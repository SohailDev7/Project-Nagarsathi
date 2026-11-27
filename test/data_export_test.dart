import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/l10n/app_locale.dart';
import 'package:projectnagarsathi/l10n/app_strings.dart';
import 'package:projectnagarsathi/l10n/language_controller.dart';
import 'package:projectnagarsathi/models/data_export_request.dart';
import 'package:projectnagarsathi/screens/settings_screen.dart';
import 'package:projectnagarsathi/services/data_export_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';
import 'package:projectnagarsathi/theme/theme_controller.dart';
import 'package:projectnagarsathi/utils/data_export_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDataExportService extends DataExportService {
  _FakeDataExportService({
    this.initialExport,
    this.email = 'citizen@nagarsathi.app',
    this.errorToThrow,
  });

  DataExportRequest? initialExport;
  String? email;
  Object? errorToThrow;
  int requestCalls = 0;
  String? lastLocale;

  @override
  Future<DataExportRequest?> loadLatestExport() async => initialExport;

  @override
  Future<String?> resolveRegisteredEmail() async => email;

  @override
  Future<DataExportRequest> requestExport({String? locale}) async {
    requestCalls++;
    lastLocale = locale;
    if (errorToThrow != null) throw errorToThrow!;
    final now = DateTime.now();
    final created = DataExportRequest(
      exportId: 'exp-ui-1',
      userId: 'uid-1',
      email: email ?? 'citizen@nagarsathi.app',
      status: DataExportStatus.sent,
      requestedAt: now,
      expiresAt: now.add(DataExportRequest.linkValidity),
      deliveredAt: now,
      reportCount: 3,
      commentCount: 5,
    );
    initialExport = created;
    return created;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  void usePhoneSurface(WidgetTester tester) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('DataExportRequest model', () {
    test('serializes, deserializes, and tracks 48-hour expiration', () {
      final now = DateTime.now();
      final active = DataExportRequest(
        exportId: 'exp-123',
        userId: 'user-1',
        email: 'sita@example.com',
        status: DataExportStatus.sent,
        requestedAt: now,
        expiresAt: now.add(const Duration(hours: 48)),
        reportCount: 2,
        commentCount: 4,
      );

      expect(active.isExpiredAt(now), isFalse);
      expect(
        active.isExpiredAt(now.add(const Duration(hours: 48, seconds: 1))),
        isTrue,
      );
      expect(active.remainingAt(now).inHours, 48);

      final roundTrip = DataExportRequest.fromJson(active.toJson());
      expect(roundTrip.exportId, 'exp-123');
      expect(roundTrip.email, 'sita@example.com');
      expect(roundTrip.formats, ['json', 'pdf']);
      expect(roundTrip.reportCount, 2);
      expect(roundTrip.commentCount, 4);
      expect(roundTrip.status, DataExportStatus.sent);
    });

    test('fromMap marks past-due exports as expired', () {
      final past = DateTime.now().subtract(const Duration(hours: 49));
      final loaded = DataExportRequest.fromMap(<String, dynamic>{
        'exportId': 'exp-old',
        'userId': 'user-1',
        'email': 'sita@example.com',
        'status': 'sent',
        'requestedAt': past.millisecondsSinceEpoch,
        'expiresAt': past
            .add(const Duration(hours: 48))
            .millisecondsSinceEpoch,
      });

      expect(loaded.status, DataExportStatus.expired);
      expect(loaded.isExpiredAt(), isTrue);
      expect(loaded.remainingAt(), Duration.zero);
    });
  });

  group('DataExportGenerator', () {
    test('generates machine-readable JSON, multi-page PDF 1.4, and ZIP', () {
      final requestedAt = DateTime.utc(2026, 11, 26, 10, 0);
      final expiresAt = requestedAt.add(const Duration(hours: 48));
      final reports = List<Map<String, dynamic>>.generate(
        28,
        (i) => <String, dynamic>{
          'id': 'rep-${i + 1}',
          'title': 'Broken drain #${i + 1}',
          'category': 'sewer',
          'status': 'reported',
          'description': 'Needs cleaning before monsoon.',
        },
      );
      final comments = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'com-1',
          'reportId': 'rep-1',
          'text': 'Ward team inspected this morning.',
        },
      ];

      final jsonString = DataExportGenerator.generateJson(
        exportId: 'exp-gen-1',
        profile: <String, dynamic>{
          'uid': 'u-1',
          'name': 'Nima Sherpa',
          'email': 'nima@example.com',
          'role': 'citizen',
        },
        reports: reports,
        comments: comments,
        requestedAt: requestedAt,
        expiresAt: expiresAt,
      );

      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(parsed['exportMetadata']['formats'], ['json', 'pdf']);
      expect(parsed['summary']['totalReports'], 28);
      expect(parsed['summary']['totalComments'], 1);

      final pdfBytes = DataExportGenerator.generatePdf(
        exportId: 'exp-gen-1',
        profile: <String, dynamic>{
          'uid': 'u-1',
          'name': 'Nima Sherpa',
          'email': 'nima@example.com',
          'role': 'citizen',
        },
        reports: reports,
        comments: comments,
        requestedAt: requestedAt,
        expiresAt: expiresAt,
      );
      final pdfText = latin1.decode(pdfBytes);
      expect(pdfText.startsWith('%PDF-1.4\n'), isTrue);
      expect(pdfText.contains('xref\n'), isTrue);
      expect(pdfText.trimRight().endsWith('%%EOF'), isTrue);
      expect(pdfText.contains('Page 2 of'), isTrue);

      final zipBytes = DataExportGenerator.generateZip(
        exportId: 'exp-gen-1',
        jsonString: jsonString,
        pdfBytes: pdfBytes,
        requestedAt: requestedAt,
        expiresAt: expiresAt,
      );
      expect(zipBytes[0], 0x50);
      expect(zipBytes[1], 0x4B);
      expect(zipBytes[2], 0x03);
      expect(zipBytes[3], 0x04);
      final zipText = latin1.decode(zipBytes);
      expect(zipText.contains('nagarsathi-data-export.json'), isTrue);
      expect(zipText.contains('nagarsathi-data-export.pdf'), isTrue);
    });
  });

  group('DataExportService', () {
    test('sends authenticated request, persists result, and loads latest export', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final expires = now + const Duration(hours: 48).inMilliseconds;
      late Map<String, String> capturedHeaders;
      late Map<String, dynamic> capturedBody;

      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.example.test/request-data-export');
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'exportId': 'exp-srv-1',
            'status': 'sent',
            'email': 'ram@example.com',
            'formats': ['json', 'pdf'],
            'reportCount': 4,
            'commentCount': 7,
            'requestedAt': now,
            'expiresAt': expires,
            'deliveredAt': now,
            'deliverySlaMinutes': 15,
          }),
          200,
        );
      });

      final service = DataExportService(
        client: client,
        workerUrl: 'https://api.example.test',
        userContextLoader: () async => const DataExportUserContext(
          uid: 'uid-ram',
          email: 'ram@example.com',
          idToken: 'firebase-id-token-xyz',
          displayName: 'Ram',
        ),
      );

      final result = await service.requestExport(locale: 'en');
      expect(capturedHeaders['Authorization'], 'Bearer firebase-id-token-xyz');
      expect(capturedBody['locale'], 'en');
      expect(result.exportId, 'exp-srv-1');
      expect(result.status, DataExportStatus.sent);
      expect(result.reportCount, 4);
      expect(result.commentCount, 7);

      final cached = await service.loadLatestExport();
      expect(cached, isNotNull);
      expect(cached!.exportId, 'exp-srv-1');
      expect(cached.email, 'ram@example.com');
    });

    test('throws DataExportFailure when unauthenticated or server returns error', () async {
      final unauthService = DataExportService(
        userContextLoader: () async => null,
      );
      await expectLater(
        unauthService.requestExport(),
        throwsA(isA<DataExportFailure>()),
      );

      final errorClient = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{'error': 'Too many export requests.'}),
          429,
        ),
      );
      final rateLimitedService = DataExportService(
        client: errorClient,
        workerUrl: 'https://api.example.test',
        userContextLoader: () async => const DataExportUserContext(
          uid: 'uid-1',
          email: 'ram@example.com',
          idToken: 'token',
        ),
      );
      await expectLater(
        rateLimitedService.requestExport(),
        throwsA(
          predicate<DataExportFailure>(
            (e) => e.message == 'Too many export requests.',
          ),
        ),
      );
    });
  });

  group('SettingsScreen Privacy & Download My Data UI', () {
    testWidgets('Download My Data button initiates export and shows 48h expiry summary', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final themeController = ThemeController(ThemeMode.light);
      final langController = LanguageController(AppLocale.en);
      addTearDown(themeController.dispose);
      addTearDown(langController.dispose);

      final fakeService = _FakeDataExportService(
        email: 'sita@nagarsathi.app',
      );

      await tester.pumpWidget(
        AppStringsScope(
          strings: AppStrings.forLocale(AppLocale.en),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: SettingsScreen(
              controller: themeController,
              languageController: langController,
              dataExportService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final downloadButton = find.byKey(const Key('download-my-data-button'));
      await tester.scrollUntilVisible(
        downloadButton,
        250,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Download My Data'), findsOneWidget);
      expect(find.text('Formats: JSON & PDF archive'), findsOneWidget);
      expect(
        find.text('Download link expires automatically after 48 hours'),
        findsOneWidget,
      );

      await tester.tap(downloadButton);
      await tester.pumpAndSettle();

      expect(fakeService.requestCalls, 1);
      expect(fakeService.lastLocale, 'en');
      expect(find.text('EMAIL SENT'), findsOneWidget);
      expect(find.text('Sent to sita@nagarsathi.app'), findsOneWidget);
      expect(find.text('3 report(s) · 5 comment(s)'), findsOneWidget);
      expect(
        find.byKey(const Key('data-export-summary-box')),
        findsOneWidget,
      );
    });

    testWidgets('shows EXPIRED badge when previous export exceeded 48 hours and renders error cleanly', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final themeController = ThemeController(ThemeMode.dark);
      final langController = LanguageController(AppLocale.en);
      addTearDown(themeController.dispose);
      addTearDown(langController.dispose);

      final past = DateTime.now().subtract(const Duration(hours: 50));
      final fakeService = _FakeDataExportService(
        email: 'sita@nagarsathi.app',
        initialExport: DataExportRequest(
          exportId: 'exp-expired',
          userId: 'uid-1',
          email: 'sita@nagarsathi.app',
          status: DataExportStatus.expired,
          requestedAt: past,
          expiresAt: past.add(const Duration(hours: 48)),
          reportCount: 1,
          commentCount: 0,
        ),
        errorToThrow: const DataExportFailure('Could not reach export server.'),
      );

      await tester.pumpWidget(
        AppStringsScope(
          strings: AppStrings.forLocale(AppLocale.en),
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.dark),
            home: SettingsScreen(
              controller: themeController,
              languageController: langController,
              dataExportService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final downloadButton = find.byKey(const Key('download-my-data-button'));
      await tester.scrollUntilVisible(
        downloadButton,
        250,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('EXPIRED'), findsOneWidget);
      expect(
        find.text('Link expired after 48 hours. Request a new export anytime.'),
        findsOneWidget,
      );

      await tester.tap(downloadButton);
      await tester.pumpAndSettle();

      expect(find.text('Could not reach export server.'), findsWidgets);
    });

    testWidgets('supports Nepali locale in Privacy & Download My Data section', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final themeController = ThemeController(ThemeMode.light);
      final langController = LanguageController(AppLocale.ne);
      addTearDown(themeController.dispose);
      addTearDown(langController.dispose);

      final fakeService = _FakeDataExportService(
        email: 'sita@nagarsathi.app',
      );
      final neStrings = AppStrings.forLocale(AppLocale.ne);

      await tester.pumpWidget(
        AppStringsScope(
          strings: neStrings,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: SettingsScreen(
              controller: themeController,
              languageController: langController,
              dataExportService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final downloadButton = find.byKey(const Key('download-my-data-button'));
      await tester.scrollUntilVisible(
        downloadButton,
        250,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text(neStrings.privacyTitle), findsOneWidget);
      expect(find.text(neStrings.downloadMyData), findsOneWidget);

      await tester.tap(downloadButton);
      await tester.pumpAndSettle();

      expect(fakeService.requestCalls, 1);
      expect(fakeService.lastLocale, 'ne');
      expect(find.text(neStrings.dataExportEmailSentBadge), findsOneWidget);
    });
  });
}
