import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_controller.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/validators.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/ns_auth_controls.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_deactivated_account_dialog.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_google_button.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_route.dart';
import '../widgets/ns_shake.dart';
import '../widgets/ns_speech_bubble.dart';
import '../widgets/ns_split_hero_scaffold.dart';
import '../widgets/ns_text_field.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'sign_up_screen.dart';
import 'staff_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.themeController,
    this.languageController,
    this.authService = const AuthService(),
  });

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? themeController;
  final LanguageController? languageController;

  /// Injectable for tests; checks the account's deletion stage on sign-in.
  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  static const _authChannel = MethodChannel('com.softwarica.nagarsathi/auth');

  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _shakeController = NsShakeController();
  StreamSubscription<Uri>? _emailLinkSubscription;

  ThemeController get _themeController =>
      widget.themeController ?? ThemeController.instance;

  LanguageController get _languageController =>
      widget.languageController ?? LanguageController.instance;

  bool _isEmailLinkMode = false;
  bool _isLoading = false;
  bool _celebrating = false;
  bool _showError = false;
  bool _googleLoading = false;
  bool _facebookLoading = false;
  bool _identifierFocused = false;
  bool _passwordFocused = false;
  String? _errorMessage;
  IdentifierKind _kind = IdentifierKind.empty;
  String? _pendingEmailLink;
  String? _lastHandledEmailLink;
  bool _handlingEmailLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AuthService.isConfigured) {
      _emailLinkSubscription = AppLinks().uriLinkStream.listen(
        (uri) => _handleIncomingEmailSignInLink(uri.toString()),
        onError: (Object error) {
          if (error is MissingPluginException) return;
          if (!mounted) return;
          setState(() {
            _showError = true;
            _errorMessage = context.l10n.signInFailure;
          });
        },
      );
      unawaited(_handleInitialEmailSignInLink());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final sub = _emailLinkSubscription;
    if (sub != null) {
      unawaited(sub.cancel().catchError((Object _) {}));
    }
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  NsMascotMood get _mood {
    if (_celebrating) return NsMascotMood.celebrate;
    if (_showError) {
      return _isWrongCredentials ? NsMascotMood.angry : NsMascotMood.sad;
    }
    if (_passwordFocused) {
      // Eyes shut while the password is typed, so it never peeks.
      return NsMascotMood.sleepy;
    }
    if (_identifierFocused) return NsMascotMood.curious;
    return NsMascotMood.happy;
  }

  bool get _isWrongCredentials {
    if (!_showError || _errorMessage == null) return false;
    final message = _errorMessage!.toLowerCase();
    return message.contains('incorrect') || message.contains('wrong password');
  }

  Offset get _look {
    if (_passwordFocused) return const Offset(0, 0.9);
    if (_identifierFocused) return const Offset(0.1, 0.7);
    return const Offset(0.2, 0.1);
  }

  String _message(AppStrings s) {
    if (_celebrating) return s.mascotOpeningCity;
    if (_showError) {
      if (_errorMessage != null &&
          (_errorMessage!.contains('No account found') ||
              _errorMessage == s.noAccountFoundBanner)) {
        return s.mascotAccountNotFound;
      }
      return _errorMessage ?? s.mascotTryAgain;
    }
    if (_googleLoading) return s.mascotOpeningGoogle;
    if (_facebookLoading) return s.mascotOpeningFacebook;
    if (_isLoading) {
      return _isEmailLinkMode ? s.emailSignInLink : s.mascotCheckingDetails;
    }
    if (_isEmailLinkMode) return s.emailSignInLink;
    if (_passwordFocused) return s.mascotPasswordPrivate;
    switch (_kind) {
      case IdentifierKind.email:
        return s.mascotEmailSpotted;
      case IdentifierKind.phone:
        return s.mascotPhoneSpotted;
      case IdentifierKind.unknown:
        return s.mascotTypeEither;
      case IdentifierKind.empty:
        return s.mascotLoginReady;
    }
  }

  bool get _showCredentialHelp {
    if (!_showError || _errorMessage == null) return false;
    final message = _errorMessage!.toLowerCase();
    return message.contains('incorrect') ||
        message.contains('never set a password') ||
        message.contains('no account found') ||
        message.contains(context.l10n.noAccountFoundBanner.toLowerCase());
  }

  bool get _isNotFoundError {
    if (!_showError || _errorMessage == null) return false;
    return _errorMessage!.contains('No account found') ||
        _errorMessage == context.l10n.noAccountFoundBanner;
  }

  void _triggerValidationError([String? message]) {
    HapticFeedback.mediumImpact();
    _shakeController.shake();
    setState(() {
      _isLoading = false;
      _showError = true;
      if (message != null) _errorMessage = message;
    });
  }

  void _onIdentifierChanged(String value) {
    final kind = Validators.identifierKind(value);
    if (kind != _kind || _showError) {
      setState(() {
        _kind = kind;
        _showError = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitPrimary() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    if (_pendingEmailLink != null) {
      await _completePendingEmailSignInLink();
      return;
    }

    if (_isEmailLinkMode) {
      await _requestEmailSignInLink();
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      _triggerValidationError();
      return;
    }

    if (_kind == IdentifierKind.phone) {
      _triggerValidationError(context.l10n.phoneOtpSoon);
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      await widget.authService
          .signIn(
            identifier: _identifierController.text,
            password: _passwordController.text,
          )
          .timeout(const Duration(seconds: 15));
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _triggerValidationError(error.message);
      return;
    } on TimeoutException {
      if (!mounted) return;
      _triggerValidationError(context.l10n.firebaseNoResponse);
      return;
    } catch (_) {
      if (!mounted) return;
      _triggerValidationError(context.l10n.signInFailure);
      return;
    }

    if (!mounted) return;
    _finishSignIn();
  }

  Future<void> _handleInitialEmailSignInLink() async {
    try {
      final link = await AppLinks().getInitialLink();
      if (link != null) {
        await _handleIncomingEmailSignInLink(link.toString());
      }
    } on MissingPluginException {
      // App-link delivery is unavailable in widget tests and unsupported hosts.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showError = true;
        _errorMessage = context.l10n.signInFailure;
      });
    }
  }

  Future<void> _handleIncomingEmailSignInLink(String link) async {
    if (_handlingEmailLink || _lastHandledEmailLink == link) return;
    const service = AuthService();
    if (!service.isEmailSignInLink(link)) return;

    _lastHandledEmailLink = link;
    final String? savedEmail;
    try {
      savedEmail = await service.pendingEmailSignInLinkEmail();
    } catch (_) {
      _lastHandledEmailLink = null;
      if (!mounted) return;
      setState(() {
        _showError = true;
        _errorMessage = context.l10n.signInFailure;
      });
      return;
    }
    if (!mounted) return;
    if (savedEmail == null) {
      setState(() {
        _pendingEmailLink = link;
        _isEmailLinkMode = true;
        _showError = false;
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.emailSignInLinkEnterEmail)),
      );
      return;
    }

    await _completeEmailSignInLink(email: savedEmail, link: link);
  }

  Future<void> _completeEmailSignInLink({
    required String email,
    required String link,
  }) async {
    if (_isLoading || _handlingEmailLink) return;
    _handlingEmailLink = true;
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      await const AuthService().signInWithEmailLink(
        email: email,
        emailLink: link,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _triggerValidationError(error.message);
      _lastHandledEmailLink = null;
      _handlingEmailLink = false;
      return;
    } catch (_) {
      if (!mounted) return;
      _triggerValidationError(context.l10n.signInFailure);
      _lastHandledEmailLink = null;
      _handlingEmailLink = false;
      return;
    }

    if (!mounted) return;
    _handlingEmailLink = false;
    _pendingEmailLink = null;
    _finishSignIn();
  }

  Future<void> _completePendingEmailSignInLink() async {
    final email = _identifierController.text.trim();
    final link = _pendingEmailLink;
    if (link == null) return;
    final emailErr = Validators.identifier(email, strings: context.l10n);
    if (emailErr != null) {
      _triggerValidationError(emailErr);
      return;
    }
    if (_kind != IdentifierKind.email) {
      _triggerValidationError(context.l10n.emailSignInLinkEnterEmail);
      return;
    }
    await _completeEmailSignInLink(email: email, link: link);
  }

  Future<void> _finishSignIn({String? name, String? email}) async {
    await const SessionService().clearStaffSession();
    if (!mounted) return;

    // A deactivated account chooses what happens before the app opens.
    final canEnter = await _confirmActiveAccount();
    if (!mounted) return;
    if (!canEnter) {
      setState(() {
        _isLoading = false;
        _googleLoading = false;
        _facebookLoading = false;
        _celebrating = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _celebrating = true;
    });
    HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      NsPageRoute<void>(
        style: NsTransitionStyle.fade,
        builder: (_) => AppLockGate(
          child: HomeScreen(
            initialName: name,
            initialEmail: email,
            showRememberMePrompt: true,
          ),
        ),
      ),
      (route) => false,
    );
  }

  /// Tells a citizen whose account is inside its 30-day deletion window that
  /// it is being deleted, before they reach the app. Logging in cancels the
  /// deletion; continuing it leaves the citizen signed out.
  ///
  /// Returns true when the citizen may enter the app.
  Future<bool> _confirmActiveAccount() async {
    final CitizenDeletionState state;
    try {
      state = await widget.authService.loadDeletionState();
    } catch (_) {
      return true;
    }
    if (!mounted || !state.deactivated) return true;

    setState(() {
      _isLoading = false;
      _googleLoading = false;
      _facebookLoading = false;
    });
    final choice = await showDeactivatedAccountDialog(
      context: context,
      state: state,
      authService: widget.authService,
    );
    if (!mounted) return false;
    if (choice != DeactivatedAccountChoice.continueDeactivation) return true;

    await widget.authService.signOut();
    if (!mounted) return false;
    final deleteAt = state.deleteAt;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleteAt == null
              ? 'Your account stays deactivated and will be deleted when the '
                    '30 days end.'
              : 'Your account stays deactivated and will be deleted on '
                    '${formatDeletionDate(deleteAt)}.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    return false;
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading || _googleLoading || _facebookLoading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _googleLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    final bool signedIn;
    try {
      signedIn = await const AuthService().signInWithGoogle();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _googleLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    if (!signedIn) {
      setState(() => _googleLoading = false);
      return;
    }

    _finishSignIn();
  }

  Future<void> _closeBrowser() async {
    try {
      await _authChannel.invokeMethod('closeBrowser');
    } catch (_) {}
    try {
      await closeInAppWebView();
    } catch (_) {}
  }

  Future<void> _signInWithFacebook() async {
    if (_isLoading || _googleLoading || _facebookLoading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _facebookLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      final result = await const AuthService().signInWithFacebook();

      if (!mounted) return;

      if (result == null) {
        setState(() => _facebookLoading = false);
        return;
      }

      final String resolvedName = result['name'] ?? '';
      final String resolvedEmail = result['email'] ?? '';

      final bool? confirmed = await _showFacebookConfirmationSheet(
        name: resolvedName.isNotEmpty ? resolvedName : context.l10n.neighbour,
        email: resolvedEmail,
      );

      if (!mounted) return;

      if (confirmed != true) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        setState(() => _facebookLoading = false);
        return;
      }

      _finishSignIn(
        name: resolvedName.isNotEmpty ? resolvedName : null,
        email: resolvedEmail.isNotEmpty ? resolvedEmail : null,
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _facebookLoading = false;
        _showError = true;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _facebookLoading = false;
        _showError = true;
        _errorMessage = context.l10n.facebookSignInFailure;
      });
    }
  }

  Future<bool?> _showFacebookConfirmationSheet({
    required String name,
    required String email,
  }) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: tokens.border, width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1466D8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.facebook_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.continueAs(name),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: tokens.heading,
                            ),
                          ),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                NsPrimaryButton(
                  label: strings.continueAs(name),
                  icon: Icons.check_circle_rounded,
                  onPressed: () {
                    _closeBrowser();
                    Navigator.of(sheetContext).pop(true);
                  },
                ),
                const SizedBox(height: 10),
                NsOutlineButton(
                  label: strings.cancel,
                  onPressed: () {
                    _closeBrowser();
                    Navigator.of(sheetContext).pop(false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestEmailSignInLink() async {
    if (_isLoading) return;
    final identifier = _identifierController.text.trim();
    final emailErr = Validators.email(identifier, strings: context.l10n);
    if (emailErr != null) {
      _triggerValidationError(emailErr);
      return;
    }

    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });
    try {
      await const AuthService().sendEmailSignInLink(
        identifier,
        locale: _languageController.value.code,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEmailLinkMode = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.emailSignInLinkSent(identifier)),
          duration: const Duration(seconds: 6),
        ),
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _triggerValidationError(error.message);
    } catch (_) {
      if (!mounted) return;
      _triggerValidationError(context.l10n.emailSignInLinkFailure);
    }
  }

  void _openTryAnotherWaySheet() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final strings = context.l10n;
    final tokens = NsColors.of(context);
    final identifier = _identifierController.text.trim();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: tokens.border, width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.tryAnotherWay,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: tokens.ink,
                  ),
                ),
                if (identifier.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    strings.chooseSignInMethodFor(identifier),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _OptionTile(
                  icon: Icons.lock_rounded,
                  title: strings.usePassword,
                  subtitle: strings.passwordMethodSubtitle,
                  selected: !_isEmailLinkMode,
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    setState(() {
                      _isEmailLinkMode = false;
                      _showError = false;
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _OptionTile(
                  icon: Icons.mark_email_read_rounded,
                  title: strings.emailSignInLink,
                  subtitle: strings.emailSignInLinkSubtitle,
                  selected: _isEmailLinkMode,
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    setState(() {
                      _isEmailLinkMode = true;
                      _showError = false;
                      _errorMessage = null;
                    });
                    if (Validators.email(identifier) == null) {
                      _requestEmailSignInLink();
                    }
                  },
                ),
                const SizedBox(height: 10),
                _OptionTile(
                  icon: Icons.g_mobiledata_rounded,
                  title: strings.continueWithGoogle,
                  subtitle: strings.googleSignInSubtitle,
                  selected: false,
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _signInWithGoogle();
                  },
                ),
                const SizedBox(height: 10),
                _OptionTile(
                  icon: Icons.facebook_rounded,
                  title: strings.continueWithFacebook,
                  subtitle: strings.facebookSignInSubtitle,
                  selected: false,
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _signInWithFacebook();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSignUp() {
    Navigator.of(context).push(
      NsPageRoute<void>(builder: (_) => const SignUpScreen()),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      NsPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _openStaffSignIn() {
    Navigator.of(context).push(
      NsPageRoute<void>(builder: (_) => const StaffLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NsSplitHeroScaffold(
          topBar: _buildTopBar(),
          hero: _buildHero(),
          sheetChild: NsEntrance(child: _buildSheetContent()),
        ),
        if (_celebrating)
          Positioned.fill(
            child: NsConfetti(
              onCompleted: () {
                if (mounted) setState(() => _celebrating = false);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const NsLogo(size: 30, depth: 0),
        const SizedBox(width: 9),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'NagarSathi',
              style: TextStyle(
                fontSize: 16.5,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        NsAuthPreferencePills(
          onDarkHeader: true,
          themeController: _themeController,
          languageController: _languageController,
        ),
      ],
    );
  }

  Widget _buildHero() {
    final strings = context.l10n;
    final msg = _message(strings);
    final tone = switch (_mood) {
      NsMascotMood.sad || NsMascotMood.angry => NsSpeechTone.error,
      NsMascotMood.celebrate || NsMascotMood.excited => NsSpeechTone.success,
      NsMascotMood.curious || NsMascotMood.sleepy => NsSpeechTone.info,
      _ => NsSpeechTone.neutral,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Align(
                alignment: Alignment.centerRight,
                child: NsSpeechBubble(
                  messages: [msg],
                  speaker: 'Sathi',
                  tailOnRight: true,
                  tone: tone,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          NsMascot(
            size: 88,
            mood: _mood,
            look: _look,
            wave: _celebrating,
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContent() {
    final strings = context.l10n;
    final tokens = NsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.welcomeBack,
          style: TextStyle(
            fontSize: 26,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: tokens.heading,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        NsShake(
          controller: _shakeController,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showError && _errorMessage != null) ...[
                      if (_isNotFoundError)
                        _buildNotFoundBanner()
                      else if (_showCredentialHelp)
                        _buildCredentialHelp()
                      else
                        _buildInlineErrorBanner(),
                      const SizedBox(height: 14),
                    ],
                    NsTextField(
                      controller: _identifierController,
                      label: strings.emailOrPhone,
                      hint: strings.emailOrPhoneHint,
                      icon: _kind == IdentifierKind.phone
                          ? Icons.phone_iphone_rounded
                          : Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: _isEmailLinkMode
                          ? TextInputAction.done
                          : TextInputAction.next,
                      validator: Validators.identifier,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      onChanged: _onIdentifierChanged,
                      onFieldSubmitted: (_) {
                        if (_isEmailLinkMode) {
                          _submitPrimary();
                        } else {
                          _passwordFocusNode.requestFocus();
                        }
                      },
                      onFocusChange: (focused) {
                        setState(() => _identifierFocused = focused);
                      },
                      labelTrailing: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: _kind == IdentifierKind.email
                            ? NsChip(
                                key: const ValueKey('email'),
                                label: strings.email,
                                icon: Icons.mail_rounded,
                                compact: true,
                              )
                            : _kind == IdentifierKind.phone
                            ? NsChip(
                                key: const ValueKey('phone'),
                                label: strings.phone,
                                icon: Icons.smartphone_rounded,
                                tone: NsChipTone.sky,
                                compact: true,
                              )
                            : const SizedBox.shrink(key: ValueKey('empty')),
                      ),
                    ),
                    if (!_isEmailLinkMode) ...[
                      const SizedBox(height: 14),
                      NsTextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        label: strings.password,
                        hint: strings.passwordHint,
                        icon: Icons.lock_rounded,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: Validators.loginPassword,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submitPrimary(),
                        onChanged: (_) {
                          if (_showError) {
                            setState(() {
                              _showError = false;
                              _errorMessage = null;
                            });
                          }
                        },
                        onFocusChange: (focused) {
                          setState(() => _passwordFocused = focused);
                        },
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          _AuthLink(
                            label: strings.emailLinkAction,
                            onPressed: _openTryAnotherWaySheet,
                          ),
                          _AuthLink(
                            label: strings.forgotPassword,
                            onPressed: _openForgotPassword,
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: tokens.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.mark_email_read_rounded,
                              size: 18,
                              color: tokens.accentText,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _pendingEmailLink != null
                                    ? strings.emailSignInLinkEnterEmail
                                    : strings.emailSignInLinkSubtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _AuthLink(
                          label: strings.usePassword,
                          onPressed: () {
                            setState(() {
                              _isEmailLinkMode = false;
                              _pendingEmailLink = null;
                              _showError = false;
                              _errorMessage = null;
                            });
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    NsPrimaryButton(
                      label: _isEmailLinkMode
                          ? strings.emailSignInLink
                          : strings.signIn,
                      isLoading: _isLoading,
                      onPressed: _submitPrimary,
                      icon: _isEmailLinkMode
                          ? Icons.mark_email_read_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        NsAuthDivider(label: strings.orContinueWith),
        const SizedBox(height: 12),
        NsSocialAuthRow(
          onGooglePressed: _signInWithGoogle,
          onFacebookPressed: _signInWithFacebook,
          googleLoading: _googleLoading,
          facebookLoading: _facebookLoading,
        ),
        const SizedBox(height: 18),
        _buildFooter(),
      ],
    );
  }

  Widget _buildInlineErrorBanner() {
    final tokens = NsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.errorBorder.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.errorBorder.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: tokens.errorBorder),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundBanner() {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.errorBorder.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.errorBorder.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: tokens.errorBorder),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? strings.noAccountFoundBanner,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: _openSignUp,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              strings.signUp,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: tokens.accentText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialHelp() {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: tokens.accentText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage ?? strings.credentialHelp,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              _AuthLink(
                label: strings.sendResetLink,
                onPressed: _isLoading
                    ? null
                    : () async {
                        try {
                          await const AuthService().sendPasswordReset(
                            _identifierController.text.trim(),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.passwordResetLinkSent(
                                  _identifierController.text.trim(),
                                ),
                              ),
                            ),
                          );
                        } on AuthFailure catch (e) {
                          if (!mounted) return;
                          setState(() {
                            _showError = true;
                            _errorMessage = e.message;
                          });
                        }
                      },
              ),
              _AuthLink(
                label: strings.emailLinkAction,
                onPressed: _isLoading ? null : _requestEmailSignInLink,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              strings.newToNagarSathi,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: tokens.muted,
              ),
            ),
            TextButton(
              onPressed: _openSignUp,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                strings.signUp,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: tokens.accentText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: InkWell(
            key: const Key('staff-portal-pill'),
            onTap: _openStaffSignIn,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tokens.border, width: 1.2),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 14.5,
                    color: tokens.muted,
                  ),
                  Text(
                    strings.areYouStaff,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.muted,
                    ),
                  ),
                  Text(
                    strings.staffPortal,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: tokens.accentText,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 13.5,
                    color: tokens.accentText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthLink extends StatelessWidget {
  const _AuthLink({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: tokens.accentText,
        disabledForegroundColor: tokens.muted,
        textStyle: const TextStyle(
          fontSize: 12.5,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
      child: Text(label),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.mint : tokens.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : tokens.border,
            width: selected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : tokens.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : tokens.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
