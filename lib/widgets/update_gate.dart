import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/app_update.dart';
import '../services/release_notification_service.dart';
import '../services/shorebird_service.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';

/// Runs Shorebird patch checks and GitHub release checks once the app is up.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  final _service = UpdateService();
  final _releaseNotifications = ReleaseNotificationService.instance;

  Timer? _startupDelay;
  bool _busy = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer update & push notification setup slightly so initial route
    // transitions never contend with network/storage startup work.
    _startupDelay = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      unawaited(_initReleaseNotifications());
      _runChecks();
    });
  }

  Future<void> _initReleaseNotifications() async {
    await _releaseNotifications.initialize(
      onUpdateNotificationTap: () {
        if (!mounted) return;
        unawaited(_runChecks(checkPatch: false, force: true, forcePrompt: true));
      },
      onForegroundReleasePush: () async {
        if (!mounted) return;
        await _runChecks(checkPatch: false, force: true);
      },
    );
  }

  @override
  void dispose() {
    _startupDelay?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_releaseNotifications.dispose());
    _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runChecks(checkPatch: false);
    }
  }

  Future<void> _runChecks({
    bool checkPatch = true,
    bool force = false,
    bool forcePrompt = false,
  }) async {
    if (_busy) return;
    _busy = true;

    try {
      if (checkPatch) {
        final patch = await ShorebirdService.syncPatch();
        if (mounted) _announcePatch(patch);
      }

      final update = await _service.checkForUpdate(force: force);
      if (!mounted || update == null) return;

      final shouldPrompt = forcePrompt || await _service.shouldPrompt(update);
      if (!shouldPrompt) {
        // If user dismissed/snoozed earlier, still send one system notification
        // for any newer release so they have an easy reminder in the tray.
        await _releaseNotifications.notifyIfNewRelease(update);
        return;
      }

      await _releaseNotifications.markVersionNotified(update.version.display);
      if (!mounted) return;
      await _present(update);
    } catch (error) {
      debugPrint('Update check failed: $error');
    } finally {
      _busy = false;
    }
  }

  Future<void> _present(AppUpdate update) async {
    final context = widget.navigatorKey.currentContext;
    if (context == null || _dialogVisible) return;

    _dialogVisible = true;
    try {
      await showUpdateDialog(
        context: context,
        update: update,
        service: _service,
      );
    } finally {
      _dialogVisible = false;
    }
  }

  void _announcePatch(PatchUpdateResult result) {
    final message = switch (result) {
      PatchUpdateResult.downloaded =>
        'A code update was downloaded. It will apply the next time '
            'NagarSathi starts.',
      PatchUpdateResult.restartRequired =>
        'A code update is ready. Restart NagarSathi to apply it.',
      _ => null,
    };
    if (message == null) return;

    final context = widget.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
