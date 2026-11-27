import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Provider extends Fake implements UserInfo {
  _Provider(this.providerId);

  @override
  final String providerId;
}

class _User extends Fake implements User {
  _User(this.events, {this.provider = 'password'});

  final List<String> events;
  final String provider;
  FirebaseAuthException? failure;
  AuthCredential? credential;

  @override
  String get uid => 'citizen';
  @override
  String get email => 'citizen@example.com';
  @override
  String get phoneNumber => '+9779800000000';
  @override
  List<UserInfo> get providerData => [_Provider(provider)];

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    events.add('reauthenticate');
    this.credential = credential;
    if (failure != null) throw failure!;
    return _UserCredential();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    events.add('refresh-token');
    return 'fresh-token';
  }
}

class _UserCredential extends Fake implements UserCredential {}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser, this.events);

  final List<String> events;
  @override
  User? currentUser;
  FirebaseAuthException? smsFailure;

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    String? autoRetrievedSmsCodeForTesting,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
  }) {
    expect(phoneNumber, '+9779800000000');
    events.add('request-sms');
    if (smsFailure == null) {
      codeSent('sms-challenge', 7);
    } else {
      verificationFailed(smsFailure!);
    }
    return Future<void>.value();
  }

  @override
  Future<void> signOut() async {
    events.add('sign-out');
    currentUser = null;
  }
}

class _Reply<T> extends Fake implements HttpsCallableResult<T> {
  _Reply(this.data);

  @override
  final T data;
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.events);

  final List<String> events;
  Map<Object?, Object?> response = {'status': 'deleted', 'emailStatus': 'sent'};
  Object? failure;
  Object? payload;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    events.add('delete-request');
    payload = parameters;
    if (failure != null) throw failure!;
    return _Reply<T>(response as T);
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.callable);

  final _Callable callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'deleteCitizenProfile');
    return callable;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cached_display_name': 'Citizen',
      'cached_email': 'citizen@example.com',
      'remember_me': true,
      'theme_mode': 'dark',
    });
  });

  test(
    'requesting a deletion SMS does not reauthenticate or delete the account',
    () async {
      final events = <String>[];
      final user = _User(events, provider: 'phone');
      final auth = _Auth(user, events);
      final callable = _Callable(events);
      final service = AuthService(
        firebaseAuth: auth,
        firebaseFunctions: _Functions(callable),
      );
      final challenge = await service.requestDeletionSmsCode();
      expect(challenge.verificationId, 'sms-challenge');
      expect(challenge.resendToken, 7);
      expect(events, ['request-sms']);
      expect(auth.currentUser, same(user));
      expect(callable.payload, isNull);
    },
  );

  test('an immediate SMS verification failure is reported without an unhandled callback error', () async {
    final events = <String>[];
    final user = _User(events, provider: 'phone');
    final auth = _Auth(user, events)
      ..smsFailure = FirebaseAuthException(code: 'too-many-requests');
    final service = AuthService(firebaseAuth: auth);
    await expectLater(
      service.requestDeletionSmsCode(),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          'Too many attempts. Please wait a minute and try again.',
        ),
      ),
    );
    expect(events, ['request-sms']);
    expect(auth.currentUser, same(user));
  });

  test(
    'fresh verification precedes deletion and local account caches are cleared',
    () async {
      final events = <String>[];
      final user = _User(events);
      final auth = _Auth(user, events);
      final callable = _Callable(events);
      final service = AuthService(
        firebaseAuth: auth,
        firebaseFunctions: _Functions(callable),
      );

      final result = await service.deleteCitizenProfile(
        password: ' password with spaces ',
      );
      expect(
        (user.credential! as EmailAuthCredential).password,
        ' password with spaces ',
      );
      expect(events, [
        'reauthenticate',
        'refresh-token',
        'delete-request',
        'sign-out',
      ]);
      expect(callable.payload, {'confirm': true});
      expect(result.completed, isTrue);
      expect(result.emailStatus, DeletionEmailStatus.sent);
      expect(auth.currentUser, isNull);
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'cached_display_name',
        'cached_email',
        'remember_me',
      ]) {
        expect(prefs.containsKey(key), isFalse);
      }
      expect(prefs.getString('theme_mode'), 'dark');
    },
  );

  test('wrong password leaves the account and cached profile intact', () async {
    final events = <String>[];
    final user = _User(events)
      ..failure = FirebaseAuthException(code: 'wrong-password');
    final auth = _Auth(user, events);
    final callable = _Callable(events);
    final service = AuthService(
      firebaseAuth: auth,
      firebaseFunctions: _Functions(callable),
    );

    await expectLater(
      service.deleteCitizenProfile(password: 'wrong'),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          'Email or password is incorrect. If you never set a password, '
              'use the email code option instead.',
        ),
      ),
    );
    expect(events, ['reauthenticate']);
    expect(callable.payload, isNull);
    expect(auth.currentUser, same(user));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cached_email'), 'citizen@example.com');
  });

  test(
    'an undeployed deletion endpoint reports failure without signing out',
    () async {
      final events = <String>[];
      final user = _User(events);
      final auth = _Auth(user, events);
      final callable = _Callable(events)
        ..failure = FirebaseFunctionsException(
          code: 'not-found',
          message: 'Function not deployed',
        );
      final service = AuthService(
        firebaseAuth: auth,
        firebaseFunctions: _Functions(callable),
      );

      await expectLater(
        service.deleteCitizenProfile(password: 'correct'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            'Profile deletion is not available yet. Please try again later.',
          ),
        ),
      );
      expect(events, ['reauthenticate', 'refresh-token', 'delete-request']);
      expect(auth.currentUser, same(user));
    },
  );

  test('a saved pending request clears the local session without claiming completion', () async {
    final events = <String>[];
    final auth = _Auth(_User(events), events);
    final callable = _Callable(events)
      ..response = {'status': 'pending', 'emailStatus': 'pending'};
    final service = AuthService(
      firebaseAuth: auth,
      firebaseFunctions: _Functions(callable),
    );

    final result = await service.deleteCitizenProfile(password: 'correct');
    expect(result.completed, isFalse);
    expect(result.emailStatus, DeletionEmailStatus.pending);
    expect(auth.currentUser, isNull);
  });

  test('SMS verification reauthenticates the existing account and does not send the code to deletion backend', () async {
    final events = <String>[];
    final user = _User(events, provider: 'phone');
    final callable = _Callable(events);
    final service = AuthService(
      firebaseAuth: _Auth(user, events),
      firebaseFunctions: _Functions(callable),
    );

    await service.deleteCitizenProfile(
      smsChallenge: const CitizenDeletionSmsChallenge(
        verificationId: 'challenge',
      ),
      smsCode: '123456',
    );
    final credential = user.credential! as PhoneAuthCredential;
    expect(credential.verificationId, 'challenge');
    expect(credential.smsCode, '123456');
    expect(callable.payload, {'confirm': true});
    expect(events.first, 'reauthenticate');
  });
}
