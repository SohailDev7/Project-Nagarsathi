import 'package:flutter/widgets.dart';

import 'app_locale.dart';

/// Provides type-safe access to all user-facing strings in the app.
abstract class AppStrings {
  const AppStrings();

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    return scope?.strings ?? EnglishStrings.instance;
  }

  static AppStrings forLocale(AppLocale locale) {
    return locale.isNepali ? NepaliStrings.instance : EnglishStrings.instance;
  }

  // ── Common ────────────────────────────────────────────────────────────────
  String get appName;
  String get cancel;
  String get confirm;
  String get save;
  String get retry;
  String get back;
  String get close;
  String get continueText;
  String get updateNow;
  String get comingSoon;
  String get orText;
  String get optional;
  String get success;

  // ── Auth ──────────────────────────────────────────────────────────────────
  String get signIn;
  String get signUp;
  String get forgotPassword;
  String get createAccount;
  String get welcomeBack;
  String get emailOrPhone;
  String get email;
  String get phone;
  String get fullName;
  String get password;
  String get confirmPassword;
  String get enterCode;
  String get sendCode;
  String get resendCode;
  String get rememberMe;
  String get continueWithGoogle;
  String get continueWithFacebook;
  String get dontHaveAccount;
  String get alreadyHaveAccount;
  String get staffPortal;
  String get citizenPortal;
  String get staffWorkspace;
  String get staffBadge;
  String get tryAnotherWay;
  String get usePassword;
  String get termsDisclaimer;
  String get resetPasswordTitle;
  String get sendResetLink;
  String get newToNagarSathi;
  String get areYouStaff;
  String get changeIdentifier;
  String get verifyAndSignIn;
  String get emailOrPhoneHint;
  String get passwordHint;
  String get otpHint;
  String get noAccountFoundBanner;
  String get phoneOtpSoon;
  String get verificationCode;
  String get passwordMethodSubtitle;
  String get googleSignInSubtitle;
  String get facebookSignInSubtitle;
  String get emailSignInLink;
  String get emailSignInLinkSubtitle;
  String get emailSignInLinkFailure;
  String emailSignInLinkSent(String email);
  String get emailSignInLinkEnterEmail;
  String get credentialHelp;
  String get orContinueWith;
  String get firebaseNoResponse;
  String get signInFailure;
  String get sendCodeFailure;
  String get facebookSignInFailure;
  String get switchToLightMode;
  String get switchToDarkMode;
  String continueAs(String name);
  String chooseSignInMethodFor(String identifier);
  String verificationCodeSent(String email);
  String passwordResetLinkSent(String email);
  String passwordResetSentCheckInbox(String email);
  String get emailLinkAction;
  String get editEmail;
  String resendIn(int seconds);
  String stepOfTotal(int step, int total);
  String otpSentNotice(String email);
  String get pwdRuleLength;
  String get pwdRuleNumber;
  String get pwdRuleSymbolOrUpper;
  String get pwdStrengthWeak;
  String get pwdStrengthFair;
  String get pwdStrengthGood;
  String get pwdStrengthStrong;
  String get signUpPhoneHelper;
  String get acceptTermsNotice;
  String get agreeToTermsPrefix;
  String get termsOfServiceLabel;
  String get andLabel;
  String get privacyPolicyLabel;

  // ── Mascot Speeches & Guidance ────────────────────────────────────────────
  String get mascotDefaultLogin;
  String get mascotDefaultSignUp;
  String get mascotPasswordPrompt;
  String get mascotForgotPrompt;
  String get mascotForgotSent;
  String get mascotForgotFocused;
  String get mascotStepYourDetails;
  String get mascotStepSecure;
  String get mascotStepVerify;
  String get mascotAllSet;
  String get mascotTryAgain;
  String get mascotGoogleLoading;
  String get mascotCreatingAccount;
  String get mascotLoginReady;
  String get mascotEmailSpotted;
  String get mascotPhoneSpotted;
  String get mascotTypeEither;
  String get mascotCheckingAccount;
  String get mascotVerifyingCode;
  String get mascotCheckingDetails;
  String get mascotEnterPassword;
  String get mascotPasswordPrivate;
  String get mascotAccountNotFound;
  String get mascotOpeningGoogle;
  String get mascotOpeningFacebook;
  String get mascotOpeningCity;

  // ── Home Screen ───────────────────────────────────────────────────────────
  String greeting(String name);
  String get goodMorning;
  String get goodAfternoon;
  String get goodEvening;
  String get setYourLocation;
  String get locating;
  String get reportHeroTitle;
  String get reportHeroSubtitle;
  String get reportNow;
  String get reportInOneTap;
  String get aroundYou;
  String get seeAll;
  String get noReportsYet;
  String get categoryPothole;
  String get categoryWaste;
  String get categoryStreetlight;
  String get categoryWater;
  String get categorySewer;
  String get categoryTree;
  String get navHome;
  String get navReports;
  String get navNotifications;
  String get navProfile;
  String get navMap;
  String get navProgress;

  // ── Staff dashboard & super admin ─────────────────────────────────────────
  String get staffWardReports;
  String get staffProgress;
  String get staffWardLabel;
  List<String> get staffTips;
  String get staffWardSnapshot;
  String get staffWardClear;
  String get staffAssignedWard;
  String get staffUpdateQueue;
  String get staffProfileTitle;
  String get staffAccessLevel;
  String get superAdminBadge;
  String get superAdminConsole;
  String get superAdminSubtitle;
  String get createWardOfficer;
  String get openAuditTrail;
  String get officersLabel;
  String get auditEventsLabel;
  String get quickActions;
  String get somethingBrokenNearby;
  String get communityReporting;
  String get reportHeroPrompt;
  String get findingYourWard;
  String get areYouFrom;
  String get phoneLocationNotice;
  String get yesThatsMe;
  String get notQuite;
  String get categoryRoads;
  String get categoryGarbage;
  String get categoryLights;
  String get categoryWaterHero;
  String wardLabel(String number);
  String get wardSavedSession;
  String get wardSavedProfile;
  String get wardSyncFailed;
  String get wardConfirmTitle;
  String wardConfirmSubtitle(String ward, String municipality);
  String get changeWard;

  // ── Settings & Appearance ─────────────────────────────────────────────────
  String get appearanceTitle;
  String get settingsTitle;
  String get themeTitle;
  String get themeSubtitle;
  String get themeSystem;
  String get themeSystemDesc;
  String get themeLight;
  String get themeLightDesc;
  String get themeDark;
  String get themeDarkDesc;
  String get languageTitle;
  String get languageSubtitle;
  String get languageEnglish;
  String get languageEnglishDesc;
  String get languageNepali;
  String get languageNepaliDesc;
  String get signOut;
  String versionText(String version);
  String get checkForUpdates;
  String get upToDate;

  // ── Dashboard & Quick Settings ────────────────────────────────────────────
  String get settings;
  String get settingsSubtitle;
  String get appearanceShort;
  String get languageShort;
  String get systemShort;
  String get lightShort;
  String get darkShort;
  String get openSettings;
  String get neighbour;
  String get citizenAccount;
  String get citizenBadge;
  String get appTagline;

  // ── Citizen feed demo ─────────────────────────────────────────────────────
  List<String> get homeTips;
  String get reportOverflowBin;
  String get reportOverflowBinMeta;
  String get reportPotholeTitle;
  String get reportPotholeMeta;
  String get reportStreetlightTitle;
  String get reportStreetlightMeta;
  String get statusInProgress;
  String get statusReported;
  String get statusResolved;
  String hoursAgo(int hours);
  String daysAgo(int days);
  String get yesterdayLabel;

  // ── Location notices ──────────────────────────────────────────────────────
  String get locationTimeout;
  String get wardNotConfirmed;
  String updateCheckFailed(String error);

  // ── Staff workspace ───────────────────────────────────────────────────────
  String get staffWorkspaceSubtitle;
  String get staffSignedInLabel;
  String get staffWelcomeTitle;
  String get staffClearedBody;
  String get appAdmin;
  String get wardOfficerManagement;
  String get wardOfficerManagementDesc;
  String get todaysQueue;
  String get statOpen;
  String get statResolved;
  String get statAvgTime;
  String get queueRoadRepair;
  String get queueRoadRepairMeta;
  String get queueStreetlight;
  String get queueStreetlightMeta;
  String get queueWaste;
  String get queueWasteMeta;
  String get statusPriority;
  String get statusNew;
  String get statusOpen;
  String get signOutOfStaff;
  String get staffSignInTitle;
  String get staffBadgeShort;
  String get staffEnterPassword;
  String get staffForgotPassword;
  String get staffPasswordResetNeedsEmail;
  String staffPasswordResetSent(String email);
  String get staffSendCode;
  String get staffWorkEmail;
  String get staffWorkEmailHint;
  String get staffMobileNumberHint;
  String get staffNepaliMobileOnly;
  String get staffAccessIssued;
  String get staffSetPermanentPassword;
  String get staffTemporaryPasswordInstructions;
  String get staffNewPassword;
  String get staffChangePassword;
  String get staffPasswordChanged;
  String get staffPasswordMismatch;
  String get staffPasswordLengthHint;
  String get staffPasswordLengthError;
  String get staffConfirmNewPassword;
  String get staffReenterPassword;
  String get staffUpdateAndSignIn;
  String get staffCancelAndSignOut;

  // ── Admin ward officers ───────────────────────────────────────────────────
  String get wardOfficersTitle;
  String appAdminSubtitle(String admin);
  String get officersTab;
  String get auditTrailTab;
  String get searchOfficersHint;
  String get auditSearchHint;
  String get exportCsv;
  String get exportFailed;
  String get allWards;
  String get allStatuses;
  String get totalLabel;
  String get activeLabel;
  String get suspendedLabel;
  String officerCount(int count);
  String get noWardOfficersTitle;
  String get noOfficersMatchTitle;
  String get noWardOfficersBody;
  String get noOfficersMatchBody;
  String get clearFilters;
  String get addOfficer;
  String get recentActivity;
  String auditEntryCount(int count);
  String get noAuditEntriesTitle;
  String get noAuditEntriesBody;
  String get reassign;
  String get accountActive;
  String get accountSuspended;
  String get auditInfo;
  String get addWardOfficerTitle;
  String get addWardOfficerSubtitle;
  String get fullNameExample;
  String get emailAddressLabel;
  String get emailExample;
  String get phoneNumberLabel;
  String get phoneExample;
  String get assignedWardLabel;
  String get municipalityLabel;
  String get createOfficerLabel;
  String get officerEmailExists;
  String get reassignWardTitle;
  String reassignWardSubtitle(String name, String ward);
  String get newWardLabel;
  String get reasonLabel;
  String get reassignReasonHint;
  String get updateWardLabel;
  String get reassignReasonRequired;
  String get chooseDifferentWard;
  String get addReasonTitle;
  String addReasonSubtitle(String name);
  String get reasonHint;
  String get saveReasonLabel;
  String get reasonRequiredForAction;
  String get viewAudit;
  String get addReasonAction;
  String get couldNotLoadOfficerData;
  String get couldNotRefreshOfficerData;
  String get couldNotUpdateOfficerStatus;
  String get couldNotReassignOfficer;
  String get couldNotUpdateAuditReason;
  String auditReasonUpdated(String name);
  String officerAddedMessage(String name, String ward, String notification);
  String officerStatusChangedMessage(
    String name,
    String status,
    String notification,
  );
  String officerMovedMessage(String name, String ward, String notification);

  // ── Validation & Errors ───────────────────────────────────────────────────
  String get errRequired;
  String get errEmailOrPhone;
  String get errInvalidEmailOrPhone;
  String get errName;
  String get errNameLength;
  String get errEmail;
  String get errInvalidEmail;
  String get errPhone;
  String get errInvalidPhone;
  String get errNepaliPhone;
  String get errPasswordLength;
  String get errPasswordMatch;
  String get errOtpFormat;
  String get errOtpWrong;
  String get errOtpExpired;
  String get errNetwork;
  String get errTimeout;
  String get errTooManyAttempts;
  String get errUnknown;

  // ── Update Dialog ─────────────────────────────────────────────────────────
  String get updateRequired;
  String get updateAvailable;
  String get whatsNew;
  String get holdToCancel;
  String get downloadingUpdate;
  String get keepAppOpen;
  String get useWifi;
}

