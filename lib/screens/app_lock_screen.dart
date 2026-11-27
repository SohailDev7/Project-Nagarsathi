import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/session_service.dart';
import '../services/staff_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_route.dart';
import 'login_screen.dart';
import 'staff_login_screen.dart';

/// Security checkpoint shown before a remembered session is opened.
///
/// The session itself already lives on the device through Firebase Auth. This
/// screen makes sure the person holding the phone is the person who owns that
/// session by asking for a fingerprint, face scan, or the phone's screen lock
/// PIN. It is only used when Remember me and App Lock are both on.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.target,
    this.isStaff = false,
    this.resumeMode = false,
    this.autoPrompt = true,
    this.biometricService,
    this.sessionService = const SessionService(),
  });

  /// The screen to open after a successful unlock.
  final WidgetBuilder target;

  /// Staff and admin sessions return to the staff sign-in flow when signed out.
  final bool isStaff;

  /// When true the lock was pushed over a running session and simply pops on
  /// success instead of replacing itself with [target].
  final bool resumeMode;

  /// Starts the system prompt automatically once the screen is visible.
  final bool autoPrompt;

  final BiometricService? biometricService;
  final SessionService sessionService;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with WidgetsBindingObserver {
  late final BiometricService _biometrics =
      widget.biometricService ?? BiometricService();

  BiometricAvailability? _availability;
  bool _checking = true;
  bool _authenticating = false;
  bool _signingOut = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check device lock status if the user went to phone Settings to add a
    // fingerprint, face scan, or PIN and came back.
    if (state == AppLifecycleState.resumed &&
        !_checking &&
        !_authenticating &&
        !_signingOut &&
        !(_availability?.isSupported ?? false)) {
      _refreshAvailability();
    }
  }

  Future<void> _refreshAvailability() async {
    final availability = await _biometrics.availability();
    if (!mounted) return;
    setState(() {
      _availability = availability;
      if (availability.isSupported) _message = null;
    });
  }

  Future<void> _prepare() async {
    final availability = await _biometrics.availability();
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _checking = false;
    });

    if (widget.autoPrompt && availability.isSupported) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (mounted) await _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || _signingOut) return;
    final availability = _availability;
    if (availability == null || !availability.isSupported) return;

    HapticFeedback.selectionClick();
    setState(() {
      _authenticating = true;
      _message = null;
    });

    final outcome = await _biometrics.authenticate(
      reason: widget.isStaff
          ? 'Unlock the NagarSathi staff workspace'
          : 'Unlock NagarSathi',
    );
    if (!mounted) return;

    if (outcome.success) {
      HapticFeedback.mediumImpact();
      if (widget.resumeMode && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          NsPageRoute<void>(
            style: NsTransitionStyle.fade,
            builder: widget.target,
          ),
        );
      }
      return;
    }

    setState(() {
      _authenticating = false;
      _message = outcome.message;
    });
  }

  Future<void> _confirmSignOut() async {
    if (_signingOut) return;
    final tokens = NsColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: tokens.border, width: 1.5),
        ),
        title: Text(
          'Sign out instead?',
          style: TextStyle(fontWeight: FontWeight.w900, color: tokens.heading),
        ),
        content: Text(
          widget.isStaff
              ? 'The saved staff session will be removed from this phone. You '
                    'can sign in again with your staff credentials.'
              : 'The saved session will be removed from this phone. You can '
                    'sign in again with your password, Google, or Facebook.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: tokens.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Stay locked',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: tokens.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sign out',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: tokens.errorBorder,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _signOut();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    final navigator = Navigator.of(context);

    await widget.sessionService.saveRememberMe(false);
    await widget.sessionService.saveAppLock(false);

    if (widget.isStaff) {
      await StaffAuthService.signOut();
      await widget.sessionService.clearStaffSession();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        NsPageRoute<void>(
          style: NsTransitionStyle.fade,
          builder: (_) => const StaffLoginScreen(),
        ),
        (route) => false,
      );
    } else {
      await const AuthService().signOut();
      await widget.sessionService.clearStaffSession();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        NsPageRoute<void>(
          style: NsTransitionStyle.fade,
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final availability = _availability;
    final supported = availability?.isSupported ?? false;
    final methodSummary = supported
        ? availability!.methodSummary.toLowerCase()
        : null;

    return PopScope(
      // Never allow hardware/gesture back to dismiss the lock over an active
      // session; the user must either unlock or explicitly sign out.
      canPop: false,
      child: Scaffold(
        body: NsBackground(
        staff: widget.isStaff,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: NsBrand(compact: true)),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: tokens.border,
                          width: NsTokens.borderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.shadow,
                            offset: const Offset(0, 6),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: _LockGlyph(
                              icon: supported
                                  ? _iconFor(availability!)
                                  : Icons.lock_rounded,
                              busy: _authenticating,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.resumeMode
                                ? 'Welcome back'
                                : widget.isStaff
                                ? 'Staff workspace locked'
                                : 'NagarSathi is locked',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                              color: tokens.heading,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _description(methodSummary),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              color: tokens.muted,
                            ),
                          ),
                          if (supported && availability != null) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: _methodChips(availability),
                            ),
                          ],
                          if (_message != null) ...[
                            const SizedBox(height: 14),
                            _MessageBanner(message: _message!),
                          ],
                          const SizedBox(height: 20),
                          if (_checking)
                            const NsPrimaryButton(
                              label: 'Checking this device…',
                              onPressed: null,
                              isLoading: true,
                            )
                          else if (supported)
                            NsPrimaryButton(
                              label: _authenticating
                                  ? 'Waiting for your device…'
                                  : availability!.actionLabel,
                              icon: _authenticating
                                  ? null
                                  : Icons.lock_open_rounded,
                              isLoading: _authenticating,
                              onPressed: _unlock,
                            )
                          else
                            NsPrimaryButton(
                              label: 'Sign in with password',
                              icon: Icons.password_rounded,
                              onPressed: _signingOut ? null : _confirmSignOut,
                            ),
                          if (supported) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: _signingOut ? null : _confirmSignOut,
                                style: TextButton.styleFrom(
                                  foregroundColor: tokens.muted,
                                  minimumSize: const Size(0, 34),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Not you? Sign out',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 15,
                          color: tokens.accentText,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Your face, fingerprint, and PIN stay on your phone.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: tokens.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  String _description(String? methods) {
    final intro = widget.resumeMode
        ? 'You were away for a moment, so the app locked itself.'
        : 'Remember me is on for this device.';
    if (methods == null) {
      return '$intro Set up a fingerprint, face scan, or screen lock PIN in '
          'your phone settings, then try again.';
    }
    return '$intro Confirm it is you with $methods to open your saved '
        'session.';
  }

  List<Widget> _methodChips(BiometricAvailability availability) {
    return <Widget>[
      if (availability.hasFace)
        const NsChip(
          label: 'FACE UNLOCK',
          icon: Icons.face_rounded,
          tone: NsChipTone.green,
          compact: true,
        ),
      if (availability.hasFingerprint)
        const NsChip(
          label: 'FINGERPRINT',
          icon: Icons.fingerprint_rounded,
          tone: NsChipTone.sky,
          compact: true,
        ),
      if (availability.hasIris)
        const NsChip(
          label: 'IRIS UNLOCK',
          icon: Icons.remove_red_eye_rounded,
          tone: NsChipTone.green,
          compact: true,
        ),
      if (availability.hasGenericBiometric)
        const NsChip(
          label: 'BIOMETRIC',
          icon: Icons.security_rounded,
          tone: NsChipTone.green,
          compact: true,
        ),
      if (availability.deviceSupported)
        const NsChip(
          label: 'SCREEN LOCK PIN',
          icon: Icons.pin_rounded,
          tone: NsChipTone.sun,
          compact: true,
        ),
    ];
  }

  static IconData _iconFor(BiometricAvailability availability) {
    if (availability.hasFace) return Icons.face_rounded;
    if (availability.hasFingerprint) return Icons.fingerprint_rounded;
    if (availability.hasIris) return Icons.remove_red_eye_rounded;
    if (availability.hasGenericBiometric) return Icons.security_rounded;
    return Icons.pin_rounded;
  }
}

class _LockGlyph extends StatelessWidget {
  const _LockGlyph({required this.icon, required this.busy});

  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return SizedBox(
      width: 118,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.mint,
              border: Border.all(color: tokens.border, width: 1.5),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: busy ? 84 : 78,
            height: busy ? 84 : 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.surface,
              border: Border.all(
                color: tokens.primaryStrong.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.primaryStrong.withValues(alpha: 0.16),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, size: 38, color: tokens.accentText),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.errorBorder.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.errorBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: tokens.errorBorder),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
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
}
