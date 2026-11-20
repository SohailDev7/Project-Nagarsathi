import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_auth_heading.dart';
import '../widgets/ns_auth_scaffold.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_google_button.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_step_progress.dart';
import '../widgets/ns_text_field.dart';
import 'home_screen.dart';

/// Two short steps: your details, then how you keep the account secure.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const _totalSteps = 3;
  static const _passwordStep = 1;
  static const _lastStep = 2;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  NsMascotMood get _mood {
    if (_celebrating) return NsMascotMood.celebrate;
    if (_showError) return NsMascotMood.sad;
    if (_fieldFocused) return NsMascotMood.curious;
    return NsMascotMood.happy;
  }

  (String, String) get _copy => switch (_step) {
    0 => ('Create your account', 'Tell me who you are and where to reach you.'),
    1 => (
    'Secure your account',
    'At least 8 characters. I promise not to peek!',
    ),
    _ => ('Verify your email', 'Enter the 6-digit code sent to your email.'),
  };

  String get _stepMessage {
    if (_celebrating) return 'You are all set! Welcome to NagarSathi.';
    if (_showError) {
      return _errorMessage ?? 'Almost — check that answer and try once more.';
    }
    if (_googleLoading) {
      return 'Opening Google… pick your account.';
    }
    if (_isLoading) {
      return _step == _lastStep
          ? 'Verifying your email…'
          : 'Creating your citizen account…';
    }
    return _copy.$2;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!(_formKeys[_step].currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }

    if (_step == _passwordStep) {
      _requestOtp();
      return;
    }
    if (_step == _lastStep) {
      _createAccount();
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
      Navigator.of(context).pop();
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

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    if (!(_formKeys[_passwordStep].currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }

    if (!_acceptedTerms) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accept the terms to continue.')),
      );
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
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
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    _finishSignUp();
  }

  Future<void> _requestOtp() async {
    if (!(_formKeys[_passwordStep].currentState?.validate() ?? false)) {
      setState(() => _showError = true);
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accept the terms to continue.')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });
    try {
      await const AuthService().requestEmailOtp(_emailController.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = _lastStep;
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
    }
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

    setState(() => _googleLoading = false);
    _finishSignUp();
  }

  Future<void> _finishSignUp() async {
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
          NsAuthScaffold(
            topBar: _buildTopBar(),
            bottom: _buildActions(),
            child: AutofillGroup(
              child: NsEntrance(
                duration: const Duration(milliseconds: 420),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NsAuthHeading(
                        title: _copy.$1,
                        message: _stepMessage,
                        mood: _mood,
                        look: const Offset(0, 0.6),
                        wave: _celebrating,
                        mascotSize: 58,
                      ),
                      const SizedBox(height: 20),
                      _buildStep(),
                    ],
                  ),
                ),
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
    final tokens = NsColors.of(context);

    return Row(
      children: [
        NsBackButton(onPressed: _back),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_step + 1} of $_totalSteps',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: tokens.accentText,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 5),
              NsStepProgress(step: _step, total: _totalSteps, height: 14),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CloseButton(onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _buildStep() {
    final tokens = NsColors.of(context);

    if (_step == 0) {
      if (_step == _lastStep) {
        return Form(
          key: _formKeys[_lastStep],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NsTextField(
                controller: _otpController,
                label: 'Email verification code',
                hint: '6-digit code',
                icon: Icons.pin_rounded,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (value) => RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter the 6-digit code',
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _createAccount(),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a code to ${_emailController.text}. It expires in 5 minutes.',
                style: TextStyle(fontSize: 12.5, color: tokens.muted),
              ),
            ],
          ),
        );
      }

      return Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NsTextField(
              controller: _nameController,
              label: 'Full name',
              hint: 'Sita Sharma',
              icon: Icons.person_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.name,
              autofillHints: const [AutofillHints.name],
              autofocus: true,
              onChanged: (_) => _clearError(),
              onFocusChange: _setFieldFocus,
            ),
            const SizedBox(height: 14),
            NsTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.mail_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              onChanged: (_) => _clearError(),
              onFocusChange: _setFieldFocus,
            ),
            const SizedBox(height: 14),
            NsTextField(
              controller: _phoneController,
              label: 'Phone (optional)',
              hint: '+977 98XXXXXXXX',
              icon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: Validators.optionalPhone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
              ],
              helper: 'Only used for urgent ward notices.',
              onChanged: (_) => _clearError(),
              onFocusChange: _setFieldFocus,
              onFieldSubmitted: (_) => _next(),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKeys[_lastStep],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NsTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create a password',
            icon: Icons.lock_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: Validators.password,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _onPasswordChanged(),
            onFocusChange: _setFieldFocus,
          ),
          _PasswordStrength(password: _passwordController.text),
          const SizedBox(height: 14),
          NsTextField(
            controller: _confirmController,
            label: 'Confirm password',
            hint: 'Repeat your password',
            icon: Icons.lock_reset_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: Validators.confirmPassword(_passwordController),
            onChanged: (_) => _clearError(),
            onFocusChange: _setFieldFocus,
            onFieldSubmitted: (_) => _createAccount(),
          ),
          const SizedBox(height: 18),
          _TermsRow(
            accepted: _acceptedTerms,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _acceptedTerms = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final tokens = NsColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NsPrimaryButton(
          label: _step == _lastStep ? 'Create account' : 'Continue',
          isLoading: _isLoading,
          onPressed: _next,
          icon: _step == _lastStep
              ? Icons.check_rounded
              : Icons.arrow_forward_rounded,
        ),
        if (_step == 0) ...[
          const SizedBox(height: 6),
          const NsAuthDivider(label: 'or sign up with'),
          const SizedBox(height: 8),
          NsGoogleButton(
            label: 'Sign up with Google',
            isLoading: _googleLoading,
            onPressed: _signUpWithGoogle,
          ),
          const SizedBox(height: 2),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.muted,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Sign in',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ],
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

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  int get _score {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (RegExp(r'\d').hasMatch(password)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score += 1;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final tokens = NsColors.of(context);

    const labels = ['Too short', 'Fair', 'Good', 'Strong'];
    final score = _score;
    final label = score == 0 ? labels[0] : labels[(score - 1).clamp(0, 3)];
    final barColor = switch (score) {
      0 => tokens.errorBorder,
      1 => AppColors.sun,
      2 => tokens.accentBright,
      _ => AppColors.primary,
    };
    final labelColor = switch (score) {
      0 => tokens.errorBorder,
      1 => tokens.muted,
      2 => tokens.accentText,
      _ => AppColors.primary,
    };
    final filled = score == 0 ? 1 : score;

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 3, right: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index < filled ? barColor : tokens.hairline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: labelColor,
              letterSpacing: 0.1,
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
              padding: EdgeInsets.only(top: 7),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: tokens.accentText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: tokens.accentText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(text: '.'),
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return NsPressable(
      onTap: onPressed,
      color: tokens.surface,
      borderColor: tokens.controlBorder,
      shadowColor: tokens.shadow,
      depth: 3,
      radius: 14,
      expand: false,
      semanticLabel: 'Close',
      child: SizedBox(
        width: 42,
        height: 42,
        child: Tooltip(
          message: 'Close',
          child: Center(
            child: Icon(Icons.close_rounded, size: 22, color: tokens.heading),
          ),
        ),
      ),
    );
  }
}