/// InheritedWidget that exposes [AppStrings] down the widget tree.
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      strings != oldWidget.strings;
}

/// Extension on [BuildContext] for ergonomic syntax: `context.l10n`.
extension BuildContextL10n on BuildContext {
  AppStrings get l10n => AppStrings.of(this);
}

/// English implementation of [AppStrings].
class EnglishStrings extends AppStrings {
  const EnglishStrings();
  static const EnglishStrings instance = EnglishStrings();

  @override
  String get appName => 'NagarSathi';
  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'Confirm';
  @override
  String get save => 'Save';
  @override
  String get retry => 'Retry';
  @override
  String get back => 'Back';
  @override
  String get close => 'Close';
  @override
  String get continueText => 'Continue';
  @override
  String get updateNow => 'Update now';
  @override
  String get comingSoon => 'Feature coming soon.';
  @override
  String get orText => 'or';
  @override
  String get optional => 'optional';
  @override
  String get success => 'Success';

  @override
  String get signIn => 'Sign in';
  @override
  String get signUp => 'Sign up';
  @override
  String get forgotPassword => 'Forgot password?';
  @override
  String get createAccount => 'Create your account';
  @override
  String get welcomeBack => 'Welcome back';
  @override
  String get emailOrPhone => 'Email or phone number';
  @override
  String get email => 'Email';
  @override
  String get phone => 'Phone';
  @override
  String get fullName => 'Full name';
  @override
  String get password => 'Password';
  @override
  String get confirmPassword => 'Confirm password';
  @override
  String get enterCode => 'Enter 6-digit code';
  @override
  String get sendCode => 'Send verification code';
  @override
  String get resendCode => 'Resend code';
  @override
  String get rememberMe => 'Remember me on this device';
  @override
  String get continueWithGoogle => 'Continue with Google';
  @override
  String get continueWithFacebook => 'Continue with Facebook';
  @override
  String get dontHaveAccount => "Don't have an account?";
  @override
  String get alreadyHaveAccount => 'Already have an account?';
  @override
  String get staffPortal => 'Staff portal';
  @override
  String get citizenPortal => 'Citizen sign-in';
  @override
  String get staffWorkspace => 'Staff workspace';
  @override
  String get staffBadge => 'Municipal Staff';
  @override
  String get tryAnotherWay => 'Sign in another way';
  @override
  String get usePassword => 'Use password';
  @override
  @override
  String get termsDisclaimer =>
      'By continuing you agree to NagarSathi terms and privacy policy.';
  @override
  String get resetPasswordTitle => 'Reset password';
  @override
  String get sendResetLink => 'Send reset instructions';
  @override
  String get newToNagarSathi => 'New to NagarSathi?';
  @override
  String get areYouStaff => 'Are you municipality staff? ';
  @override
  String get changeIdentifier => 'Change';
  @override
  String get verifyAndSignIn => 'Verify & sign in';
  @override
  String get emailOrPhoneHint => 'you@example.com or 98XXXXXXXX';
  @override
  String get passwordHint => 'Enter your password';
  @override
  String get otpHint => '6-digit code';
  @override
  String get noAccountFoundBanner => 'No account found with this email.';
  @override
  String get phoneOtpSoon =>
      'Use your email to sign in. Phone OTP is coming soon.';
  @override
  String get verificationCode => 'Verification code';
  @override
  @override
  String get passwordMethodSubtitle => 'Enter your account password';
  @override
  String get googleSignInSubtitle => 'Sign in with your Google account';
  @override
  String get facebookSignInSubtitle => 'Sign in with your Facebook account';
  @override
  String get emailSignInLink => 'Sign in with an email link';
  @override
  String get emailSignInLinkSubtitle =>
      'Send a secure sign-in link to your inbox';
  @override
  String get emailSignInLinkFailure =>
      'Could not send a sign-in link. Please try again.';
  @override
  String emailSignInLinkSent(String email) =>
      'A sign-in link was sent to $email. Open it on this device to sign in.';
  @override
  String get emailSignInLinkEnterEmail =>
      'Enter the email address that received this sign-in link.';
  @override
  String get credentialHelp =>
      'Wrong password, or signed up with Google/Facebook? Use "Try another way" below, or send a password reset link.';
  @override
  String get orContinueWith => 'or continue with';
  @override
  String get firebaseNoResponse =>
      'Firebase did not respond. Check your internet and try again.';
  @override
  String get signInFailure => 'Sign-in could not finish. Please try again.';
  @override
  String get sendCodeFailure => 'Could not send the code. Please try again.';
  @override
  String get facebookSignInFailure =>
      'Facebook sign-in failed. Please try again.';
  @override
  String get switchToLightMode => 'Switch to light mode';
  @override
  String get switchToDarkMode => 'Switch to dark mode';
  @override
  String continueAs(String name) => 'Continue as $name';
  @override
  String chooseSignInMethodFor(String identifier) =>
      'Choose how you would like to sign in to $identifier:';
  @override
  String verificationCodeSent(String email) =>
      'Verification code sent to $email';
  @override
  String passwordResetLinkSent(String email) =>
      'Password reset link sent to $email';
  @override
  String passwordResetSentCheckInbox(String email) =>
      'Reset link sent to $email. Check your inbox.';
  @override
  String get emailLinkAction => 'Email link';
  @override
  String get editEmail => 'Edit';
  @override
  String resendIn(int seconds) => 'Resend in ${seconds}s';
  @override
  String stepOfTotal(int step, int total) => '$step of $total';
  @override
  String otpSentNotice(String email) =>
      'We sent a 6-digit code to $email. It expires in 5 minutes.';
  @override
  String get pwdRuleLength => '8+ characters';
  @override
  String get pwdRuleNumber => 'Includes a number';
  @override
  String get pwdRuleSymbolOrUpper => 'Uppercase or symbol';
  @override
  String get pwdStrengthWeak => 'Too short';
  @override
  String get pwdStrengthFair => 'Fair';
  @override
  String get pwdStrengthGood => 'Good';
  @override
  String get pwdStrengthStrong => 'Strong';
  @override
  String get signUpPhoneHelper => 'Only used for urgent ward notices.';
  @override
  String get acceptTermsNotice => 'Accept the terms to continue.';
  @override
  String get agreeToTermsPrefix => 'I agree to the ';
  @override
  String get termsOfServiceLabel => 'Terms of Service';
  @override
  String get andLabel => ' and ';
  @override
  String get privacyPolicyLabel => 'Privacy Policy';

