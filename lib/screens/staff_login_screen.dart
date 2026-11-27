import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/staff_auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/ns_auth_controls.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_otp_input.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_route.dart';
import '../widgets/ns_shake.dart';
import '../widgets/ns_text_field.dart';
import 'login_screen.dart';
import 'staff_home_screen.dart';
import 'superadmin_home_screen.dart';

enum _PhoneStep { phone, code }

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  static const _resendCooldownSeconds = 45;

  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _otpController = TextEditingController();
  final _shakeController = NsShakeController();
  final _staffAuth = const StaffAuthService();

  _PhoneStep _phoneStep = _PhoneStep.phone;
  IdentifierKind _kind = IdentifierKind.empty;
  StaffPhoneChallenge? _challenge;

  bool _isLoading = false;
  bool _celebrating = false;
  bool _showError = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendRemaining = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
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

  bool get _isCurrentRoute => ModalRoute.of(context)?.isCurrent ?? false;

  void _clearError() {
    if (!_showError && _errorMessage == null) return;
    setState(() {
      _showError = false;
      _errorMessage = null;
      _errorMessage = null;
    });
  }

  void _failValidation() {
    HapticFeedback.mediumImpact();
    _shakeController.shake();
    setState(() {
      _isLoading = false;
      _showError = true;
      _errorMessage = null;
      _errorMessage = null;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _shakeController.shake();
    setState(() {
      _isLoading = false;
      _showError = true;
      _errorMessage = message;
      _errorMessage = message;
    });
  }

  bool get _isPhoneFlow => _kind == IdentifierKind.phone;

  /// The single identifier box detects an email (password sign-in) or a phone
  /// number (SMS code sign-in) as it is typed, so no method tab is needed.
  void _onIdentifierChanged(String value) {
    final kind = Validators.identifierKind(value);
    if (kind == _kind && !_showError) return;
    setState(() {
      _kind = kind;
      _showError = false;
      _errorMessage = null;
      if (kind != IdentifierKind.phone && _phoneStep == _PhoneStep.code) {
        _resendTimer?.cancel();
        _phoneStep = _PhoneStep.phone;
        _challenge = null;
        _otpController.clear();
        _resendRemaining = 0;
      }
    });
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _failValidation();
      return;
    }

    final staffEmail = _identifierController.text.trim();
    if (Validators.identifierKind(staffEmail) != IdentifierKind.email) {
      _failValidation();
      return;
    }
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

  /// Emails a reset link to the address typed above, so ward staff and super
  /// admins can recover a lost password without a super admin resetting it.
  Future<void> _forgotPassword() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    final strings = context.l10n;
    final email = _identifierController.text.trim();
    if (Validators.email(email, strings: strings) != null) {
      _fail(strings.staffPasswordResetNeedsEmail);
      return;
    }

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    try {
      await _staffAuth.sendPasswordReset(email);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.staffPasswordResetSent(email))),
      );
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
        _identifierController.text,
        previous: resending ? _challenge : null,
      );
      if (!mounted) return;
      if (!_isCurrentRoute) {
        setState(() => _isLoading = false);
        return;
      }

      _startResendCooldown();
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

    if (!autoVerified) {
      final otpErr = Validators.otp(_otpController.text, strings: context.l10n);
      if (otpErr != null) {
        _fail(otpErr);
        return;
      }
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

    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted || !_isCurrentRoute) {
      await StaffAuthService.signOut();
      return;
    }

    TextInput.finishAutofillContext();
    Navigator.of(context).pushAndRemoveUntil(
      NsPageRoute<void>(
        style: NsTransitionStyle.fade,
        builder: (_) => AppLockGate(
          isStaff: true,
          child: session.isSuperAdmin
              ? SuperAdminHomeScreen(
                  staffIdentifier: session.identifier,
                  showRememberMePrompt: true,
                )
              : StaffHomeScreen(
                  staffIdentifier: session.identifier,
                  isPhone: session.isPhone,
                  showRememberMePrompt: true,
                ),
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final viewInsets = MediaQuery.of(context).viewInsets;

            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + viewInsets.bottom),
              decoration: BoxDecoration(
                color: isDark ? tokens.surface : Colors.white,
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
                      context.l10n.staffSetPermanentPassword,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.staffTemporaryPasswordInstructions,
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          localError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    NsTextField(
                      controller: newPasswordController,
                      label: context.l10n.staffNewPassword,
                      hint: context.l10n.staffPasswordLengthHint,
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return context.l10n.staffPasswordLengthError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    NsTextField(
                      controller: confirmPasswordController,
                      label: context.l10n.staffConfirmNewPassword,
                      hint: context.l10n.staffReenterPassword,
                      icon: Icons.lock_reset_rounded,
                      obscureText: true,
                      validator: (v) {
                        if (v != newPasswordController.text) {
                          return context.l10n.errPasswordMatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    NsPrimaryButton(
                      label: context.l10n.staffUpdateAndSignIn,
                      isLoading: isSubmitting,
                      gradientColors: isDark
                          ? const [Color(0xFF36D395), Color(0xFF22B57A)]
                          : const [Color(0xFF0E6B47), Color(0xFF095035)],
                      foregroundColor: isDark
                          ? tokens.background
                          : Colors.white,
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
                                  localError = 'Failed to update password. Please try again.';
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
                        context.l10n.staffCancelAndSignOut,
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
    _resendTimer?.cancel();
    setState(() {
      _phoneStep = _PhoneStep.phone;
      _challenge = null;
      _otpController.clear();
      _resendRemaining = 0;
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
      NsPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _StaffPalette.of(isDark);

    return Scaffold(
      backgroundColor: palette.bgBottom,
      body: Stack(
        children: [
          // Distinct Light (Crisp Civic Slate) vs Dark (Obsidian Command) backdrop
          Positioned.fill(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [palette.bgTop, palette.bgBottom],
                  ),
                ),
                child: CustomPaint(
                  painter: _BlueprintGridPainter(color: palette.gridColor),
                ),
              ),
            ),
          ),
          // Soft ambient accent wash at top corner
          Positioned(
            top: -120,
            right: -80,
            width: 320,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [palette.ambientAccent, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth < 380 ? 16.0 : 22.0;
                final maxW = constraints.maxWidth - horizontal * 2;
                final contentWidth = maxW > 440
                    ? 440.0
                    : (maxW < 0 ? 0.0 : maxW);

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        10,
                        horizontal,
                        4,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: _buildTopBar(palette),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          12,
                          horizontal,
                          24,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: contentWidth,
                            child: NsEntrance(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildExecutiveHeader(palette),
                                  const SizedBox(height: 18),
                                  _buildCommandCard(palette),
                                  const SizedBox(height: 18),
                                  _buildFooter(palette),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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

  Widget _buildTopBar(_StaffPalette palette) {
    final strings = context.l10n;
    return Row(
      children: [
        NsBackButton(
          onPressed: _backToCitizenSignIn,
          onDarkHeader: palette.isDark,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.goldBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.goldBorder, width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 13,
                  color: palette.goldText,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    strings.staffBadgeShort.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: palette.goldText,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        NsAuthPreferencePills(onDarkHeader: palette.isDark),
      ],
    );
  }

  Widget _buildExecutiveHeader(_StaffPalette palette) {
    final strings = context.l10n;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.bannerBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.bannerShadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.crestBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.crestBorder, width: 1.4),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 27,
              color: palette.crestIcon,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.staffSignInTitle,
                  style: TextStyle(
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: palette.bannerTitle,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  strings.staffWorkspaceSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: palette.bannerSubtitle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard(_StaffPalette palette) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return NsShake(
      controller: _shakeController,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: palette.cardShadow,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AutofillGroup(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIdentifierField(),
                  if (_showError && _errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.errorBorder.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tokens.errorBorder.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: tokens.errorBorder,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _errorMessage!,
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
                  ],
                  const SizedBox(height: 16),
                  if (!_isPhoneFlow) ...[
                    NsTextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      label: strings.password,
                      hint: strings.passwordHint,
                      icon: Icons.lock_rounded,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (value) => value == null || value.isEmpty
                          ? strings.staffEnterPassword
                          : null,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _signIn(),
                      onChanged: (_) => _clearError(),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          strings.staffForgotPassword,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: palette.ctaColors.first,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    NsPrimaryButton(
                      label: strings.signIn,
                      isLoading: _isLoading,
                      onPressed: _signIn,
                      icon: Icons.arrow_forward_rounded,
                      color: palette.ctaColors.first,
                      gradientColors: palette.ctaColors,
                      foregroundColor: palette.ctaForeground,
                    ),
                  ] else ...[
                    if (_phoneStep == _PhoneStep.code) ...[
                      const SizedBox(height: 14),
                      NsOtpInput(
                        controller: _otpController,
                        enabled: !_isLoading,
                        hasError: _showError,
                        onChanged: (_) => _clearError(),
                        onCompleted: (_) => _verifyCode(),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: _resendRemaining > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
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
                                onPressed: _isLoading
                                    ? null
                                    : () => _sendCode(resending: true),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: Text(strings.resendCode),
                              ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (_phoneStep == _PhoneStep.phone)
                      NsPrimaryButton(
                        label: strings.staffSendCode,
                        isLoading: _isLoading,
                        onPressed: _sendCode,
                        icon: Icons.send_rounded,
                        color: palette.ctaColors.first,
                        gradientColors: palette.ctaColors,
                        foregroundColor: palette.ctaForeground,
                      )
                    else ...[
                      NsPrimaryButton(
                        label: strings.verifyAndSignIn,
                        isLoading: _isLoading,
                        onPressed: _verifyCode,
                        icon: Icons.verified_user_rounded,
                        color: palette.ctaColors.first,
                        gradientColors: palette.ctaColors,
                        foregroundColor: palette.ctaForeground,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _changeNumber,
                          child: Text(strings.changeIdentifier),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentifierField() {
    final strings = context.l10n;
    final isPhone = _isPhoneFlow;

    return NsTextField(
      controller: _identifierController,
      label: strings.emailOrPhone,
      hint: isPhone
          ? strings.staffMobileNumberHint
          : strings.emailOrPhoneHint,
      icon: isPhone
          ? Icons.phone_android_rounded
          : Icons.alternate_email_rounded,
      keyboardType: TextInputType.emailAddress,
      textInputAction: isPhone ? TextInputAction.done : TextInputAction.next,
      validator: (value) {
        if (Validators.identifierKind(value) == IdentifierKind.phone) {
          return Validators.nepaliPhone(value, strings: strings);
        }
        return Validators.identifier(value, strings: strings);
      },
      autocorrect: false,
      enabled: _phoneStep == _PhoneStep.phone,
      autofillHints: isPhone
          ? const [AutofillHints.telephoneNumber]
          : const [AutofillHints.username],
      helper: isPhone ? strings.staffNepaliMobileOnly : null,
      onChanged: _onIdentifierChanged,
      onFieldSubmitted: (_) {
        if (isPhone) {
          _sendCode();
        } else {
          _passwordFocusNode.requestFocus();
        }
      },
      labelTrailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: isPhone
            ? NsChip(
                key: const ValueKey('phone'),
                label: strings.phone,
                icon: Icons.smartphone_rounded,
                tone: NsChipTone.sky,
                compact: true,
              )
            : _kind == IdentifierKind.email
            ? NsChip(
                key: const ValueKey('email'),
                label: strings.email,
                icon: Icons.mail_rounded,
                compact: true,
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }

  Widget _buildFooter(_StaffPalette palette) {
    final strings = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.securityStripBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 15,
                color: palette.securityIcon,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  strings.staffAccessIssued,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: palette.securityText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _backToCitizenSignIn,
            child: Text(
              strings.citizenPortal,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: palette.portalLinkColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffPalette {
  const _StaffPalette({
    required this.isDark,
    required this.bgTop,
    required this.bgBottom,
    required this.gridColor,
    required this.ambientAccent,
    required this.goldBg,
    required this.goldBorder,
    required this.goldText,
    required this.bannerGradient,
    required this.bannerBorder,
    required this.bannerShadow,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.crestBg,
    required this.crestBorder,
    required this.crestIcon,
    required this.cardBg,
    required this.cardBorder,
    required this.cardShadow,
    required this.ctaColors,
    required this.ctaForeground,
    required this.securityStripBg,
    required this.securityIcon,
    required this.securityText,
    required this.portalLinkColor,
  });

  final bool isDark;
  final Color bgTop;
  final Color bgBottom;
  final Color gridColor;
  final Color ambientAccent;
  final Color goldBg;
  final Color goldBorder;
  final Color goldText;
  final List<Color> bannerGradient;
  final Color bannerBorder;
  final Color bannerShadow;
  final Color bannerTitle;
  final Color bannerSubtitle;
  final Color crestBg;
  final Color crestBorder;
  final Color crestIcon;
  final Color cardBg;
  final Color cardBorder;
  final Color cardShadow;
  final List<Color> ctaColors;
  final Color ctaForeground;
  final Color securityStripBg;
  final Color securityIcon;
  final Color securityText;
  final Color portalLinkColor;

  factory _StaffPalette.of(bool isDark) {
    if (isDark) {
      return _StaffPalette(
        isDark: true,
        bgTop: const Color(0xFF07110D),
        bgBottom: const Color(0xFF0C1813),
        gridColor: const Color(0xFF34D399).withValues(alpha: 0.045),
        ambientAccent: const Color(0xFF1A7F55).withValues(alpha: 0.24),
        goldBg: const Color(0xFFF5B731).withValues(alpha: 0.14),
        goldBorder: const Color(0xFFF5B731).withValues(alpha: 0.45),
        goldText: const Color(0xFFF7C95B),
        bannerGradient: const [Color(0xFF10281F), Color(0xFF173A2C)],
        bannerBorder: const Color(0xFF285542),
        bannerShadow: Colors.black.withValues(alpha: 0.35),
        bannerTitle: const Color(0xFFEFF8F3),
        bannerSubtitle: const Color(0xFFA6C7B6),
        crestBg: const Color(0xFF0A1D16),
        crestBorder: const Color(0xFFF5B731).withValues(alpha: 0.6),
        crestIcon: const Color(0xFFF7C95B),
        cardBg: const Color(0xFF12211B),
        cardBorder: const Color(0xFF233B31),
        cardShadow: Colors.black.withValues(alpha: 0.4),
        ctaColors: const [Color(0xFF36D395), Color(0xFF22B57A)],
        ctaForeground: const Color(0xFF062016),
        securityStripBg: const Color(0xFF101D18),
        securityIcon: const Color(0xFF36D395),
        securityText: const Color(0xFF9AB5A8),
        portalLinkColor: const Color(0xFF5FE3AC),
      );
    }

    return _StaffPalette(
      isDark: false,
      bgTop: const Color(0xFF96C7B7),
      bgBottom: const Color(0xFFACD6C8),
      gridColor: const Color(0xFF0E6B47).withValues(alpha: 0.08),
      ambientAccent: const Color(0xFF148558).withValues(alpha: 0.20),
      goldBg: const Color(0xFFF5D57A),
      goldBorder: const Color(0xFFB9881E),
      goldText: const Color(0xFF4A2B00),
      bannerGradient: const [Color(0xFF0E5338), Color(0xFF17704D)],
      bannerBorder: const Color(0xFF23865E),
      bannerShadow: const Color(0xFF0F3B2A).withValues(alpha: 0.18),
      bannerTitle: Colors.white,
      bannerSubtitle: const Color(0xFFD5F2E4),
      crestBg: Colors.white.withValues(alpha: 0.16),
      crestBorder: const Color(0xFFF5B731).withValues(alpha: 0.65),
      crestIcon: const Color(0xFFFFD166),
      cardBg: const Color(0xFFB9DFD2),
      cardBorder: const Color(0xFF7BB19E),
      cardShadow: const Color(0xFF0F3B2A).withValues(alpha: 0.12),
      ctaColors: const [Color(0xFF0E6B47), Color(0xFF095035)],
      ctaForeground: Colors.white,
      securityStripBg: const Color(0xFFACD5C7),
      securityIcon: const Color(0xFF0A4D33),
      securityText: const Color(0xFF133629),
      portalLinkColor: const Color(0xFF08422B),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  const _BlueprintGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
