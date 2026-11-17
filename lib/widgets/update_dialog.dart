import 'package:material_ui/material_ui.dart';

import '../models/app_update.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'ns_primary_button.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
  required AppUpdate update,
  required UpdateService service,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.isPriority,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => UpdateDialog(update: update, service: service),
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.update, required this.service});

  final AppUpdate update;
  final UpdateService service;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _apkPath;
  bool _installerOpened = false;

  String get _notes {
    final cleaned = widget.update.notes
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .trim();
    return cleaned.isEmpty
        ? 'Bug fixes and performance improvements.'
        : cleaned;
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
        widget.update,
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

      if (!widget.update.isPriority) {
        Navigator.of(context).pop();
      }
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
    await widget.service.snooze(widget.update);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openReleasePage() async {
    try {
      await widget.service.openReleasePage(widget.update);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;

    return PopScope(
      canPop: !update.isPriority,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const Spacer(),
                      _Badge(
                        label: update.isPriority
                            ? 'Required'
                            : 'v${update.version.display}',
                        urgent: update.isPriority,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    update.isPriority ? 'Important update' : 'Update available',
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    update.isPriority
                        ? 'NagarSathi ${update.version.display} includes '
                              'changes required to keep using the app.'
                        : 'NagarSathi ${update.version.display} is ready to '
                              'install. ${update.sizeLabel.isEmpty ? '' : '${update.sizeLabel} • '}APK build.',
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "What's new",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _notes,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_downloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress == 0 ? null : _progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE7F0EA),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Downloading ${(_progress * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ] else if (_installerOpened) ...[
                    const _InfoBox(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primary,
                      text:
                          'The Android installer is open. Follow the prompts '
                          'to finish updating.',
                    ),
                    const SizedBox(height: 16),
                    NsPrimaryButton(
                      label: 'Open installer',
                      onPressed: _openInstaller,
                      icon: Icons.open_in_new_rounded,
                    ),
                    if (update.isPriority) ...[
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
                  ] else ...[
                    if (_error != null) ...[
                      _InfoBox(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.error,
                        text: _error!,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (update.isPriority)
                      NsPrimaryButton(
                        label: _error == null ? 'Update now' : 'Try again',
                        onPressed: _updateNow,
                        icon: Icons.download_rounded,
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _later,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.ink,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: NsPrimaryButton(
                              label: _error == null ? 'Update' : 'Retry',
                              onPressed: _updateNow,
                            ),
                          ),
                        ],
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: _openReleasePage,
                          child: const Text('Download from GitHub'),
                        ),
                      ),
                    ],
                    if (update.isPriority) ...[
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
                ],
              ),
            ),
          ),
        ),
      ),
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

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