  @override
  String get mascotDefaultLogin =>
      'Hi neighbour! Sign in to report and track municipal issues.';
  @override
  String get mascotDefaultSignUp =>
      'Join NagarSathi to make your city cleaner and better.';
  @override
  String get mascotPasswordPrompt =>
      'At least 8 characters. I promise not to peek!';
  @override
  String get mascotForgotPrompt => 'Forgot it? Happens to everyone.';
  @override
  String get mascotForgotSent => 'Sent! Check your inbox in a moment.';
  @override
  String get mascotForgotFocused => 'Email or phone — either one works.';
  @override
  String get mascotStepYourDetails =>
      'Tell me who you are and where to reach you.';
  @override
  String get mascotStepSecure => 'Set a strong password for your account.';
  @override
  String get mascotStepVerify => 'Enter the 6-digit code sent to your email.';
  @override
  String get mascotAllSet => 'You are all set! Welcome to NagarSathi.';
  @override
  String get mascotTryAgain => 'Check your details and try once more.';
  @override
  String get mascotGoogleLoading => 'Opening Google… pick your account.';
  @override
  String get mascotCreatingAccount => 'Creating your citizen account…';
  @override
  String get mascotLoginReady => 'Namaste! Ready when you are.';
  @override
  String get mascotEmailSpotted => 'Email spotted. Looking good!';
  @override
  String get mascotPhoneSpotted => 'Phone number it is. Nice!';
  @override
  String get mascotTypeEither =>
      'Type an email or a phone number — I will sort it out.';
  @override
  String get mascotCheckingAccount => 'Checking your account…';
  @override
  String get mascotVerifyingCode => 'Verifying code…';
  @override
  String get mascotCheckingDetails => 'Checking your details…';
  @override
  String get mascotEnterPassword => 'Enter your password to sign in.';
  @override
  String get mascotPasswordPrivate => 'Your password stays private. Promise.';
  @override
  String get mascotAccountNotFound =>
      'I could not find an account with that email.';
  @override
  String get mascotOpeningGoogle => 'Opening Google… pick your account.';
  @override
  String get mascotOpeningFacebook => 'Opening Facebook… hold tight.';
  @override
  String get mascotOpeningCity => 'Welcome back! Opening your city…';

  @override
  String greeting(String name) => 'Namaste, $name';
  @override
  String get goodMorning => 'Good morning';
  @override
  String get goodAfternoon => 'Good afternoon';
  @override
  String get goodEvening => 'Good evening';
  @override
  String get setYourLocation => 'Set your location';
  @override
  String get locating => 'Locating…';
  @override
  String get reportHeroTitle => 'See an issue in your city?';
  @override
  String get reportHeroSubtitle =>
      'Report potholes, waste, water leaks and track fixes in real time.';
  @override
  String get reportNow => 'Report an issue';
  @override
  String get reportInOneTap => 'Report in one tap';
  @override
  String get aroundYou => 'Around you';
  @override
  String get seeAll => 'See all';
  @override
  String get noReportsYet => 'No reports around you yet.';
  @override
  String get categoryPothole => 'Pothole';
  @override
  String get categoryWaste => 'Waste';
  @override
  String get categoryStreetlight => 'Streetlight';
  @override
  String get categoryWater => 'Water leak';
  @override
  String get categorySewer => 'Sewer';
  @override
  String get categoryTree => 'Fallen tree';
  @override
  String get navHome => 'Home';
  @override
  String get navReports => 'Reports';
  @override
  String get navNotifications => 'Notifications';
  @override
  String get navProfile => 'Profile';
  @override
  String get navProgress => 'Progress';
  @override
  String get staffWardReports => 'Ward reports';
  @override
  String get staffProgress => 'Progress';
  @override
  String get staffWardLabel => 'Ward 4 · Lakeside';
  @override
  List<String> get staffTips => const [
    'Your ward queue, one tap away.',
    'Resolve what your neighbours reported.',
    'Keep ward progress moving today.',
  ];
  @override
  String get staffWardSnapshot => 'Ward snapshot';
  @override
  String get staffWardClear => 'Nothing waiting — your ward is clear.';
  @override
  String get staffAssignedWard => 'Assigned ward';
  @override
  String get staffUpdateQueue => 'Review ward queue';
  @override
  String get staffProfileTitle => 'Staff profile';
  @override
  String get staffAccessLevel => 'Access level';
  @override
  String get superAdminBadge => 'SUPER ADMIN';
  @override
  String get superAdminConsole => 'Super admin console';
  @override
  String get superAdminSubtitle =>
      'Create ward officers and keep an eye on the audit trail.';
  @override
  String get createWardOfficer => 'Create ward officer';
  @override
  String get openAuditTrail => 'Open audit trail';
  @override
  String get officersLabel => 'Officers';
  @override
  String get auditEventsLabel => 'Audit events';
  @override
  String get quickActions => 'Quick actions';
  @override
  String get navMap => 'Map';
  @override
  String get somethingBrokenNearby => 'Something broken nearby?';
  @override
  String get communityReporting => 'COMMUNITY REPORTING';
  @override
  String get reportHeroPrompt =>
      'Send a photo and a short note. It goes straight to the desk that fixes it.';
  @override
  String get findingYourWard => 'Finding your ward…';
  @override
  String get areYouFrom => 'Are you from';
  @override
  String get phoneLocationNotice =>
      "We used your phone's location. Reports you send will be routed to this ward office.";
  @override
  String get yesThatsMe => "Yes, that's me";
  @override
  String get notQuite => 'Not quite';
  @override
  String get categoryRoads => 'Roads';
  @override
  String get categoryGarbage => 'Garbage';
  @override
  String get categoryLights => 'Lights';
  @override
  String get categoryWaterHero => 'Water';
  @override
  String wardLabel(String number) => 'Ward $number';
  @override
  String get wardSavedSession => 'Ward saved for this session.';
  @override
  String get wardSavedProfile => 'Ward saved to your profile.';
  @override
  String get wardSyncFailed =>
      "Couldn't sync your ward. Tap the location pill to retry.";
  @override
  String get wardConfirmTitle => 'Confirm your ward';
  @override
  String wardConfirmSubtitle(String ward, String municipality) =>
      'Based on your location, you are in $ward, $municipality.';
  @override
  String get changeWard => 'Change ward';

  @override
  String get appearanceTitle => 'Appearance';
  @override
  String get settingsTitle => 'Settings';
  @override
  String get themeTitle => 'Theme';
  @override
  String get themeSubtitle =>
      'Choose how NagarSathi looks. System follows your device setting automatically.';
  @override
  String get themeSystem => 'System';
  @override
  String get themeSystemDesc => 'Match your device setting';
  @override
  String get themeLight => 'Light';
  @override
  String get themeLightDesc => 'Warm cream background';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeDarkDesc => 'Easier on the eyes at night';
  @override
  String get languageTitle => 'Language';
  @override
  String get languageSubtitle =>
      'Choose your preferred language for NagarSathi.';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageEnglishDesc => 'English · Default';
  @override
  String get languageNepali => 'नेपाली';
  @override
  String get languageNepaliDesc => 'नेपाली भाषा · Nepali';
  @override
  String get signOut => 'Sign out';
  @override
  String versionText(String version) => 'NagarSathi · version $version';
  @override
  String get checkForUpdates => 'Check for updates';
  @override
  String get upToDate => 'NagarSathi is up to date.';

  @override
  String get settings => 'Settings';
  @override
  String get settingsSubtitle => 'Choose how NagarSathi looks and speaks.';
  @override
  String get appearanceShort => 'Appearance';
  @override
  String get languageShort => 'Language';
  @override
  String get systemShort => 'System';
  @override
  String get lightShort => 'Light';
  @override
  String get darkShort => 'Dark';
  @override
  String get openSettings => 'Open settings';
  @override
  String get neighbour => 'neighbour';
  @override
  String get citizenAccount => 'citizen account';
  @override
  String get citizenBadge => 'CITIZEN';
  @override
  String get appTagline => 'NagarSathi · your city, by your side';

  @override
  List<String> get homeTips => const [
    'What needs fixing in your city today?',
    'Spotted a pothole? I am all ears.',
    'A small report can make a big difference.',
    'Streetlight out? Garbage piling up? Tell me.',
    'Your ward gets better every time you report.',
  ];
  @override
  String get reportOverflowBin => 'Overflowing bin near the chowk';
  @override
  String get reportOverflowBinMeta => 'Baneshwor · 2h ago';
  @override
  String get reportPotholeTitle => 'Pothole on the main road';
  @override
  String get reportPotholeMeta => 'Maitighar · Yesterday';
  @override
  String get reportStreetlightTitle => 'Streetlight out on the lane';
  @override
  String get reportStreetlightMeta => 'Ward 12 · 2 days ago';
  @override
  String get statusInProgress => 'In progress';
  @override
  String get statusReported => 'Reported';
  @override
  String get statusResolved => 'Resolved';
  @override
  String hoursAgo(int hours) => '$hours hours ago';
  @override
  String daysAgo(int days) => '$days days ago';
  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String get locationTimeout =>
      'Finding your ward took too long. Please try again.';
  @override
  String get wardNotConfirmed =>
      'No problem. Tap the location pill to try again.';
  @override
  String updateCheckFailed(String error) =>
      'Could not check for updates: $error';

