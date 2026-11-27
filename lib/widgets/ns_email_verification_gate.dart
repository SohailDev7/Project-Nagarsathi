import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'ns_background.dart';
import 'ns_mascot.dart';
import 'ns_otp_input.dart';
import 'ns_outline_button.dart';
import 'ns_primary_button.dart';

/// Holds a signed-in citizen at email verification until their address is
/// confirmed with a 6-digit code.
///
/// Google and Facebook sign-ins already carry a proven email, and accounts
/// without an email (phone-only) are not gated. The verification itself runs
/// through the same OTP worker as sign-up, then asks the worker to stamp
/// `emailVerified` on the Firebase account.
class NsEmailVerificationGate extends StatefulWidget {
  const NsEmailVerificationGate({
    super.key,
    required this.child,
    required this.onSignOut,
    this.authService = const AuthService(),
  });

  final Widget child;

  /// Sends the citizen back to the sign-in screen after signing out.
  final VoidCallback onSignOut;

  final AuthService authService;

  @override
  State<NsEmailVerificationGate> createState() =>
      _NsEmailVerificationGateState();
}

class _NsEmailVerificationGateState extends State<NsEmailVerificationGate> {
  final _codeController = TextEditingController();

  bool _verified = true;
  String? _email;
  bool _codeSent = false;
  bool _sending = false;
  bool _verifying = false;
  int _seconds = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _evaluate() {
    User? user;
    try {
      user = AuthService.isConfigured ? FirebaseAuth.instance.currentUser : null;
    } catch (_) {
      user = null;
    }
    _email = user?.email;
    _verified = user == null || !_needsVerification(user);
  }

  static bool _needsVerification(User user) {
    final email = user.email;
    if (email == null || email.isEmpty) return false;
    final providers = user.providerData.map((item) => item.providerId).toSet();
    if (providers.contains('google.com') || providers.contains('facebook.com')) {
      return false;
    }
    return !user.emailVerified;
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _email;
    if (email == null || _sending || _seconds > 0) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.authService.requestEmailOtp(email);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _codeSent = true;
      });
      _startCountdown();
      _showMessage(context.l10n.verificationCodeSent(email));
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = context.l10n.sendCodeFailure;
      });
    }
  }

  Future<void> _verify() async {
    final email = _email;
    final code = _codeController.text.trim();
    if (email == null || _verifying) return;

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = context.l10n.enterCode);
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.authService.verifyEmailOtp(email: email, otp: code);
      final verified = await widget.authService.markEmailVerified();
      if (!mounted) return;
      if (!verified) {
        setState(() {
          _verifying = false;
          _error = 'We could not verify this email. Try again.';
        });
        return;
      }
      setState(() {
        _verifying = false;
        _verified = true;
      });
      HapticFeedback.mediumImpact();
      _showMessage(context.l10n.verifyEmailDone);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'We could not verify this email. Try again.';
      });
    }
  }

  Future<void> _signOut() async {
    HapticFeedback.selectionClick();
    await widget.authService.signOut();
    if (!mounted) return;
    widget.onSignOut();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) return widget.child;

    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Scaffold(
      key: const Key('verify-email-gate'),
      body: NsBackground(
        ambientGlow: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: NsMascot(
                        size: 116,
                        mood: NsMascotMood.curious,
                        look: Offset(0, 0.2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      strings.verifyEmailTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: tokens.heading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.verifyEmailBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.mint,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: tokens.border),
                        ),
                        child: Text(
                          _email ?? '',
                          key: const Key('verify-email-address'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: tokens.accentText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_codeSent) ...[
                      Text(
                        strings.verificationCode,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      NsOtpInput(
                        key: const Key('verify-email-code'),
                        controller: _codeController,
                        enabled: !_verifying,
                        hasError: _error != null,
                        onCompleted: (_) => _verify(),
                      ),
                      const SizedBox(height: 16),
                      NsPrimaryButton(
                        key: const Key('verify-email-submit'),
                        label: strings.verifyEmailAction,
                        icon: Icons.verified_rounded,
                        isLoading: _verifying,
                        onPressed: _verify,
                      ),
                      const SizedBox(height: 8),
                      NsOutlineButton(
                        key: const Key('verify-email-resend'),
                        label: _seconds > 0
                            ? strings.resendIn(_seconds)
                            : strings.resendCode,
                        icon: Icons.refresh_rounded,
                        onPressed: (_sending || _seconds > 0)
                            ? null
                            : _sendCode,
                      ),
                    ] else
                      NsPrimaryButton(
                        key: const Key('verify-email-send'),
                        label: strings.sendCode,
                        icon: Icons.mark_email_unread_rounded,
                        isLoading: _sending,
                        onPressed: _sendCode,
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const Key('verify-email-error'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: tokens.errorBorder,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton(
                      key: const Key('verify-email-sign-out'),
                      onPressed: _signOut,
                      child: Text(
                        strings.signOut,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: tokens.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
