import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'ns_pressable.dart';

/// Interactive notification popup that prompts the user to activate "Remember me"
/// right after signing in.
///
/// Designed to follow NagarSathi's playful civic palette in both light and
/// dark modes.
class NsRememberMeNotification extends StatelessWidget {
  const NsRememberMeNotification({
    super.key,
    required this.onRemember,
    required this.onDismiss,
    this.isStaff = false,
  });

  final VoidCallback onRemember;
  final VoidCallback onDismiss;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Dismissible(
      key: const ValueKey('ns_remember_me_notification_dismissible'),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: tokens.border,
            width: NsTokens.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.shadow,
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Row ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tokens.mint,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: tokens.border,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isStaff
                          ? Icons.admin_panel_settings_rounded
                          : Icons.lock_person_rounded,
                      size: 20,
                      color: tokens.primaryStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Heading & category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isStaff
                            ? 'STAFF & ADMIN • SECURITY'
                            : 'NAGARSATHI • SECURITY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: tokens.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Remember me on this device?',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.heading,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                Semantics(
                  button: true,
                  label: 'Dismiss remember me notification',
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDismiss();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: tokens.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Explanation Body ─────────────────────────────────────────
            Text(
              isStaff
                  ? 'Stay signed in on this device so you can quickly manage municipality duties, respond to reports, and access admin tools without signing in each time.'
                  : 'Stay signed in on this device so you can report civic issues, track community updates, and view your profile without typing your password each time.',
              style: TextStyle(
                fontSize: 13,
                height: 1.38,
                fontWeight: FontWeight.w500,
                color: tokens.ink.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 14),
            // ── Action Buttons ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: NsPressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDismiss();
                    },
                    color: tokens.surfaceSoft,
                    borderColor: tokens.controlBorder,
                    shadowColor: tokens.controlBorder,
                    radius: 12,
                    depth: 3,
                    semanticLabel: 'Do not remember me on this device',
                    child: SizedBox(
                      height: 42,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Not now',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NsPressable(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onRemember();
                    },
                    color: AppColors.primary,
                    borderColor: tokens.primaryStrong,
                    shadowColor: tokens.primaryStrong,
                    radius: 12,
                    depth: 3,
                    semanticLabel: 'Remember me on this device',
                    child: SizedBox(
                      height: 42,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Remember me',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the top floating "Remember me" notification right after sign-in.
///
/// Returns `true` if the user enabled remember me, `false` if dismissed, or
/// `null` if dismissed via barrier tap.
Future<bool?> showRememberMeNotification({
  required BuildContext context,
  bool isStaff = false,
  String? staffIdentifier,
  bool isPhone = false,
  SessionService sessionService = const SessionService(),
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Remember me notification',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: NsRememberMeNotification(
                  isStaff: isStaff,
                  onDismiss: () async {
                    await sessionService.saveRememberMe(false);
                    if (isStaff) {
                      await sessionService.clearStaffSession();
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop(false);
                    }
                  },
                  onRemember: () async {
                    await sessionService.saveRememberMe(true);
                    if (isStaff && staffIdentifier != null) {
                      await sessionService.saveStaffSession(
                        identifier: staffIdentifier,
                        isPhone: isPhone,
                      );
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop(true);
                    }
                    if (context.mounted) {
                      _showRememberConfirmation(context);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.65),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        ),
      );
    },
  );

  if (result != true) {
    // If the notification was dismissed by tapping outside or swiping up,
    // do not keep the session remembered.
    await sessionService.saveRememberMe(false);
    if (isStaff) {
      await sessionService.clearStaffSession();
    }
  }

  return result;
}

void _showRememberConfirmation(BuildContext context) {
  try {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final tokens = NsColors.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.border,
              width: NsTokens.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Remember me enabled for this device.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.heading,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (_) {
    // If no Scaffold is available in context, ignore gracefully.
  }
}