  @override
  String get staffWorkspaceSubtitle => 'Your municipal queue at a glance.';
  @override
  String get staffSignedInLabel => 'SIGNED IN';
  @override
  String get staffWelcomeTitle => 'Welcome, staff member';
  @override
  String get staffClearedBody =>
      'You are cleared for citizen requests and ward updates.';
  @override
  String get appAdmin => 'App admin';
  @override
  String get wardOfficerManagement => 'Ward officer management';
  @override
  String get wardOfficerManagementDesc =>
      'Create accounts, suspend or reactivate access, reassign wards and '
      'review the audit trail.';
  @override
  String get todaysQueue => "Today's queue";
  @override
  String get statOpen => 'Open';
  @override
  String get statResolved => 'Resolved';
  @override
  String get statAvgTime => 'Avg time';
  @override
  String get queueRoadRepair => 'Road repair';
  @override
  String get queueRoadRepairMeta => 'Ward 4 · Lakeside Road';
  @override
  String get queueStreetlight => 'Streetlight';
  @override
  String get queueStreetlightMeta => 'Ward 2 · Durbar Marg';
  @override
  String get queueWaste => 'Waste pickup';
  @override
  String get queueWasteMeta => 'Ward 7 · Baneshwor';
  @override
  String get statusPriority => 'Priority';
  @override
  String get statusNew => 'New';
  @override
  String get statusOpen => 'Open';
  @override
  String get signOutOfStaff => 'Sign out';
  @override
  String get staffSignInTitle => 'Staff sign in';
  @override
  String get staffBadgeShort => 'STAFF';
  @override
  String get staffEnterPassword => 'Enter your password';
  @override
  String get staffForgotPassword => 'Forgot password?';
  @override
  String get staffPasswordResetNeedsEmail =>
      'Enter your work email first, then tap Forgot password.';
  @override
  String staffPasswordResetSent(String email) =>
      'If $email has an account, a reset link is on its way. Check that inbox.';
  @override
  String get staffSendCode => 'Send code';
  @override
  String get staffWorkEmail => 'Work email address';
  @override
  String get staffWorkEmailHint => 'you@municipality.gov.np';
  @override
  String get staffMobileNumberHint => '98XXXXXXXX or +977 98XXXXXXXX';
  @override
  String get staffNepaliMobileOnly => 'Nepali mobile numbers only (+977).';
  @override
  String get staffAccessIssued => 'Access is issued by your municipality.';
  @override
  String get staffSetPermanentPassword => 'Set a permanent password';
  @override
  String get staffTemporaryPasswordInstructions =>
      'You are signing in with a temporary password. Please set your new '
      'permanent password to continue.';
  @override
  String get staffNewPassword => 'New password';
  @override
  String get staffChangePassword => 'Change password';
  @override
  String get staffPasswordChanged => 'Your password has been updated.';
  @override
  String get staffPasswordMismatch => 'Both passwords must match.';
  @override
  String get staffPasswordLengthHint => 'At least 6 characters';
  @override
  String get staffPasswordLengthError =>
      'Password must be at least 6 characters';
  @override
  String get staffConfirmNewPassword => 'Confirm new password';
  @override
  String get staffReenterPassword => 'Re-enter your new password';
  @override
  String get staffUpdateAndSignIn => 'Update & sign in';
  @override
  String get staffCancelAndSignOut => 'Cancel & sign out';

  @override
  String get wardOfficersTitle => 'Ward officers';
  @override
  String appAdminSubtitle(String admin) => 'App admin · $admin';
  @override
  String get officersTab => 'Officers';
  @override
  String get auditTrailTab => 'Audit trail';
  @override
  String get searchOfficersHint => 'Search name, email, phone or ward';
  @override
  String get auditSearchHint => 'Search officer, action or reason';
  @override
  String get exportCsv => 'Export CSV';
  @override
  String get exportFailed => 'Could not export the report.';
  @override
  String get allWards => 'All wards';
  @override
  String get allStatuses => 'All statuses';
  @override
  String get totalLabel => 'Total';
  @override
  String get activeLabel => 'Active';
  @override
  String get suspendedLabel => 'Suspended';
  @override
  String officerCount(int count) =>
      count == 1 ? '1 officer' : '$count officers';
  @override
  String get noWardOfficersTitle => 'No ward officers yet';
  @override
  String get noOfficersMatchTitle => 'No officers match';
  @override
  String get noWardOfficersBody =>
      'Create the first officer account to start assigning wards and '
      'tracking admin actions.';
  @override
  String get noOfficersMatchBody =>
      'Try a different search or clear the ward and status filters.';
  @override
  String get clearFilters => 'Clear filters';
  @override
  String get addOfficer => 'Add officer';
  @override
  String get recentActivity => 'Recent activity';
  @override
  String auditEntryCount(int count) =>
      count == 1 ? '1 entry' : '$count entries';
  @override
  String get noAuditEntriesTitle => 'No audit entries yet';
  @override
  String get noAuditEntriesBody =>
      'Create, suspend, reactivate or reassign an officer and the action '
      'will appear here.';
  @override
  String get reassign => 'Reassign';
  @override
  String get accountActive => 'Account active';
  @override
  String get accountSuspended => 'Account suspended';
  @override
  String get auditInfo =>
      'Every admin action is recorded. Add a reason to any entry so the '
      'decision is clear to the next reviewer.';
  @override
  String get addWardOfficerTitle => 'Add ward officer';
  @override
  String get addWardOfficerSubtitle =>
      'Create an account and assign the officer to a ward. '
      'A confirmation email is sent automatically.';
  @override
  String get fullNameExample => 'e.g. Anita Sharma';
  @override
  String get emailAddressLabel => 'Email address';
  @override
  String get emailExample => 'officer@nagarsathi.gov';
  @override
  String get phoneNumberLabel => 'Phone number';
  @override
  String get phoneExample => '+977 98XXXXXXXX';
  @override
  String get assignedWardLabel => 'Assigned ward';
  @override
  String get municipalityLabel => 'Municipality';
  @override
  String get createOfficerLabel => 'Create officer';
  @override
  String get officerEmailExists => 'An officer with this email already exists';
  @override
  String get reassignWardTitle => 'Reassign ward';
  @override
  String reassignWardSubtitle(String name, String ward) =>
      'Move $name from $ward to a new ward.';
  @override
  String get newWardLabel => 'New ward';
  @override
  String get reasonLabel => 'Reason';
  @override
  String get reassignReasonHint => 'e.g. Ward coverage rebalanced';
  @override
  String get updateWardLabel => 'Update ward';
  @override
  String get reassignReasonRequired => 'Enter a reason for reassignment';
  @override
  String get chooseDifferentWard =>
      'Choose a ward different from the current one.';
  @override
  String get addReasonTitle => 'Add a reason';
  @override
  String addReasonSubtitle(String name) => 'Update the audit entry for $name.';
  @override
  String get reasonHint => 'Why did this action happen?';
  @override
  String get saveReasonLabel => 'Save reason';
  @override
  String get reasonRequiredForAction => 'Enter a reason for this action';
  @override
  String get viewAudit => 'View audit';
  @override
  String get addReasonAction => 'Add reason';
  @override
  String get couldNotLoadOfficerData =>
      'Could not load ward officer data. Please try again.';
  @override
  String get couldNotRefreshOfficerData =>
      'Could not refresh ward officer data.';
  @override
  String get couldNotUpdateOfficerStatus =>
      'Could not update the officer status.';
  @override
  String get couldNotReassignOfficer => 'Could not reassign the officer.';
  @override
  String get couldNotUpdateAuditReason => 'Could not update the audit reason.';
  @override
  String auditReasonUpdated(String name) => 'Audit reason updated for $name.';
  @override
  String officerAddedMessage(String name, String ward, String notification) =>
      '$name added to $ward. $notification';
  @override
  String officerStatusChangedMessage(
    String name,
    String status,
    String notification,
  ) => '$name is now $status. $notification';
  @override
  String officerMovedMessage(String name, String ward, String notification) =>
      '$name moved to $ward. $notification';

  @override
  String get errRequired => 'This field is required';
  @override
  String get errEmailOrPhone => 'Enter your email or phone number';
  @override
  String get errInvalidEmailOrPhone => 'Enter a valid email or phone number';
  @override
  String get errName => 'Enter your full name';
  @override
  String get errNameLength => 'Enter a valid name';
  @override
  String get errEmail => 'Enter your email address';
  @override
  String get errInvalidEmail => 'Enter a valid email address';
  @override
  String get errPhone => 'Enter your phone number';
  @override
  String get errInvalidPhone => 'Enter a valid phone number';
  @override
  String get errNepaliPhone => 'Enter a valid Nepali mobile number';
  @override
  String get errPasswordLength => 'Password must be at least 8 characters';
  @override
  String get errPasswordMatch => 'Passwords do not match';
  @override
  String get errOtpFormat => 'Enter the 6-digit code';
  @override
  String get errOtpWrong => 'That code is incorrect.';
  @override
  String get errOtpExpired => 'That code has expired. Request a new one.';
  @override
  String get errNetwork => 'Check your internet connection and try again.';
  @override
  String get errTimeout => 'Request timed out. Please try again.';
  @override
  String get errTooManyAttempts => 'Too many attempts. Please try again later.';
  @override
  String get errUnknown => 'Something went wrong. Please try again.';

