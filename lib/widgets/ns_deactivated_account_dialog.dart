import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'ns_outline_button.dart';
import 'ns_primary_button.dart';

/// What the citizen picked on the deactivated-account notice.
enum DeactivatedAccountChoice { logIn, continueDeactivation }

/// Shown while a citizen whose account is inside its 30-day deletion window
/// signs in, before the app opens. The citizen either logs in (which cancels
/// the deletion and restores the account) or keeps the deactivation going.
Future<DeactivatedAccountChoice?> showDeactivatedAccountDialog({
  required BuildContext context,
  required CitizenDeletionState state,
  required AuthService authService,
}) {
  return showDialog<DeactivatedAccountChoice>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: _DeactivatedAccountDialog(state: state, authService: authService),
    ),
  );
}

/// Formats a purge date the same way the deletion screens do.
String formatDeletionDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _DeactivatedAccountDialog extends StatefulWidget {
  const _DeactivatedAccountDialog({
    required this.state,
    required this.authService,
  });

  final CitizenDeletionState state;
  final AuthService authService;

  @override
  State<_DeactivatedAccountDialog> createState() =>
      _DeactivatedAccountDialogState();
}

class _DeactivatedAccountDialogState extends State<_DeactivatedAccountDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _logIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.cancelProfileDeletion();
      if (!mounted) return;
      Navigator.of(context).pop(DeactivatedAccountChoice.logIn);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'We could not restore your account. Please try again.';
      });
    }
  }

  void _continueDeactivation() {
    if (_busy) return;
    Navigator.of(context).pop(DeactivatedAccountChoice.continueDeactivation);
  }

  String get _schedule {
    final deleteAt = widget.state.deleteAt;
    if (deleteAt == null) {
      return 'It will be permanently deleted when the 30-day window ends.';
    }
    return 'It will be permanently deleted on ${formatDeletionDate(deleteAt)}, '
        '30 days after your request.';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NsTokens.cardRadius),
        side: BorderSide(color: tokens.errorBorder, width: NsTokens.borderWidth),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              size: 44,
              color: tokens.errorBorder,
            ),
            const SizedBox(height: 12),
            Text(
              'Your account is being processed for deletion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.w900,
                color: tokens.heading,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You asked us to delete this account, so it is deactivated. '
              '$_schedule Logging in cancels the deletion and restores your '
              'account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.ink, height: 1.5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const Key('deactivated-account-error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 22),
            NsPrimaryButton(
              key: const Key('deactivated-log-in'),
              label: 'Log in',
              icon: Icons.login_rounded,
              isLoading: _busy,
              onPressed: _logIn,
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              key: const Key('deactivated-continue'),
              label: 'Continue deactivation',
              onPressed: _busy ? null : _continueDeactivation,
            ),
            const SizedBox(height: 10),
            Text(
              'Logging in stops the deletion. Continuing keeps the account '
              'deactivated and it is deleted when the 30 days end.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: tokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
