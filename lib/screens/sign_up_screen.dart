import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/ns_auth_controls.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_google_button.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_otp_input.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_route.dart';
import '../widgets/ns_shake.dart';
import '../widgets/ns_speech_bubble.dart';
import '../widgets/ns_split_hero_scaffold.dart';
import '../widgets/ns_step_progress.dart';
import '../widgets/ns_text_field.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Three streamlined steps: details, password + checklist, and 6-digit email OTP.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const _totalSteps = 3;
  static const _passwordStep = 1;
  static const _lastStep = 2;
  static const _resendCooldownSeconds = 45;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  final _shakeController = NsShakeController();

  final _formKeys = List<GlobalKey<FormState>>.generate(
    _totalSteps,
    (_) => GlobalKey<FormState>(),
  );

  int _step = 0;
  int _direction = 1;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  bool _googleLoading = false;
  bool _celebrating = false;
  bool _showError = false;
  bool _fieldFocused = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendRemaining = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendRemaining = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendRemaining <= 1) {
        timer.cancel();
        setState(() => _resendRemaining = 0);
      } else {
        setState(() => _resendRemaining -= 1);
      }
    });
  }

  NsMascotMood get _mood {
    if (_celebrating) return NsMascotMood.celebrate;
    if (_showError) return NsMascotMood.sad;
    if (_fieldFocused) return NsMascotMood.curious;
    return NsMascotMood.happy;
  }

  (String, String) _copy(AppStrings s) => switch (_step) {
    0 => (s.createAccount, s.mascotStepYourDetails),
    1 => (s.password, s.mascotPasswordPrompt),
    _ => (s.verificationCode, s.mascotStepVerify),
  };

  String _stepMessage(AppStrings s) {
    if (_celebrating) return s.mascotAllSet;
    if (_showError) return _errorMessage ?? s.mascotTryAgain;
    if (_googleLoading) return s.mascotGoogleLoading;
    if (_isLoading) return s.mascotCreatingAccount;
    return _copy(s).$2;
  }

  void _triggerError([String? message]) {
    HapticFeedback.mediumImpact();
    _shakeController.shake();
    setState(() {
      _isLoading = false;
      _showError = true;
      if (message != null) _errorMessage = message;
    });
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step != _lastStep &&
        !(_formKeys[_step].currentState?.validate() ?? false)) {
      _triggerError();
      return;
    }

    if (_step == _lastStep) {
      _createAccount();
      return;
    }
    if (_step == _passwordStep) {
      _requestOtp();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _direction = 1;
      _step += 1;
      _showError = false;
      _errorMessage = null;
      _fieldFocused = false;
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      _returnToSignIn();
      return;
    }
    setState(() {
      _direction = -1;
      _step -= 1;
      _showError = false;
      _errorMessage = null;
      _fieldFocused = false;
    });
  }

  void _returnToSignIn() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      NsPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _requestOtp() async {
    final strings = context.l10n;
    if (_step == _passwordStep) {
      if (!(_formKeys[_passwordStep].currentState?.validate() ?? false)) {
        _triggerError();
        return;
      }
      if (!_acceptedTerms) {
        _triggerError(strings.acceptTermsNotice);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });
    try {
      await const AuthService().requestEmailOtp(_emailController.text);
      if (!mounted) return;
      _startResendCooldown();
      setState(() {
        _isLoading = false;
        _direction = 1;
        _step = _lastStep;
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _triggerError(error.message);
    }
  }

  Future<void> _createAccount() async {
    final strings = context.l10n;
    FocusScope.of(context).unfocus();
    final otpErr = Validators.otp(_otpController.text, strings: strings);
    if (otpErr != null) {
      _triggerError(otpErr);
      return;
    }

    if (!_acceptedTerms) {
      _triggerError(strings.acceptTermsNotice);
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      await const AuthService().verifyEmailOtp(
        email: _emailController.text,
        otp: _otpController.text,
      );
      await const AuthService().createCitizenAccount(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _triggerError(error.message);
      return;
    }

    if (!mounted) return;
    _finishSignUp();
  }

  Future<void> _signUpWithGoogle() async {
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
      _triggerError(error.message);
      setState(() => _googleLoading = false);
      return;
    }

    if (!mounted) return;
    if (!signedIn) {
      setState(() => _googleLoading = false);
      return;
    }

    setState(() => _googleLoading = false);
    _finishSignUp();
  }

  Future<void> _finishSignUp() async {
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
        builder: (_) => const AppLockGate(
          child: HomeScreen(showRememberMePrompt: true),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Stack(
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
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        NsBackButton(onPressed: _back, onDarkHeader: true),
        const SizedBox(width: 10),
        const NsLogo(size: 30, depth: 0),
        const SizedBox(width: 8),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'NagarSathi',
              style: TextStyle(
                fontSize: 16,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const NsAuthPreferencePills(onDarkHeader: true),
      ],
    );
  }

  Widget _buildHero() {
    final strings = context.l10n;
    final msg = _stepMessage(strings);
    final tone = switch (_mood) {
      NsMascotMood.sad => NsSpeechTone.error,
      NsMascotMood.celebrate => NsSpeechTone.success,
      NsMascotMood.curious => NsSpeechTone.info,
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
            size: 80,
            mood: _mood,
            look: const Offset(0, 0.5),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _copy(strings).$1,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: tokens.heading,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.mint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                strings.stepOfTotal(_step + 1, _totalSteps),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: tokens.accentText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        NsStepProgress(
          step: _step,
          total: _totalSteps,
          height: 10,
        ),
        const SizedBox(height: 16),
        NsShake(
          controller: _shakeController,
          child: AutofillGroup(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: Offset(0.05 * _direction, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('signup-step-$_step'),
                  child: _buildStepCardContent(),
                ),
              ),
            ),
          ),
        ),
        if (_step == 0) ...[
          const SizedBox(height: 16),
          NsAuthDivider(label: strings.orContinueWith),
          const SizedBox(height: 10),
          NsSocialAuthRow(
            onGooglePressed: _signUpWithGoogle,
            googleLoading: _googleLoading,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                strings.alreadyHaveAccount,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.muted,
                ),
              ),
              TextButton(
                onPressed: _returnToSignIn,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  strings.signIn,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: tokens.accentText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStepCardContent() {
    final strings = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showError && _errorMessage != null) ...[
          _buildErrorBanner(),
          const SizedBox(height: 12),
        ],
        _buildStep(),
        const SizedBox(height: 16),
        NsPrimaryButton(
          label: _step == _lastStep ? strings.createAccount : strings.continueText,
          isLoading: _isLoading,
          onPressed: _next,
          icon: _step == _lastStep
              ? Icons.check_rounded
              : Icons.arrow_forward_rounded,
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
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

  Widget _buildStep() {
    final strings = context.l10n;
    final tokens = NsColors.of(context);

    if (_step == 0) {
      return Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NsTextField(
              controller: _nameController,
              label: strings.fullName,
              hint: 'Sita Sharma',
              icon: Icons.person_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.name(v, strings: strings),
              autofillHints: const [AutofillHints.name],
              autofocus: true,
              onChanged: (_) => _clearError(),
              onFocusChange: _setFieldFocus,
            ),
            const SizedBox(height: 13),
            NsTextField(
              controller: _emailController,
              label: strings.email,
              hint: 'you@example.com',
              icon: Icons.mail_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.email(v, strings: strings),
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              onChanged: (_) => _clearError(),
              onFocusChange: _setFieldFocus,
            ),
            const SizedBox(height: 13),
            NsTextField(
              controller: _phoneController,
              label: '${strings.phone} (${strings.optional})',
              hint: '+977 98XXXXXXXX',
              icon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: (v) => Validators.optionalPhone(v, strings: strings),
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
              ],
              helper: strings.signUpPhoneHelper,
              onChanged: (_) => _clearError(),
              onFocusChange: _setFieldFocus,
              onFieldSubmitted: (_) => _next(),
            ),
          ],
        ),
      );
    }

    if (_step == _lastStep) {
      return Form(
        key: _formKeys[_lastStep],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _emailController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _direction = -1;
                              _step = 0;
                              _showError = false;
                              _errorMessage = null;
                            });
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      strings.editEmail,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: tokens.accentText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            NsOtpInput(
              controller: _otpController,
              enabled: !_isLoading,
              hasError: _showError,
              onChanged: (_) => _clearError(),
              onCompleted: (_) {
                if (!_isLoading) _createAccount();
              },
            ),
            const SizedBox(height: 12),
            Text(
              strings.otpSentNotice(_emailController.text.trim()),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: _resendRemaining > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tokens.border),
                      ),
                      child: Text(
                        strings.resendIn(_resendRemaining),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: tokens.muted,
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _isLoading ? null : _requestOtp,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(strings.resendCode),
                    ),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKeys[_passwordStep],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NsTextField(
            controller: _passwordController,
            label: strings.password,
            hint: strings.passwordHint,
            icon: Icons.lock_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.password(v, strings: strings),
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _onPasswordChanged(),
            onFocusChange: _setFieldFocus,
          ),
          _PasswordStrengthPanel(password: _passwordController.text),
          const SizedBox(height: 14),
          NsTextField(
            controller: _confirmController,
            label: strings.confirmPassword,
            hint: strings.confirmPassword,
            icon: Icons.lock_reset_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: Validators.confirmPassword(
              _passwordController,
              strings: strings,
            ),
            onChanged: (_) => _clearError(),
            onFocusChange: _setFieldFocus,
            onFieldSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 16),
          _TermsRow(
            accepted: _acceptedTerms,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() {
                _acceptedTerms = value;
                if (_showError &&
                    _errorMessage == strings.acceptTermsNotice &&
                    value) {
                  _showError = false;
                  _errorMessage = null;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  void _onPasswordChanged() {
    setState(() {
      _showError = false;
      _errorMessage = null;
    });
  }

  void _clearError() {
    if (_showError) {
      setState(() {
        _showError = false;
        _errorMessage = null;
      });
    }
  }

  void _setFieldFocus(bool focused) {
    if (_fieldFocused != focused) {
      setState(() => _fieldFocused = focused);
    }
  }
}

class _PasswordStrengthPanel extends StatelessWidget {
  const _PasswordStrengthPanel({required this.password});

  final String password;

  bool get _hasMinLength => password.length >= 8;
  bool get _hasNumber => RegExp(r'\d').hasMatch(password);
  bool get _hasUpperOrSymbol =>
      RegExp(r'[A-Z]').hasMatch(password) ||
      RegExp(r'[^A-Za-z0-9]').hasMatch(password);

  int get _score {
    if (password.isEmpty) return 0;
    var score = 0;
    if (_hasMinLength) score += 1;
    if (password.length >= 12) score += 1;
    if (_hasNumber) score += 1;
    if (_hasUpperOrSymbol) score += 1;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    final score = _score;
    final label = switch (score) {
      0 => '',
      1 => strings.pwdStrengthWeak,
      2 => strings.pwdStrengthFair,
      3 => strings.pwdStrengthGood,
      _ => strings.pwdStrengthStrong,
    };
    final barColor = switch (score) {
      0 => tokens.hairline,
      1 => tokens.errorBorder,
      2 => AppColors.sun,
      3 => tokens.accentBright,
      _ => AppColors.primary,
    };
    final labelColor = switch (score) {
      1 => tokens.errorBorder,
      2 => tokens.muted,
      3 => tokens.accentText,
      _ => AppColors.primary,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(4, (index) {
                    final active = password.isNotEmpty && index < score;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 5,
                        margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: active ? barColor : tokens.hairline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: labelColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _RuleChip(label: strings.pwdRuleLength, met: _hasMinLength),
              _RuleChip(label: strings.pwdRuleNumber, met: _hasNumber),
              _RuleChip(
                label: strings.pwdRuleSymbolOrUpper,
                met: _hasUpperOrSymbol,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final fg = met ? tokens.accentText : tokens.muted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met ? tokens.mint : tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: met ? AppColors.primary.withValues(alpha: 0.6) : tokens.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!accepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Checkbox(
              value: accepted,
              onChanged: (value) => onChanged(value ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: strings.agreeToTermsPrefix),
                    TextSpan(
                      text: strings.termsOfServiceLabel,
                      style: TextStyle(
                        color: tokens.accentText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(text: strings.andLabel),
                    TextSpan(
                      text: strings.privacyPolicyLabel,
                      style: TextStyle(
                        color: tokens.accentText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