  @override
  String get updateRequired => 'Update required';
  @override
  String get updateAvailable => 'Update available';
  @override
  String get whatsNew => "What's new";
  @override
  String get holdToCancel => 'Press and hold outside to dismiss';
  @override
  String get downloadingUpdate => 'Downloading update…';
  @override
  String get keepAppOpen => 'Keep NagarSathi open';
  @override
  String get useWifi => 'Use Wi-Fi if you can';
}

/// Nepali (देवनागरी) implementation of [AppStrings].
class NepaliStrings extends AppStrings {
  const NepaliStrings();
  static const NepaliStrings instance = NepaliStrings();

  @override
  String get appName => 'नगरसाथी';
  @override
  String get cancel => 'रद्द गर्नुहोस्';
  @override
  String get confirm => 'पुष्टि गर्नुहोस्';
  @override
  String get save => 'बचत गर्नुहोस्';
  @override
  String get retry => 'पुन: प्रयास गर्नुहोस्';
  @override
  String get back => 'पछाडि';
  @override
  String get close => 'बन्द गर्नुहोस्';
  @override
  String get continueText => 'अगाडि बढ्नुहोस्';
  @override
  String get updateNow => 'अहिले अपडेट गर्नुहोस्';
  @override
  String get comingSoon => 'यो सुविधा छिट्टै उपलब्ध हुनेछ।';
  @override
  String get orText => 'वा';
  @override
  String get optional => 'ऐच्छिक';
  @override
  String get success => 'सफल भयो';

  @override
  String get signIn => 'साइन इन गर्नुहोस्';
  @override
  String get signUp => 'साइन अप गर्नुहोस्';
  @override
  String get forgotPassword => 'पासवर्ड बिर्सनुभयो?';
  @override
  String get createAccount => 'नयाँ खाता खोल्नुहोस्';
  @override
  String get welcomeBack => 'पुन: स्वागत छ';
  @override
  String get emailOrPhone => 'इमेल वा फोन नम्बर';
  @override
  String get email => 'इमेल';
  @override
  String get phone => 'फोन';
  @override
  String get fullName => 'पूरा नाम';
  @override
  String get password => 'पासवर्ड';
  @override
  String get confirmPassword => 'पासवर्ड पुष्टि गर्नुहोस्';
  @override
  String get enterCode => '६ अंकको कोड राख्नुहोस्';
  @override
  String get sendCode => 'प्रमाणीकरण कोड पठाउनुहोस्';
  @override
  String get resendCode => 'कोड पुनः पठाउनुहोस्';
  @override
  String get rememberMe => 'यो डिभाइसमा मलाई सम्झिराख्नुहोस्';
  @override
  String get continueWithGoogle => 'गुगलबाट जारी राख्नुहोस्';
  @override
  String get continueWithFacebook => 'फेसबुकबाट जारी राख्नुहोस्';
  @override
  String get dontHaveAccount => 'खाता छैन?';
  @override
  String get alreadyHaveAccount => 'पहिले नै खाता छ?';
  @override
  String get staffPortal => 'कर्मचारी पोर्टल';
  @override
  String get citizenPortal => 'नागरिक साइन इन';
  @override
  String get staffWorkspace => 'कर्मचारी कार्यक्षेत्र';
  @override
  String get staffBadge => 'नगरपालिका कर्मचारी';
  @override
  String get tryAnotherWay => 'अर्को तरिकाबाट साइन इन गर्नुहोस्';
  @override
  String get usePassword => 'पासवर्ड प्रयोग गर्नुहोस्';
  @override
  @override
  String get termsDisclaimer =>
      'अगाडि बढेर तपाईं नगरसाथीका सर्तहरू र गोपनीयता नीतिमा सहमत हुनुहुन्छ।';
  @override
  String get resetPasswordTitle => 'पासवर्ड रिसेट गर्नुहोस्';
  @override
  String get sendResetLink => 'रिसेट निर्देशन पठाउनुहोस्';
  @override
  String get newToNagarSathi => 'नगरसाथीमा नयाँ हुनुहुन्छ?';
  @override
  String get areYouStaff => 'तपाईं नगरपालिका कर्मचारी हुनुहुन्छ? ';
  @override
  String get changeIdentifier => 'बदल्नुहोस्';
  @override
  String get verifyAndSignIn => 'प्रमाणीकरण गरी साइन इन गर्नुहोस्';
  @override
  String get emailOrPhoneHint => 'इमेल वा ९८XXXXXXXX';
  @override
  String get passwordHint => 'आफ्नो पासवर्ड राख्नुहोस्';
  @override
  String get otpHint => '६-अंकको कोड';
  @override
  String get noAccountFoundBanner => 'यो इमेलबाट कुनै खाता भेटिएन।';
  @override
  String get phoneOtpSoon =>
      'साइन इन गर्न इमेल प्रयोग गर्नुहोस्। फोन OTP छिट्टै आउनेछ।';
  @override
  String get verificationCode => 'प्रमाणीकरण कोड';
  @override
  @override
  String get passwordMethodSubtitle => 'आफ्नो खाताको पासवर्ड राख्नुहोस्';
  @override
  String get googleSignInSubtitle => 'आफ्नो Google खाताबाट साइन इन गर्नुहोस्';
  @override
  String get facebookSignInSubtitle =>
      'आफ्नो Facebook खाताबाट साइन इन गर्नुहोस्';
  @override
  String get emailSignInLink => 'इमेल लिङ्कबाट साइन इन गर्नुहोस्';
  @override
  String get emailSignInLinkSubtitle =>
      'तपाईंको इनबक्समा सुरक्षित साइन-इन लिङ्क पठाउनुहोस्';
  @override
  String get emailSignInLinkFailure =>
      'साइन-इन लिङ्क पठाउन सकिएन। कृपया फेरि प्रयास गर्नुहोस्।';
  @override
  String emailSignInLinkSent(String email) =>
      '$email मा साइन-इन लिङ्क पठाइयो। साइन इन गर्न यही डिभाइसमा खोल्नुहोस्।';
  @override
  String get emailSignInLinkEnterEmail =>
      'यो साइन-इन लिङ्क प्राप्त गर्ने इमेल ठेगाना राख्नुहोस्।';
  @override
  String get credentialHelp =>
      'पासवर्ड गलत छ वा Google/Facebook बाट खाता खोल्नुभएको हो? तलको “अर्को तरिकाबाट साइन इन गर्नुहोस्” छान्नुहोस् वा पासवर्ड रिसेट लिङ्क पठाउनुहोस्।';
  @override
  String get orContinueWith => 'वा यसबाट जारी राख्नुहोस्';
  @override
  String get firebaseNoResponse =>
      'Firebase बाट जवाफ आएन। इन्टरनेट जाँचेर फेरि प्रयास गर्नुहोस्।';
  @override
  String get signInFailure => 'साइन इन पूरा भएन। कृपया फेरि प्रयास गर्नुहोस्।';
  @override
  String get sendCodeFailure => 'कोड पठाउन सकिएन। कृपया फेरि प्रयास गर्नुहोस्।';
  @override
  String get facebookSignInFailure =>
      'Facebook साइन इन असफल भयो। कृपया फेरि प्रयास गर्नुहोस्।';
  @override
  String get switchToLightMode => 'उज्यालो मोडमा बदल्नुहोस्';
  @override
  String get switchToDarkMode => 'गाढा मोडमा बदल्नुहोस्';
  @override
  String continueAs(String name) => '$name को रूपमा जारी राख्नुहोस्';
  @override
  String chooseSignInMethodFor(String identifier) =>
      '$identifier मा साइन इन गर्ने तरिका छान्नुहोस्:';
  @override
  String verificationCodeSent(String email) =>
      '$email मा प्रमाणीकरण कोड पठाइयो';
  @override
  String passwordResetLinkSent(String email) =>
      '$email मा पासवर्ड रिसेट लिङ्क पठाइयो';
  @override
  String passwordResetSentCheckInbox(String email) =>
      '$email मा रिसेट लिङ्क पठाइयो। इनबक्स हेर्नुहोस्।';
  @override
  String get emailLinkAction => 'इमेल लिङ्क';
  @override
  String get editEmail => 'बदल्नुहोस्';
  @override
  String resendIn(int seconds) =>
      '${AppLocale.ne.formatDigits(seconds.toString())} सेकेन्डमा पुनः पठाउनुहोस्';
  @override
  String stepOfTotal(int step, int total) =>
      '${AppLocale.ne.formatDigits(step.toString())} / ${AppLocale.ne.formatDigits(total.toString())}';
  @override
  String otpSentNotice(String email) =>
      '$email मा ६-अंकको कोड पठाइएको छ। यो ५ मिनेटमा समाप्त हुन्छ।';
  @override
  String get pwdRuleLength => 'कम्तिमा ८ अक्षर';
  @override
  String get pwdRuleNumber => 'एउटा अंक (०–९)';
  @override
  String get pwdRuleSymbolOrUpper => 'ठूलो अक्षर वा चिन्ह';
  @override
  String get pwdStrengthWeak => 'धेरै छोटो';
  @override
  String get pwdStrengthFair => 'सामान्य';
  @override
  String get pwdStrengthGood => 'राम्रो';
  @override
  String get pwdStrengthStrong => 'बलियो';
  @override
  String get signUpPhoneHelper =>
      'अत्यावश्यक वडा सूचनाका लागि मात्र प्रयोग गरिनेछ।';
  @override
  String get acceptTermsNotice => 'अगाडि बढ्न सर्तहरू स्वीकार गर्नुहोस्।';
  @override
  String get agreeToTermsPrefix => 'म ';
  @override
  String get termsOfServiceLabel => 'सेवाका सर्तहरू';
  @override
  String get andLabel => ' र ';
  @override
  String get privacyPolicyLabel => 'गोपनीयता नीति';

