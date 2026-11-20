import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../services/staff_auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_auth_scaffold.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_staff_badge.dart';
import '../widgets/ns_text_field.dart';
import 'login_screen.dart';
import 'staff_home_screen.dart';

enum _StaffMethod { email, phone }

enum _PhoneStep { phone, code }

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _staffAuth = const StaffAuthService();

  _StaffMethod _method = _StaffMethod.email;
  _PhoneStep _phoneStep = _PhoneStep.phone;
  StaffPhoneChallenge? _challenge;

  bool _isLoading = false;
  bool _celebrating = false;
  bool _showError = false;
  bool _focused = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool get _isCurrentRoute => ModalRoute.of(context)?.isCurrent ?? false;

  String get _message {
    if (_celebrating) return 'Badge verified. Opening your workspace…';
    if (_showError) {
      return _errorMessage ??
          (_method == _StaffMethod.phone
              ? 'Check your number and code.'
              : 'Check your work email and password.');
    }
    if (_isLoading) {
      if (_method == _StaffMethod.phone) {
        return _phoneStep == _PhoneStep.phone
            ? 'Sending your code…'
            : 'Verifying your code…';
      }
      return 'Verifying your staff access…';
    }
    if (_focused) {
      return _method == _StaffMethod.phone
          ? 'Use the number registered with your ward office.'
          : 'Use the email issued by your municipality.';
    }
    return "Staff badge ready. Let's get to work!";
  }

  void _clearError() {
    if (!_showError) return;
    setState(() {
      _showError = false;
      _errorMessage = null;
    });
  }

  void _failValidation() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = false;
      _showError = true;
      _errorMessage = null;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = false;
      _showError = true;
      _errorMessage = message;
    });
  }

  void _switchMethod(_StaffMethod method) {
    if (_isLoading || method == _method) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _method = method;
      _phoneStep = _PhoneStep.phone;
      _challenge = null;
      _otpController.clear();
      _showError = false;
      _errorMessage = null;
    });
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _failValidation();
      return;
    }

    final staffEmail = _emailController.text.trim();
    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      final session = await _staffAuth.signInWithEmail(
        email: staffEmail,
        password: _passwordController.text,
      );
      if (!mounted) {
        await StaffAuthService.signOut();
        return;
      }
      if (!_isCurrentRoute) {
        await StaffAuthService.signOut();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await _openStaffHome(session);
    } on AuthFailure catch (error) {
      _fail(error.message);
    }
  }

  Future<void> _sendCode({bool resending = false}) async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!resending && !(_formKey.currentState?.validate() ?? false)) {
      _failValidation();
      return;
    }

    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      final challenge = await _staffAuth.sendPhoneCode(
        _phoneController.text,
        previous: resending ? _challenge : null,
      );
      if (!mounted) return;
      if (!_isCurrentRoute) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _challenge = challenge;
        _phoneStep = _PhoneStep.code;
        _isLoading = false;
      });
      HapticFeedback.selectionClick();

      if (challenge.autoCredential != null) {
        await _verifyCode(autoVerified: true);
      }
    } on AuthFailure catch (error) {
      _fail(error.message);
    }
  }

  Future<void> _verifyCode({bool autoVerified = false}) async {
    if (_isLoading) return;
    final challenge = _challenge;
    if (challenge == null) return;
    FocusScope.of(context).unfocus();

    if (!autoVerified && !(_formKey.currentState?.validate() ?? false)) {
      _failValidation();
      return;
    }

    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      final session = await _staffAuth.verifyPhoneOtp(
        challenge: challenge,
        code: _otpController.text.trim(),
      );
      if (!mounted) {
        await StaffAuthService.signOut();
        return;
      }
      if (!_isCurrentRoute) {
        await StaffAuthService.signOut();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await _openStaffHome(session);
    } on AuthFailure catch (error) {
      _fail(error.message);
    }
  }

  Future<void> _openStaffHome(StaffSession session) async {
    if (!mounted || !_isCurrentRoute) return;
    setState(() {
      _isLoading = false;
      _celebrating = true;
    });
    HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || !_isCurrentRoute) {
      await StaffAuthService.signOut();
      return;
    }

    TextInput.finishAutofillContext();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => StaffHomeScreen(
          staffIdentifier: session.identifier,
          isPhone: session.isPhone,
        ),
      ),
      (route) => false,
    );
  }

  void _changeNumber() {
    setState(() {
      _phoneStep = _PhoneStep.phone;
      _challenge = null;
      _otpController.clear();
      _showError = false;
      _errorMessage = null;
    });
  }

  void _backToCitizenSignIn() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NsAuthScaffold(
          staff: true,
          topBar: Row(
            children: [
              NsBackButton(onPressed: _backToCitizenSignIn),
              const Spacer(),
              const NsStaffBadge(compact: true),
            ],
          ),
          bottom: TextButton(
            onPressed: _backToCitizenSignIn,
            child: const Text('Back to citizen sign in'),
          ),
          child: NsEntrance(child: _buildBody()),
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

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.28),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(
              Icons.badge_rounded,
              size: 24,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STAFF PORTAL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryLight,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Staff sign in',
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _message,
                    key: ValueKey(_message),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: _showError
                          ? const Color(0xFFFFC4BD)
                          : Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final tokens = NsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        NsCard(
          padding: const EdgeInsets.all(16),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMethodTabs(),
                  const SizedBox(height: 16),
                  if (_method == _StaffMethod.email) ...[
                    NsTextField(
                      controller: _emailController,
                      label: 'Work email address',
                      hint: 'you@municipality.gov.np',
                      icon: Icons.mail_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      onChanged: (_) => _clearError(),
                      onFocusChange: (focused) =>
                          setState(() => _focused = focused),
                    ),
                    const SizedBox(height: 13),
                    NsTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_rounded,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: Validators.loginPassword,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _signIn(),
                      onChanged: (_) => _clearError(),
                      onFocusChange: (focused) =>
                          setState(() => _focused = focused),
                    ),
                    const SizedBox(height: 16),
                    NsPrimaryButton(
                      label: 'Sign in',
                      isLoading: _isLoading,
                      onPressed: _signIn,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ] else ...[
                    NsTextField(
                      controller: _phoneController,
                      label: 'Mobile number',
                      hint: '98XXXXXXXX or +977 98XXXXXXXX',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      textInputAction: _phoneStep == _PhoneStep.phone
                          ? TextInputAction.done
                          : TextInputAction.next,
                      validator: Validators.nepaliPhone,
                      autocorrect: false,
                      enabled: _phoneStep == _PhoneStep.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9०-९+\s()\-]'),
                        ),
                      ],
                      helper: 'Nepali mobile numbers only (+977).',
                      onFieldSubmitted: (_) => _sendCode(),
                      onChanged: (_) => _clearError(),
                      onFocusChange: (focused) =>
                          setState(() => _focused = focused),
                    ),
                    if (_phoneStep == _PhoneStep.code) ...[
                      const SizedBox(height: 13),
                      NsTextField(
                        controller: _otpController,
                        label: '6-digit code',
                        hint: 'Enter the SMS code',
                        icon: Icons.sms_rounded,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        validator: Validators.otp,
                        autocorrect: false,
                        autofocus: true,
                        maxLength: 6,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onFieldSubmitted: (_) => _verifyCode(),
                        onChanged: (_) => _clearError(),
                        onFocusChange: (focused) =>
                            setState(() => _focused = focused),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_phoneStep == _PhoneStep.phone)
                      NsPrimaryButton(
                        label: 'Send code',
                        isLoading: _isLoading,
                        onPressed: _sendCode,
                        icon: Icons.send_rounded,
                      )
                    else ...[
                      NsPrimaryButton(
                        label: 'Verify & sign in',
                        isLoading: _isLoading,
                        onPressed: _verifyCode,
                        icon: Icons.verified_user_rounded,
                      ),
                      const SizedBox(height: 10),
                      NsOutlineButton(
                        label: 'Resend code',
                        height: 46,
                        icon: Icons.refresh_rounded,
                        onPressed: _isLoading
                            ? null
                            : () => _sendCode(resending: true),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _isLoading ? null : _changeNumber,
                          child: const Text('Change number'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1.5),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: tokens.muted,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Access is issued by your municipality.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodTabs() {
    return Row(
      children: [
        Expanded(
          child: _MethodTab(
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            selected: _method == _StaffMethod.email,
            enabled: !_isLoading,
            onTap: () => _switchMethod(_StaffMethod.email),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MethodTab(
            label: 'Phone',
            icon: Icons.phone_iphone_rounded,
            selected: _method == _StaffMethod.phone,
            enabled: !_isLoading,
            onTap: () => _switchMethod(_StaffMethod.phone),
          ),
        ),
      ],
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primaryDeep : AppColors.forest;

    return NsPressable(
      onTap: enabled ? onTap : null,
      color: selected ? AppColors.mint : AppColors.surface,
      borderColor: selected ? AppColors.primaryDeep : AppColors.borderStrong,
      shadowColor: selected ? AppColors.primaryDark : AppColors.borderStrong,
      radius: 14,
      depth: selected ? 3 : 2,
      semanticLabel: label,
      child: SizedBox(
        height: 42,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
