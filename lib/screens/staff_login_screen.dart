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
import '../widgets/ns_language_toggle.dart';
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

  void _clearError() {
    if (!_showError && _errorMessage == null) return;
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

    if (session.mustChangePassword) {
      final changed = await _promptPasswordChange();
      if (!changed) {
        await StaffAuthService.signOut();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _celebrating = false;
          });
        }
        return;
      }
    }

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
          showRememberMePrompt: true,
        ),
      ),
      (route) => false,
    );
  }

  Future<bool> _promptPasswordChange() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSubmitting = false;
    String? localError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final tokens = NsColors.of(context);
            final viewInsets = MediaQuery.of(context).viewInsets;

            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + viewInsets.bottom),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set Permanent Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You are signing in with a temporary password. Please set your new permanent password to continue.',
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.muted,
                        height: 1.4,
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          localError!,
                          style: const TextStyle(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    NsTextField(
                      controller: newPasswordController,
                      label: 'New Password',
                      hint: 'At least 6 characters',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    NsTextField(
                      controller: confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Re-enter your new password',
                      icon: Icons.lock_reset_rounded,
                      obscureText: true,
                      validator: (v) {
                        if (v != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    NsPrimaryButton(
                      label: 'Update & Sign In',
                      isLoading: isSubmitting,
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() {
                                isSubmitting = true;
                                localError = null;
                              });
                              try {
                                await _staffAuth.updateStaffPassword(
                                  newPasswordController.text.trim(),
                                );
                                if (bottomSheetContext.mounted) {
                                  Navigator.of(bottomSheetContext).pop(true);
                                }
                              } on AuthFailure catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  localError = e.message;
                                });
                              } catch (_) {
                                setModalState(() {
                                  isSubmitting = false;
                                  localError =
                                      'Failed to update password. Please try again.';
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(bottomSheetContext).pop(false),
                      child: Text(
                        'Cancel & Sign Out',
                        style: TextStyle(color: tokens.muted),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Wait for the modal sheet's exit animation to finish before disposing
    // controllers so the closing frame doesn't flash a disposed-controller error.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
    return result == true;
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
              const NsLanguageToggle(compact: true),
              const SizedBox(width: 8),
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

  Widget _buildBody() {
    final tokens = NsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