  @override
  String get mascotDefaultLogin =>
      'नमस्ते साथी! समस्या दर्ता गर्न र प्रगति हेर्न साइन इन गर्नुहोस्।';
  @override
  String get mascotDefaultSignUp =>
      'आफ्नो नगरलाई सुन्दर बनाउन नगरसाथीमा जोडिनुहोस्।';
  @override
  String get mascotPasswordPrompt =>
      'कम्तिमा ८ अक्षरहरू। म हेर्दिनँ, ढुक्क हुनुहोस्!';
  @override
  String get mascotForgotPrompt =>
      'बिर्सनुभयो? केही छैन, सबैलाई बिर्सने बानी हुन्छ।';
  @override
  String get mascotForgotSent => 'पठाइयो! एकैछिनमा आफ्नो इनबक्स हेर्नुहोस्।';
  @override
  String get mascotForgotFocused => 'इमेल वा फोन — जे भए पनि हुन्छ।';
  @override
  String get mascotStepYourDetails =>
      'तपाईं को हुनुहुन्छ र कसरी सम्पर्क गर्ने बताउनुहोस्।';
  @override
  String get mascotStepSecure =>
      'आफ्नो खाता सुरक्षित गर्न बलियो पासवर्ड राख्नुहोस्।';
  @override
  String get mascotStepVerify =>
      'तपाईंको इमेलमा पठाइएको ६ अंकको कोड राख्नुहोस्।';
  @override
  String get mascotAllSet => 'सबै तयार भयो! नगरसाथीमा स्वागत छ।';
  @override
  String get mascotTryAgain => 'विवरण जाँचेर फेरि प्रयास गर्नुहोस्।';
  @override
  String get mascotGoogleLoading => 'गुगल खुल्दैछ… आफ्नो खाता छान्नुहोस्।';
  @override
  String get mascotCreatingAccount => 'तपाईंको नागरिक खाता बनाइँदैछ…';
  @override
  String get mascotLoginReady => 'नमस्ते! तपाईं तयार भएपछि सुरु गरौँ।';
  @override
  String get mascotEmailSpotted => 'इमेल भेटियो। राम्रो छ!';
  @override
  String get mascotPhoneSpotted => 'फोन नम्बर भेटियो। राम्रो छ!';
  @override
  String get mascotTypeEither => 'इमेल वा फोन नम्बर लेख्नुहोस् — म मिलाउनेछु।';
  @override
  String get mascotCheckingAccount => 'खाता जाँच्दैछ…';
  @override
  String get mascotVerifyingCode => 'कोड प्रमाणीकरण हुँदैछ…';
  @override
  String get mascotCheckingDetails => 'विवरण जाँच्दैछ…';
  @override
  String get mascotEnterPassword => 'साइन इन गर्न आफ्नो पासवर्ड राख्नुहोस्।';
  @override
  String get mascotPasswordPrivate =>
      'तपाईंको पासवर्ड गोप्य रहन्छ। ढुक्क हुनुहोस्।';
  @override
  String get mascotAccountNotFound => 'यो इमेलबाट कुनै खाता भेटिएन।';
  @override
  String get mascotOpeningGoogle => 'गुगल खुल्दैछ… आफ्नो खाता छान्नुहोस्।';
  @override
  String get mascotOpeningFacebook => 'फेसबुक खुल्दैछ… केही क्षण पर्खनुहोस्।';
  @override
  String get mascotOpeningCity => 'पुन: स्वागत छ! तपाईंको नगर खुल्दैछ…';

  @override
  String greeting(String name) => 'नमस्ते, $name';
  @override
  String get goodMorning => 'शुभ प्रभात';
  @override
  String get goodAfternoon => 'शुभ दिउँसो';
  @override
  String get goodEvening => 'शुभ साँझ';
  @override
  String get setYourLocation => 'आफ्नो स्थान छान्नुहोस्';
  @override
  String get locating => 'स्थान खोजिँदैछ…';
  @override
  String get reportHeroTitle => 'तपाईंको नगरमा समस्या देख्नुभयो?';
  @override
  String get reportHeroSubtitle =>
      'खाल्डाखुल्डी, फोहोर, पानी चुहावट तत्काल दर्ता गर्नुहोस् र समाधान ट्र्याक गर्नुहोस्।';
  @override
  String get reportNow => 'समस्या दर्ता गर्नुहोस्';
  @override
  String get reportInOneTap => 'एकै ट्यापमा रिपोर्ट गर्नुहोस्';
  @override
  String get aroundYou => 'तपाईंको वरिपरि';
  @override
  String get seeAll => 'सबै हेर्नुहोस्';
  @override
  String get noReportsYet => 'तपाईंको क्षेत्रमा हाल कुनै रिपोर्ट छैन।';
  @override
  String get categoryPothole => 'सडक खाल्डो';
  @override
  String get categoryWaste => 'फोहोरमैला';
  @override
  String get categoryStreetlight => 'सडक बत्ती';
  @override
  String get categoryWater => 'पानी चुहावट';
  @override
  String get categorySewer => 'ढल निकास';
  @override
  String get categoryTree => 'ढलेको रुख';
  @override
  String get navHome => 'गृहपृष्ठ';
  @override
  String get navReports => 'मेरो रिपोर्ट';
  @override
  String get navNotifications => 'सूचनाहरू';
  @override
  String get navProfile => 'प्रोफाइल';
  @override
  String get navProgress => 'प्रगति';
  @override
  String get staffWardReports => 'वडा रिपोर्ट';
  @override
  String get staffProgress => 'प्रगति';
  @override
  String get staffWardLabel => 'वडा ४ · लेकसाइड';
  @override
  List<String> get staffTips => const [
    'तपाईंको वडा कार्यसूची एक ट्यापमै।',
    'छिमेकीले रिपोर्ट गरेका समस्या समाधान गर्नुहोस्।',
    'आजै वडाको प्रगति अघि बढाउनुहोस्।',
  ];
  @override
  String get staffWardSnapshot => 'वडा सारांश';
  @override
  String get staffWardClear => 'केही बाँकी छैन — तपाईंको वडा सफा छ।';
  @override
  String get staffAssignedWard => 'तोकिएको वडा';
  @override
  String get staffUpdateQueue => 'वडा कार्यसूची हेर्नुहोस्';
  @override
  String get staffProfileTitle => 'कर्मचारी प्रोफाइल';
  @override
  String get staffAccessLevel => 'पहुँच स्तर';
  @override
  String get superAdminBadge => 'सुपर एडमिन';
  @override
  String get superAdminConsole => 'सुपर एडमिन कन्सोल';
  @override
  String get superAdminSubtitle =>
      'वडा अधिकृत बनाउनुहोस् र अडिट रेकर्डमा नजर राख्नुहोस्।';
  @override
  String get createWardOfficer => 'वडा अधिकृत बनाउनुहोस्';
  @override
  String get openAuditTrail => 'अडिट रेकर्ड खोल्नुहोस्';
  @override
  String get officersLabel => 'अधिकृतहरू';
  @override
  String get auditEventsLabel => 'अडिट घटना';
  @override
  String get quickActions => 'छिटो कार्यहरू';
  @override
  String get navMap => 'नक्सा';
  @override
  String get somethingBrokenNearby => 'वरिपरि केही बिग्रिएको छ?';
  @override
  String get communityReporting => 'सामुदायिक रिपोर्टिङ';
  @override
  String get reportHeroPrompt =>
      'फोटो र छोटो विवरण पठाउनुहोस्। यो सिधै समस्या समाधान गर्ने शाखामा पुग्छ।';
  @override
  String get findingYourWard => 'तपाईंको वडा खोजिँदैछ…';
  @override
  String get areYouFrom => 'तपाईं यहाँबाट हुनुहुन्छ?';
  @override
  String get phoneLocationNotice =>
      'हामीले तपाईंको फोनको लोकेसन प्रयोग गर्यौं। रिपोर्टहरू यो वडा कार्यालयमा पठाइनेछ।';
  @override
  String get yesThatsMe => 'हो, म यहीँबाट हुँ';
  @override
  String get notQuite => 'होइन, फरक छ';
  @override
  String get categoryRoads => 'सडक';
  @override
  String get categoryGarbage => 'फोहोरमैला';
  @override
  String get categoryLights => 'सडक बत्ती';
  @override
  String get categoryWaterHero => 'खानेपानी';
  @override
  String wardLabel(String number) =>
      'वडा नं. ${AppLocale.ne.formatDigits(number)}';
  @override
  String get wardSavedSession => 'यो सत्रको लागि वडा सुरक्षित गरियो।';
  @override
  String get wardSavedProfile => 'तपाईंको प्रोफाइलमा वडा सुरक्षित गरियो।';
  @override
  String get wardSyncFailed =>
      'वडा सिङ्क गर्न सकिएन। पुनः प्रयास गर्न थिच्नुहोस्।';
  @override
  String get wardConfirmTitle => 'आफ्नो वडा पुष्टि गर्नुहोस्';
  @override
  String wardConfirmSubtitle(String ward, String municipality) =>
      'तपाईंको स्थान अनुसार तपाईं ${AppLocale.ne.formatDigits(ward)}, $municipality मा हुनुहुन्छ।';
  @override
  String get changeWard => 'वडा बदल्नुहोस्';

