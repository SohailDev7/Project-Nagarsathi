import 'package:material_ui/material_ui.dart';

import '../screens/app_lock_screen.dart';
import '../services/biometric_service.dart';
import '../services/session_service.dart';

/// Re-locks an already-open NagarSathi session after the app spends a while in
/// the background.
///
/// The gate is intentionally thin: it only overlays [AppLockScreen] when the
/// user has enabled App Lock, so signing out or disabling the feature restores
/// the normal home screen with no extra route in the stack.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    this.isStaff = false,
    this.sessionService = const SessionService(),
    this.biometricService,
    this.relockAfter = const Duration(seconds: 30),
  });

  final Widget child;
  final bool isStaff;
  final SessionService sessionService;
  final BiometricService? biometricService;

  /// How long the app may stay in the background before the next resume asks
  /// for the device lock again.
  final Duration relockAfter;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  DateTime? _leftAt;
  bool _showingLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        if (leftAt != null &&
            DateTime.now().difference(leftAt) >= widget.relockAfter) {
          _lockIfEnabled();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _lockIfEnabled() async {
    if (_showingLock || !mounted) return;
    final rememberMe = await widget.sessionService.loadRememberMe();
    final enabled = await widget.sessionService.loadAppLock();
    if (!mounted || !rememberMe || !enabled || _showingLock) return;

    _showingLock = true;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return AppLockScreen(
            isStaff: widget.isStaff,
            resumeMode: true,
            target: (targetContext) => const SizedBox.shrink(),
            biometricService: widget.biometricService,
            sessionService: widget.sessionService,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    _showingLock = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
