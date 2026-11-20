import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/validators.dart';
import '../widgets/ns_auth_heading.dart';
import '../widgets/ns_auth_scaffold.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_google_button.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_text_field.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'sign_up_screen.dart';
import 'staff_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.themeController});

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? themeController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  ThemeController get _themeController =>
      widget.themeController ?? ThemeController.instance;

  int _step = 0;
  int _direction = 1;
  bool _isOtpMode = false;
  bool _isLoading = false;
  bool _celebrating = false;
  bool _showError = false;
  bool _googleLoading = false;
  bool _identifierFocused = false;
  bool _passwordFocused = false;
  bool _otpFocused = false;
  String? _errorMessage;
  IdentifierKind _kind = IdentifierKind.empty;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  NsMascotMood get _mood {
    if (_celebrating) return NsMascotMood.celebrate;
    if (_showError) return NsMascotMood.sad;
    if (_identifierFocused || _passwordFocused || _otpFocused) {
      return NsMascotMood.curious;
    }
    return NsMascotMood.happy;
  }

  Offset get _look {
    if (_passwordFocused || _otpFocused) return const Offset(0, 0.9);
    if (_identifierFocused) return const Offset(0.1, 0.7);
    return const Offset(0.2, 0.1);
  }

  String get _message {
    if (_celebrating) return 'Welcome back! Opening your city…';
    if (_showError) {
      if (_errorMessage != null &&
          _errorMessage!.contains('No account found')) {
        return 'I could not find an account with that email.';
      }
      return _errorMessage ?? 'Hmm, check that and give it another go.';
    }
    if (_googleLoading) return 'Opening Google… pick your account.';
    if (_isLoading) {
      if (_step == 0) return 'Checking your account…';
      return _isOtpMode ? 'Verifying code…' : 'Checking your details…';
    }
    if (_step == 1) {
      if (_isOtpMode) {
        return 'Enter the 6-digit verification code sent to your email.';
      }
      if (_passwordFocused) return 'Your password stays private. Promise.';
      return 'Enter your password to sign in.';
    }
    switch (_kind) {
      case IdentifierKind.email:
        return 'Email spotted. Looking good!';
      case IdentifierKind.phone:
        return 'Phone number it is. Nice!';
      case IdentifierKind.unknown:
        return 'Type an email or a phone number — I will sort it out.';
      case IdentifierKind.empty:
        return 'Namaste! Ready when you are.';
    }
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

  Future<void> _checkIdentifierAndContinue() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKeyStep0.currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }

    final identifier = _identifierController.text.trim();
    if (_kind == IdentifierKind.phone) {
      HapticFeedback.mediumImpact();
      setState(() {
        _showError = true;
        _errorMessage = 'Use your email to sign in. Phone OTP is coming soon.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showError = false;
    });

    try {
      final exists = await const AuthService().checkEmailExists(identifier);
      if (!mounted) return;

      if (!exists) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isLoading = false;
          _showError = true;
          _errorMessage = 'No account found with this email.';
        });
        return;
      }

      HapticFeedback.selectionClick();
      setState(() {
        _isLoading = false;
        _direction = 1;
        _step = 1;
        _isOtpMode = false;
        _showError = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = 'Could not verify account. Please try again.';
      });
    }
  }

  void _backToIdentifier() {
    FocusScope.of(context).unfocus();
    setState(() {
      _direction = -1;
      _step = 0;
      _isOtpMode = false;
      _showError = false;
      _errorMessage = null;
      _passwordController.clear();
      _otpController.clear();
    });
  }

  Future<void> _signInWithPassword() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKeyStep1.currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await const AuthService().signIn(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    _finishSignIn();
  }

  Future<void> _signInWithOtp() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      HapticFeedback.mediumImpact();
      setState(() {
        _showError = true;
        _errorMessage = 'Enter the 6-digit verification code.';
      });
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await const AuthService().signInWithEmailOtp(
        email: _identifierController.text,
        otp: otp,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    _finishSignIn();
  }

  Future<void> _finishSignIn() async {
    setState(() {
      _isLoading = false;
      _celebrating = true;
    });
    HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading || _googleLoading) return;
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

  Future<void> _requestEmailOtp() async {
    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });
    try {
      await const AuthService().requestEmailOtp(
        _identifierController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOtpMode = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification code sent to ${_identifierController.text.trim()}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
    }
  }

  void _openTryAnotherWaySheet() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: tokens.border, width: 2),
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
                  'Sign in another way',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you would like to sign in as ${_identifierController.text.trim()}:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 16),
                _OptionTile(
                  icon: Icons.lock_rounded,
                  title: 'Use password',
                  subtitle: 'Enter your account password',
                  selected: !_isOtpMode,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    setState(() {
                      _isOtpMode = false;
                      _showError = false;
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _OptionTile(
                  icon: Icons.mark_email_read_rounded,
                  title: 'Get OTP via email',
                  subtitle: 'Send a 6-digit code to your inbox',
                  selected: _isOtpMode,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _requestEmailOtp();
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
      MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _openStaffSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StaffLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backToIdentifier();
      },
      child: Stack(
        children: [
          NsAuthScaffold(
            centerContent: true,
            topBar: _buildTopBar(),
            child: NsEntrance(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('step-$_step'),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(14 * (1 - value) * _direction, 0),
                      child: child,
                    ),
                  );
                },
                child: _buildBody(),
              ),
            ),
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
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        if (_step == 1) ...[
          NsBackButton(onPressed: _backToIdentifier),
          const SizedBox(width: 8),
        ],
        const NsLogo(size: 34, depth: 2),
        const SizedBox(width: 10),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'NagarSathi',
              style: TextStyle(
                fontSize: 17,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: AppColors.forest,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildThemeToggle(),
      ],
    );
  }

  Widget _buildThemeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, mode, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return NsPressable(
          onTap: () {
            HapticFeedback.selectionClick();
            final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
            _themeController.setMode(nextMode);
          },
          color: isDark ? const Color(0xFF243B30) : AppColors.mint,
          borderColor: isDark ? const Color(0xFF325444) : AppColors.primary,
          shadowColor: isDark ? const Color(0xFF0F1A14) : AppColors.primaryDark,
          depth: 2,
          radius: 999,
          expand: false,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          semanticLabel: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 15,
                color: isDark ? AppColors.sun : AppColors.forest,
              ),
              const SizedBox(width: 5),
              Text(
                isDark ? 'Light' : 'Dark',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.forest,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NsAuthHeading(
          title: 'Welcome back',
          message: _message,
          mood: _mood,
          look: _look,
          wave: _celebrating,
        ),
        const SizedBox(height: 16),
        if (_step == 0) _buildStep0() else _buildStep1(),
        if (_step == 0) ...[
          const SizedBox(height: 14),
          const NsAuthDivider(),
          const SizedBox(height: 8),
          NsGoogleButton(
            onPressed: _signInWithGoogle,
            isLoading: _googleLoading,
          ),
          const SizedBox(height: 2),
        ],
        _buildFooter(),
      ],
    );
  }

  Widget _buildStep0() {
    return AutofillGroup(
      child: Form(
        key: _formKeyStep0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NsTextField(
              controller: _identifierController,
              label: 'Email or phone',
              hint: 'you@example.com or 98XXXXXXXX',
              icon: _kind == IdentifierKind.phone
                  ? Icons.phone_iphone_rounded
                  : Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.identifier,
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              onChanged: _onIdentifierChanged,
              onFieldSubmitted: (_) => _checkIdentifierAndContinue(),
              onFocusChange: (focused) {
                setState(() => _identifierFocused = focused);
              },
              labelTrailing: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _kind == IdentifierKind.email
                    ? const NsChip(
                        key: ValueKey('email'),
                        label: 'EMAIL',
                        icon: Icons.mail_rounded,
                        compact: true,
                      )
                    : _kind == IdentifierKind.phone
                    ? const NsChip(
                        key: ValueKey('phone'),
                        label: 'PHONE',
                        icon: Icons.smartphone_rounded,
                        tone: NsChipTone.sky,
                        compact: true,
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
            if (_showError &&
                _errorMessage != null &&
                _errorMessage!.contains('No account found')) ...[
              const SizedBox(height: 10),
              _buildNotFoundBanner(),
            ],
            const SizedBox(height: 18),
            NsPrimaryButton(
              label: 'Continue',
              isLoading: _isLoading,
              onPressed: _checkIdentifierAndContinue,
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundBanner() {
    final tokens = NsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'No account found with this email.',
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
            child: const Text(
              'Sign up',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final tokens = NsColors.of(context);

    return AutofillGroup(
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: tokens.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_rounded,
                    size: 20,
                    color: tokens.ink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _identifierController.text.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _backToIdentifier,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isOtpMode) ...[
              NsTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_rounded,
                obscureText: true,
                autofocus: true,
                textInputAction: TextInputAction.done,
                validator: Validators.loginPassword,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _signInWithPassword(),
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
                labelTrailing: Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _openForgotPassword,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openTryAnotherWaySheet,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Try another way'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primaryDeep,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              NsPrimaryButton(
                label: 'Sign in',
                isLoading: _isLoading,
                onPressed: _signInWithPassword,
                icon: Icons.arrow_forward_rounded,
              ),
            ] else ...[
              NsTextField(
                controller: _otpController,
                label: 'Verification code',
                hint: '6-digit code',
                icon: Icons.pin_rounded,
                keyboardType: TextInputType.number,
                autofocus: true,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (val) {
                  if (val == null || val.trim().length != 6) {
                    return 'Enter the 6-digit code';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _signInWithOtp(),
                onChanged: (_) {
                  if (_showError) {
                    setState(() {
                      _showError = false;
                      _errorMessage = null;
                    });
                  }
                },
                onFocusChange: (focused) {
                  setState(() => _otpFocused = focused);
                },
                labelTrailing: Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _requestEmailOtp,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Resend code',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openTryAnotherWaySheet,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Try another way'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primaryDeep,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              NsPrimaryButton(
                label: 'Verify & sign in',
                isLoading: _isLoading,
                onPressed: _signInWithOtp,
                icon: Icons.check_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'New to NagarSathi?',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            TextButton(
              onPressed: _openSignUp,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Sign up',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDeep,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Are you municipality staff? ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            TextButton(
              onPressed: _openStaffSignIn,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Staff portal',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDeep,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool isDark;
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
          color: selected
              ? (isDark ? const Color(0xFF243B30) : AppColors.mint)
              : tokens.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : tokens.border,
            width: selected ? 2 : 1.5,
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