  @override
  String get appearanceTitle => 'स्वरूप';
  @override
  String get settingsTitle => 'सेटिङहरू';
  @override
  String get themeTitle => 'थिम';
  @override
  String get themeSubtitle =>
      'नगरसाथीको स्वरूप छान्नुहोस्। सिस्टमले डिभाइस अनुसार मिलाउनेछ।';
  @override
  String get themeSystem => 'सिस्टम';
  @override
  String get themeSystemDesc => 'डिभाइसको सेटिङ अनुसार';
  @override
  String get themeLight => 'उज्यालो';
  @override
  String get themeLightDesc => 'हल्का र सफा पृष्ठभूमि';
  @override
  String get themeDark => 'गाढा';
  @override
  String get themeDarkDesc => 'रातिको लागि आँखालाई सहज';
  @override
  String get languageTitle => 'भाषा';
  @override
  String get languageSubtitle =>
      'नगरसाथीको लागि आफ्नो मनपर्ने भाषा छान्नुहोस्।';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageEnglishDesc => 'English · Default';
  @override
  String get languageNepali => 'नेपाली';
  @override
  String get languageNepaliDesc => 'नेपाली भाषा · Nepali';
  @override
  String get signOut => 'साइन आउट';
  @override
  String versionText(String version) =>
      'नगरसाथी · संस्करण ${AppLocale.ne.formatDigits(version)}';
  @override
  String get checkForUpdates => 'अपडेट जाँच गर्नुहोस्';
  @override
  String get upToDate => 'नगरसाथी अद्यावधिक छ।';

  @override
  String get settings => 'सेटिङहरू';
  @override
  String get settingsSubtitle => 'नगरसाथीको रूप र भाषा छान्नुहोस्।';
  @override
  String get appearanceShort => 'स्वरूप';
  @override
  String get languageShort => 'भाषा';
  @override
  String get systemShort => 'सिस्टम';
  @override
  String get lightShort => 'उज्यालो';
  @override
  String get darkShort => 'गाढा';
  @override
  String get openSettings => 'सेटिङ खोल्नुहोस्';
  @override
  String get neighbour => 'छिमेकी';
  @override
  String get citizenAccount => 'नागरिक खाता';
  @override
  String get citizenBadge => 'नागरिक';
  @override
  String get appTagline => 'नगरसाथी · तपाईंको नगर, तपाईंको साथमा';

  @override
  List<String> get homeTips => const [
    'आज तपाईंको नगरमा के बनाउनुपर्ने छ?',
    'सडक खाल्डो देख्नुभयो? म सुन्न तयार छु।',
    'सानो रिपोर्टले ठुलो फरक पार्न सक्छ।',
    'सडक बत्ती बन्द? फोहोर जम्मा हुँदै? मलाई भन्नुहोस्।',
    'तपाईंले रिपोर्ट गर्दा तपाईंको वडा अझ राम्रो बन्छ।',
  ];
  @override
  String get reportOverflowBin => 'चोकमा फोहोर भरिएको डस्टबिन';
  @override
  String get reportOverflowBinMeta => 'बानेश्वर · २ घण्टा अघि';
  @override
  String get reportPotholeTitle => 'मुख्य सडकमा खाल्डो';
  @override
  String get reportPotholeMeta => 'माइतीघर · हिजो';
  @override
  String get reportStreetlightTitle => 'गल्लीको सडक बत्ती बन्द';
  @override
  String get reportStreetlightMeta => 'वडा १२ · २ दिन अघि';
  @override
  String get statusInProgress => 'कार्य भइरहेको';
  @override
  String get statusReported => 'रिपोर्ट गरियो';
  @override
  String get statusResolved => 'समाधान भयो';
  @override
  String hoursAgo(int hours) => '${AppLocale.ne.formatDigits(hours)} घण्टा अघि';
  @override
  String daysAgo(int days) => '${AppLocale.ne.formatDigits(days)} दिन अघि';
  @override
  String get yesterdayLabel => 'हिजो';

  @override
  String get locationTimeout =>
      'तपाईंको वडा खोज्न धेरै समय लाग्यो। कृपया फेरि प्रयास गर्नुहोस्।';
  @override
  String get wardNotConfirmed =>
      'केही छैन। पुनः प्रयास गर्न स्थान पिलमा थिच्नुहोस्।';
  @override
  String updateCheckFailed(String error) => 'अपडेट जाँच्न सकिएन: $error';

  @override
  String get staffWorkspaceSubtitle => 'तपाईंको नगरपालिका कार्यसूची एकै नजरमा।';
  @override
  String get staffSignedInLabel => 'साइन इन';
  @override
  String get staffWelcomeTitle => 'स्वागत छ, कर्मचारी';
  @override
  String get staffClearedBody =>
      'तपाईं नागरिक अनुरोध र वडा अपडेटका लागि अधिकृत हुनुहुन्छ।';
  @override
  String get appAdmin => 'एप प्रशासक';
  @override
  String get wardOfficerManagement => 'वडा अधिकृत व्यवस्थापन';
  @override
  String get wardOfficerManagementDesc =>
      'खाता बनाउनुहोस्, पहुँच निलम्बन वा पुनः सक्रिय गर्नुहोस्, वडा परिवर्तन '
      'गर्नुहोस् र अडिट रेकर्ड हेर्नुहोस्।';
  @override
  String get todaysQueue => 'आजको कार्यसूची';
  @override
  String get statOpen => 'खुला';
  @override
  String get statResolved => 'समाधान';
  @override
  String get statAvgTime => 'औसत समय';
  @override
  String get queueRoadRepair => 'सडक मर्मत';
  @override
  String get queueRoadRepairMeta => 'वडा ४ · लेकसाइड रोड';
  @override
  String get queueStreetlight => 'सडक बत्ती';
  @override
  String get queueStreetlightMeta => 'वडा २ · दरबारमार्ग';
  @override
  String get queueWaste => 'फोहोर संकलन';
  @override
  String get queueWasteMeta => 'वडा ७ · बानेश्वर';
  @override
  String get statusPriority => 'प्राथमिकता';
  @override
  String get statusNew => 'नयाँ';
  @override
  String get statusOpen => 'खुला';
  @override
  String get signOutOfStaff => 'साइन आउट';
  @override
  String get staffSignInTitle => 'कर्मचारी साइन इन';
  @override
  String get staffBadgeShort => 'कर्मचारी';
  @override
  String get staffEnterPassword => 'पासवर्ड राख्नुहोस्';
  @override
  String get staffForgotPassword => 'पासवर्ड बिर्सनुभयो?';
  @override
  String get staffPasswordResetNeedsEmail =>
      'पहिले आफ्नो कार्य इमेल राख्नुहोस्, त्यसपछि पासवर्ड बिर्सनुभयो? थिच्नुहोस्।';
  @override
  String staffPasswordResetSent(String email) =>
      '$email मा खाता भए रिसेट लिंक पठाइँदै छ। इनबक्स हेर्नुहोस्।';
  @override
  String get staffSendCode => 'कोड पठाउनुहोस्';
  @override
  String get staffWorkEmail => 'कार्यालयको इमेल ठेगाना';
  @override
  String get staffWorkEmailHint => 'you@municipality.gov.np';
  @override
  String get staffMobileNumberHint => '९८XXXXXXXX वा +९७७ ९८XXXXXXXX';
  @override
  String get staffNepaliMobileOnly => 'नेपालका मोबाइल नम्बर मात्र (+९७७)।';
  @override
  String get staffAccessIssued => 'पहुँच तपाईंको नगरपालिकाले प्रदान गर्छ।';
  @override
  String get staffSetPermanentPassword => 'स्थायी पासवर्ड राख्नुहोस्';
  @override
  String get staffTemporaryPasswordInstructions =>
      'तपाईं अस्थायी पासवर्डबाट साइन इन गर्दै हुनुहुन्छ। जारी राख्न नयाँ '
      'स्थायी पासवर्ड राख्नुहोस्।';
  @override
  String get staffNewPassword => 'नयाँ पासवर्ड';
  @override
  String get staffChangePassword => 'पासवर्ड परिवर्तन गर्नुहोस्';
  @override
  String get staffPasswordChanged => 'तपाईंको पासवर्ड अद्यावधिक भयो।';
  @override
  String get staffPasswordMismatch => 'दुवै पासवर्ड मिल्नुपर्छ।';
  @override
  String get staffPasswordLengthHint => 'कम्तीमा ६ अक्षर';
  @override
  String get staffPasswordLengthError => 'पासवर्ड कम्तीमा ६ अक्षरको हुनुपर्छ';
  @override
  String get staffConfirmNewPassword => 'नयाँ पासवर्ड पुष्टि गर्नुहोस्';
  @override
  String get staffReenterPassword => 'नयाँ पासवर्ड फेरि राख्नुहोस्';
  @override
  String get staffUpdateAndSignIn => 'अपडेट गरी साइन इन गर्नुहोस्';
  @override
  String get staffCancelAndSignOut => 'रद्द गरी साइन आउट गर्नुहोस्';

