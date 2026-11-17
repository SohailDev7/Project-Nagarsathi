import 'package:material_ui/material_ui.dart';

import '../models/app_update.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'ns_logo.dart';
import 'ns_primary_button.dart';

/// How long the user must press and hold outside the sheet to cancel.
const _holdToCancelDuration = Duration(seconds: 3);

Future<void> showUpdateDialog({
  required BuildContext context,
  required AppUpdate update,
  required UpdateService service,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Update available',
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) =>
        UpdateDialog(update: update, service: service),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.update, required this.service});

  final AppUpdate update;
  final UpdateService service;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  /// Drives the press-and-hold timer for the tap-outside gesture.
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: _holdToCancelDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _cancelUpdate();
        });

  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _apkPath;
  bool _installerOpened = false;

  AppUpdate get _update => widget.update;

  /// Required updates cannot be dismissed, so no hold gesture is offered.
  bool get _canHoldToCancel => !_update.isPriority;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _updateNow() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
      _installerOpened = false;
    });

    try {
      final path = await widget.service.downloadApk(
        _update,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;

      _apkPath = path;
      await widget.service.installApk(path);
      if (!mounted) return;

      setState(() {
        _downloading = false;
        _installerOpened = true;
      });

      if (!_update.isPriority) Navigator.of(context).pop();
    } on UpdateCancelled {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openInstaller() async {
    final path = _apkPath;
    if (path == null) return;
    try {
      await widget.service.installApk(path);
      if (!mounted) return;
      setState(() {
        _installerOpened = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _installerOpened = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _later() async {
    await widget.service.snooze(_update);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openReleasePage() async {
    try {
      await widget.service.openReleasePage(_update);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _startHold() {
    if (!_canHoldToCancel) return;
    _hold.forward(from: _hold.value);
  }

  void _endHold() {
    if (!_canHoldToCancel) return;
    if (_hold.value > 0 && _hold.status != AnimationStatus.completed) {
      _hold.animateBack(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _cancelUpdate() {
    _hold.value = 0;
    if (_downloading) widget.service.cancelDownload();
    if (mounted) Navigator.of(context).pop();
  }

  String get _notes {
    final cleaned = _update.notes
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .trim();
    return cleaned.isEmpty
        ? 'Bug fixes and performance improvements.'
        : cleaned;
  }

  String get _sizeLabel {
    final size = _update.sizeLabel;
    return size.isEmpty ? 'the latest version' : size;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_update.isPriority,
      // The sheet is built as a full-screen route rather than a Dialog, so it
      // needs its own Material ancestor; without one Flutter falls back to the
      // yellow double-underline debug text style.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Everything outside the card: no taps dismiss it, but a deliberate
            // three-second hold does — accidental touches can't cancel anything.
            if (_canHoldToCancel)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _startHold(),
                  onPointerUp: (_) => _endHold(),
                  onPointerCancel: (_) => _endHold(),
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _card(),
                    ),
                  ),
                ),
              ),
            ),
            if (_canHoldToCancel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(child: _holdIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {},
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 20),
              Text(
                _update.isPriority ? 'Update required' : 'Update available',
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _update.isPriority
                    ? 'NagarSathi ${_update.version.display} must be installed '
                          'to keep using the app.'
                    : 'NagarSathi ${_update.version.display} is ready. Download '
                          'is $_sizeLabel.',
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              _whatsNew(),
              const SizedBox(height: 14),
              if (_downloading)
                _downloadingBlock()
              else if (_installerOpened)
                _installerBlock()
              else
                ..._idleBlock(),
              if (_canHoldToCancel) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hold outside for 3s to cancel',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const NsLogo(size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NagarSathi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Version ${_update.version.display}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        _Badge(
          label: _update.isPriority ? 'Required' : 'New',
          urgent: _update.isPriority,
        ),
      ],
    );
  }

  Widget _whatsNew() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 14,
                color: AppColors.primary,
              ),
              SizedBox(width: 7),
              Text(
                "What's new",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _notes,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w400,
              color: AppColors.ink.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _downloadingBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Downloading',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const Spacer(),
            Text(
              '${(_progress * 100).round()}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress == 0 ? null : _progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE7F0EA),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        const _NoticeRow(
          icon: Icons.phone_iphone_rounded,
          title: 'Keep NagarSathi open',
          detail: 'The download stops if you switch apps or lock the screen.',
        ),
      ],
    );
  }

  Widget _installerBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The Android installer is open. Follow the prompts to finish '
                  'updating.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        NsPrimaryButton(
          label: 'Open installer',
          onPressed: _openInstaller,
          icon: Icons.open_in_new_rounded,
        ),
        if (_update.isPriority) ...[
          const SizedBox(height: 12),
          const Text(
            'This update is required to keep using NagarSathi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _idleBlock() {
    return [
      if (_error != null) ...[
        _ErrorBox(message: _error!),
        const SizedBox(height: 14),
      ],
      const _NoticeRow(
        icon: Icons.wifi_rounded,
        title: 'Use Wi-Fi if you can',
        detail: 'A mobile-data download of this update may cost you.',
      ),
      const SizedBox(height: 8),
      const _NoticeRow(
        icon: Icons.phone_iphone_rounded,
        title: 'Keep NagarSathi open',
        detail: "Don't switch apps until the installer appears.",
      ),
      const SizedBox(height: 18),
      if (_update.isPriority) ...[
        NsPrimaryButton(
          label: _error == null ? 'Update now' : 'Try again',
          onPressed: _updateNow,
          icon: Icons.download_rounded,
        ),
        const SizedBox(height: 12),
        const Text(
          'This update is required to keep using NagarSathi.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ] else
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _later,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Later'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NsPrimaryButton(
                label: _error == null ? 'Update' : 'Retry',
                onPressed: _updateNow,
              ),
            ),
          ],
        ),
      if (_error != null) ...[
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: _openReleasePage,
            child: const Text('Download from GitHub'),
          ),
        ),
      ],
    ];
  }

  Widget _holdIndicator() {
    return AnimatedBuilder(
      animation: _hold,
      builder: (context, child) {
        final value = _hold.value;
        if (value == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2.4,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    value >= 1 ? 'Cancelling…' : 'Keep holding to cancel',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.urgent});

  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: urgent
            ? const Color(0xFFFFF1E0)
            : AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: urgent ? const Color(0xFFB4570A) : AppColors.primaryDark,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
