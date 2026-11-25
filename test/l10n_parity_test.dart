import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/l10n/app_locale.dart';
import 'package:projectnagarsathi/l10n/app_strings.dart';

void main() {
  group('L10n Parity & Completeness', () {
    const en = EnglishStrings.instance;
    const ne = NepaliStrings.instance;

    test('all common strings are defined and non-empty in both locales', () {
      final pairs = <(String, String)>[
        (en.appName, ne.appName),
        (en.cancel, ne.cancel),
        (en.confirm, ne.confirm),
        (en.save, ne.save),
        (en.retry, ne.retry),
        (en.back, ne.back),
        (en.close, ne.close),
        (en.continueText, ne.continueText),
        (en.updateNow, ne.updateNow),
        (en.comingSoon, ne.comingSoon),
      ];

      for (final (e, n) in pairs) {
        expect(e.isNotEmpty, isTrue);
        expect(n.isNotEmpty, isTrue);
        expect(
          e != n,
          isTrue,
          reason: 'Nepali string should differ from English: $e',
        );
      }
    });

    test('all auth strings are defined and non-empty in both locales', () {
      final pairs = <(String, String)>[
        (en.signIn, ne.signIn),
        (en.signUp, ne.signUp),
        (en.forgotPassword, ne.forgotPassword),
        (en.createAccount, ne.createAccount),
        (en.welcomeBack, ne.welcomeBack),
        (en.emailOrPhone, ne.emailOrPhone),
        (en.password, ne.password),
        (en.confirmPassword, ne.confirmPassword),
        (en.enterCode, ne.enterCode),
        (en.sendCode, ne.sendCode),
        (en.rememberMe, ne.rememberMe),
        (en.continueWithGoogle, ne.continueWithGoogle),
        (en.continueWithFacebook, ne.continueWithFacebook),
        (en.staffPortal, ne.staffPortal),
        (en.emailSignInLink, ne.emailSignInLink),
        (en.emailSignInLinkSubtitle, ne.emailSignInLinkSubtitle),
        (en.emailSignInLinkFailure, ne.emailSignInLinkFailure),
        (
          en.emailSignInLinkSent('test@example.com'),
          ne.emailSignInLinkSent('test@example.com'),
        ),
        (en.emailSignInLinkEnterEmail, ne.emailSignInLinkEnterEmail),
        (en.staffSignInTitle, ne.staffSignInTitle),
        (en.staffBadgeShort, ne.staffBadgeShort),
        (en.staffEnterPassword, ne.staffEnterPassword),
        (en.staffSendCode, ne.staffSendCode),
        (en.staffWorkEmail, ne.staffWorkEmail),
        (en.staffMobileNumberHint, ne.staffMobileNumberHint),
        (en.staffNepaliMobileOnly, ne.staffNepaliMobileOnly),
        (en.staffAccessIssued, ne.staffAccessIssued),
        (en.staffSetPermanentPassword, ne.staffSetPermanentPassword),
        (
          en.staffTemporaryPasswordInstructions,
          ne.staffTemporaryPasswordInstructions,
        ),
        (en.staffNewPassword, ne.staffNewPassword),
        (en.staffPasswordLengthHint, ne.staffPasswordLengthHint),
        (en.staffPasswordLengthError, ne.staffPasswordLengthError),
        (en.staffConfirmNewPassword, ne.staffConfirmNewPassword),
        (en.staffReenterPassword, ne.staffReenterPassword),
        (en.staffUpdateAndSignIn, ne.staffUpdateAndSignIn),
        (en.staffCancelAndSignOut, ne.staffCancelAndSignOut),
      ];

      for (final (e, n) in pairs) {
        expect(e.isNotEmpty, isTrue);
        expect(n.isNotEmpty, isTrue);
        expect(e != n, isTrue);
      }
      expect(en.staffWorkEmailHint, isNotEmpty);
      expect(ne.staffWorkEmailHint, isNotEmpty);
    });

    test('all error and validation strings are localized in Nepali', () {
      final pairs = <(String, String)>[
        (en.errRequired, ne.errRequired),
        (en.errEmailOrPhone, ne.errEmailOrPhone),
        (en.errInvalidEmailOrPhone, ne.errInvalidEmailOrPhone),
        (en.errName, ne.errName),
        (en.errEmail, ne.errEmail),
        (en.errPhone, ne.errPhone),
        (en.errNepaliPhone, ne.errNepaliPhone),
        (en.errPasswordLength, ne.errPasswordLength),
        (en.errPasswordMatch, ne.errPasswordMatch),
        (en.errOtpFormat, ne.errOtpFormat),
        (en.errOtpWrong, ne.errOtpWrong),
        (en.errOtpExpired, ne.errOtpExpired),
        (en.errNetwork, ne.errNetwork),
        (en.errTimeout, ne.errTimeout),
      ];

      for (final (e, n) in pairs) {
        expect(e.isNotEmpty, isTrue);
        expect(n.isNotEmpty, isTrue);
        expect(e != n, isTrue);
      }
    });

    test('forLocale correctly resolves matching dictionary instance', () {
      expect(AppStrings.forLocale(AppLocale.en), isA<EnglishStrings>());
      expect(AppStrings.forLocale(AppLocale.ne), isA<NepaliStrings>());
    });
  });
}
