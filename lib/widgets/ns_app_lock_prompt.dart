import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/biometric_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'ns_outline_button.dart';
import 'ns_primary_button.dart';

/// Offers to protect a newly remembered session with the phone's own lock.
///
/// Called right after the citizen or staff member chooses Remember me. The
/// sheet is skipped entirely when the phone has no fingerprint, face scan, or
/// screen lock set up, because App Lock would have nothing to check against.
Future<bool> showAppLockOffer({
  required BuildContext context,
  bool isStaff = false,
  SessionService sessionService = const SessionService(),
  BiometricService? biometricService,
}) async {
  final biometrics = biometricService ?? BiometricService();
  final availability = await biometrics.availability();
  if (!context.mounted || !availability.isSupported) return false;

  final remembered = await sessionService.loadRememberMe();
  final alreadyEnabled = await sessionService.loadAppLock();
  if (!context.mounted || !remembered || alreadyEnabled) return false;

  final wantsLock = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _AppLockSheet(isStaff: isStaff, availability: availability),
  );
  if (wantsLock != true || !context.mounted) return false;

  HapticFeedback.selectionClick();
  final outcome = await biometrics.authenticate(
    reason: isStaff
        ? 'Turn on app lock for the staff workspace'
        : 'Turn on app lock for NagarSathi',
  );
  if (!outcome.success) {
    if (context.mounted) {
      _showSnack(
        context,
        outcome.message ??
            'App lock was not turned on. You can try again in Settings.',
      );
    }
    return false;
  }

  await sessionService.saveAppLock(true);
  if (context.mounted) {
    _showSnack(
      context,
      'App lock is on. NagarSathi will ask for '
      '${availability.methodSummary.toLowerCase()} next time.',
    );
  }
  return true;
}

void _showSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
}

class _AppLockSheet extends StatelessWidget {
  const _AppLockSheet({required this.isStaff, required this.availability});

  final bool isStaff;
  final BiometricAvailability availability;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tokens.border, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tokens.mint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.border, width: 1.5),
                    ),
                    child: Icon(
                      _headerIcon(availability),
                      size: 24,
                      color: tokens.accentText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isStaff ? 'ADD STAFF SECURITY' : 'ADD APP SECURITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                            color: tokens.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Lock NagarSathi with your device?',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: tokens.heading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Remember me keeps this session signed in. Add one more step '
                'so only you can open it — using the same face scan, '
                'fingerprint, or screen lock PIN you already use to unlock '
                'your phone.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'AVAILABLE ON THIS PHONE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: tokens.muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _methodChips(availability),
              ),
              const SizedBox(height: 18),
              NsPrimaryButton(
                label: 'Turn on app lock',
                icon: Icons.lock_rounded,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: 10),
              NsOutlineButton(
                label: 'Not now',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(false);
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 14,
                    color: tokens.accentText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'NagarSathi never sees or stores your face, fingerprint, '
                      'or PIN. Your phone checks them locally.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
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
    );
  }

  static IconData _headerIcon(BiometricAvailability availability) {
    if (availability.hasFace) return Icons.face_rounded;
    if (availability.hasFingerprint) return Icons.fingerprint_rounded;
    if (availability.hasIris) return Icons.remove_red_eye_rounded;
    return Icons.pin_rounded;
  }

  static List<Widget> _methodChips(BiometricAvailability availability) {
    return <Widget>[
      if (availability.hasFace)
        const _MethodPill(icon: Icons.face_rounded, label: 'Face scan'),
      if (availability.hasFingerprint)
        const _MethodPill(
          icon: Icons.fingerprint_rounded,
          label: 'Fingerprint',
        ),
      if (availability.hasIris)
        const _MethodPill(icon: Icons.remove_red_eye_rounded, label: 'Iris'),
      if (availability.hasGenericBiometric)
        const _MethodPill(icon: Icons.security_rounded, label: 'Biometric'),
      if (availability.deviceSupported)
        const _MethodPill(icon: Icons.pin_rounded, label: 'Screen lock PIN'),
    ];
  }
}

class _MethodPill extends StatelessWidget {
  const _MethodPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tokens.accentText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}