  @override
  String get wardOfficersTitle => 'वडा अधिकृतहरू';
  @override
  String appAdminSubtitle(String admin) => 'एप प्रशासक · $admin';
  @override
  String get officersTab => 'अधिकृतहरू';
  @override
  String get auditTrailTab => 'अडिट रेकर्ड';
  @override
  String get searchOfficersHint => 'नाम, इमेल, फोन वा वडा खोज्नुहोस्';
  @override
  String get auditSearchHint => 'अधिकारी, कार्य वा कारण खोज्नुहोस्';
  @override
  String get exportCsv => 'CSV निर्यात गर्नुहोस्';
  @override
  String get exportFailed => 'प्रतिवेदन निर्यात गर्न सकिएन।';
  @override
  String get allWards => 'सबै वडा';
  @override
  String get allStatuses => 'सबै स्थिति';
  @override
  String get totalLabel => 'कुल';
  @override
  String get activeLabel => 'सक्रिय';
  @override
  String get suspendedLabel => 'निलम्बित';
  @override
  String officerCount(int count) =>
      count == 1 ? '१ अधिकृत' : '${AppLocale.ne.formatDigits(count)} अधिकृत';
  @override
  String get noWardOfficersTitle => 'अहिलेसम्म कुनै वडा अधिकृत छैन';
  @override
  String get noOfficersMatchTitle => 'कुनै अधिकृत भेटिएन';
  @override
  String get noWardOfficersBody =>
      'वडा तोक्न र प्रशासकीय कार्य ट्र्याक गर्न पहिलो अधिकृत खाता बनाउनुहोस्।';
  @override
  String get noOfficersMatchBody =>
      'फरक खोजी गर्नुहोस् वा वडा र स्थिति फिल्टर हटाउनुहोस्।';
  @override
  String get clearFilters => 'फिल्टर हटाउनुहोस्';
  @override
  String get addOfficer => 'अधिकृत थप्नुहोस्';
  @override
  String get recentActivity => 'हालैका गतिविधि';
  @override
  String auditEntryCount(int count) => count == 1
      ? '१ प्रविष्टि'
      : '${AppLocale.ne.formatDigits(count)} प्रविष्टि';
  @override
  String get noAuditEntriesTitle => 'अहिलेसम्म कुनै अडिट प्रविष्टि छैन';
  @override
  String get noAuditEntriesBody =>
      'अधिकृत बनाउनुहोस्, निलम्बन वा पुनः सक्रिय गर्नुहोस्, वा वडा परिवर्तन '
      'गर्नुहोस् — कार्य यहाँ देखिनेछ।';
  @override
  String get reassign => 'वडा परिवर्तन';
  @override
  String get accountActive => 'खाता सक्रिय';
  @override
  String get accountSuspended => 'खाता निलम्बित';
  @override
  String get auditInfo =>
      'हरेक प्रशासकीय कार्य रेकर्ड गरिन्छ। अर्को समीक्षकलाई निर्णय स्पष्ट होस् '
      'भनेर कुनै पनि प्रविष्टिमा कारण थप्नुहोस्।';
  @override
  String get addWardOfficerTitle => 'वडा अधिकृत थप्नुहोस्';
  @override
  String get addWardOfficerSubtitle =>
      'खाता बनाउनुहोस् र अधिकृतलाई वडा तोक्नुहोस्। '
      'पुष्टिकरण इमेल स्वतः पठाइनेछ।';
  @override
  String get fullNameExample => 'जस्तै: अनिता शर्मा';
  @override
  String get emailAddressLabel => 'इमेल ठेगाना';
  @override
  String get emailExample => 'officer@nagarsathi.gov';
  @override
  String get phoneNumberLabel => 'फोन नम्बर';
  @override
  String get phoneExample => '+977 98XXXXXXXX';
  @override
  String get assignedWardLabel => 'तोकिएको वडा';
  @override
  String get municipalityLabel => 'नगरपालिका';
  @override
  String get createOfficerLabel => 'अधिकृत बनाउनुहोस्';
  @override
  String get officerEmailExists => 'यो इमेल भएको अधिकृत पहिले नै छ';
  @override
  String get reassignWardTitle => 'वडा परिवर्तन गर्नुहोस्';
  @override
  String reassignWardSubtitle(String name, String ward) =>
      '$name लाई $ward बाट नयाँ वडामा सार्नुहोस्।';
  @override
  String get newWardLabel => 'नयाँ वडा';
  @override
  String get reasonLabel => 'कारण';
  @override
  String get reassignReasonHint => 'जस्तै: वडा जिम्मेवारी पुनः मिलाइयो';
  @override
  String get updateWardLabel => 'वडा अद्यावधिक गर्नुहोस्';
  @override
  String get reassignReasonRequired => 'वडा परिवर्तनको कारण लेख्नुहोस्';
  @override
  String get chooseDifferentWard => 'हालको भन्दा फरक वडा छान्नुहोस्।';
  @override
  String get addReasonTitle => 'कारण थप्नुहोस्';
  @override
  String addReasonSubtitle(String name) =>
      '$name को अडिट प्रविष्टि अद्यावधिक गर्नुहोस्।';
  @override
  String get reasonHint => 'यो कार्य किन भयो?';
  @override
  String get saveReasonLabel => 'कारण सुरक्षित गर्नुहोस्';
  @override
  String get reasonRequiredForAction => 'यो कार्यको कारण लेख्नुहोस्';
  @override
  String get viewAudit => 'अडिट हेर्नुहोस्';
  @override
  String get addReasonAction => 'कारण थप्नुहोस्';
  @override
  String get couldNotLoadOfficerData =>
      'वडा अधिकृतको विवरण लोड गर्न सकिएन। कृपया फेरि प्रयास गर्नुहोस्।';
  @override
  String get couldNotRefreshOfficerData =>
      'वडा अधिकृतको विवरण ताजा गर्न सकिएन।';
  @override
  String get couldNotUpdateOfficerStatus =>
      'अधिकृतको स्थिति अद्यावधिक गर्न सकिएन।';
  @override
  String get couldNotReassignOfficer => 'अधिकृतको वडा परिवर्तन गर्न सकिएन।';
  @override
  String get couldNotUpdateAuditReason => 'अडिट कारण अद्यावधिक गर्न सकिएन।';
  @override
  String auditReasonUpdated(String name) =>
      '$name को अडिट कारण अद्यावधिक गरियो।';
  @override
  String officerAddedMessage(String name, String ward, String notification) =>
      '$name लाई $ward मा थपियो। $notification';
  @override
  String officerStatusChangedMessage(
    String name,
    String status,
    String notification,
  ) => '$name अब $status छ। $notification';
  @override
  String officerMovedMessage(String name, String ward, String notification) =>
      '$name लाई $ward मा सारियो। $notification';

  @override
  String get errRequired => 'यो विवरण आवश्यक छ';
  @override
  String get errEmailOrPhone => 'आफ्नो इमेल वा फोन नम्बर राख्नुहोस्';
  @override
  String get errInvalidEmailOrPhone => 'मान्य इमेल वा फोन नम्बर राख्नुहोस्';
  @override
  String get errName => 'आफ्नो पूरा नाम राख्नुहोस्';
  @override
  String get errNameLength => 'मान्य नाम राख्नुहोस्';
  @override
  String get errEmail => 'आफ्नो इमेल ठेगाना राख्नुहोस्';
  @override
  String get errInvalidEmail => 'मान्य इमेल ठेगाना राख्नुहोस्';
  @override
  String get errPhone => 'आफ्नो फोन नम्बर राख्नुहोस्';
  @override
  String get errInvalidPhone => 'मान्य फोन नम्बर राख्नुहोस्';
  @override
  String get errNepaliPhone => 'मान्य नेपाली मोबाइल नम्बर राख्नुहोस्';
  @override
  String get errPasswordLength => 'पासवर्ड कम्तिमा ८ अक्षरको हुनुपर्छ';
  @override
  String get errPasswordMatch => 'पासवर्डहरू मिलेनन्';
  @override
  String get errOtpFormat => '६ अंकको कोड राख्नुहोस्';
  @override
  String get errOtpWrong => 'त्यो कोड गलत छ।';
  @override
  String get errOtpExpired => 'कोडको म्याद सकियो। नयाँ कोड माग्नुहोस्।';
  @override
  String get errNetwork => 'इन्टरनेट कनेक्सन जाँचेर फेरि प्रयास गर्नुहोस्।';
  @override
  String get errTimeout => 'समय समाप्त भयो। कृपया फेरि प्रयास गर्नुहोस्।';
  @override
  String get errTooManyAttempts =>
      'धेरै पटक प्रयास भयो। कृपया केही समयपछि प्रयास गर्नुहोस्।';
  @override
  String get errUnknown => 'त्रुटि देखा पर्यो। कृपया फेरि प्रयास गर्नुहोस्।';

  @override
  String get updateRequired => 'अपडेट आवश्यक छ';
  @override
  String get updateAvailable => 'अपडेट उपलब्ध छ';
  @override
  String get whatsNew => 'नयाँ के छ?';
  @override
  String get holdToCancel => 'रद्द गर्न बाहिर थिचिराख्नुहोस्';
  @override
  String get downloadingUpdate => 'अपडेट डाउनलोड हुँदैछ…';
  @override
  String get keepAppOpen => 'नगरसाथी एप खुला राख्नुहोस्';
  @override
  String get useWifi => 'सकेसम्म Wi-Fi प्रयोग गर्नुहोस्';
}
