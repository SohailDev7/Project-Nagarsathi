import 'package:material_ui/material_ui.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_logo.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = UpdateService();

  String? _version;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.buildNumber.isEmpty
            ? info.version
            : '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      // Version display is cosmetic; ignore failures (e.g. in tests).
    }
  }

  void _signOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _checkForUpdates() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final update = await _service.checkForUpdate(force: true);
      if (!mounted) return;

      if (update == null) {
        _showMessage('NagarSathi is up to date.');
        return;
      }

      await showUpdateDialog(
        context: context,
        update: update,
        service: _service,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Update check failed: $error');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const NsLogo(size: 30),
                        const SizedBox(width: 10),
                        const Text(
                          'NagarSathi',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 44),
                    const Text(
                      'NagarSathi Citizen',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Verified citizen account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _StatusCard(),
                    const SizedBox(height: 32),
                    const Text(
                      'Quick actions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActionList(
                      checking: _checking,
                      onCheckForUpdates: _checkForUpdates,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _signOut,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Sign out'),
                      ),
                    ),
                    if (_version != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Version $_version',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
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

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Account ready',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "You're all set",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'City services, notices and payments will appear here as they roll out.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({
    required this.checking,
    required this.onCheckForUpdates,
  });

  final bool checking;
  final VoidCallback onCheckForUpdates;

  static const _actions = [
    (Icons.campaign_outlined, 'Report an issue'),
    (Icons.receipt_long_outlined, 'Pay bills'),
    (Icons.notifications_none_rounded, 'Notices'),
    (Icons.support_agent_rounded, 'Helpline'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < _actions.length; index++) ...[
            if (index > 0) const _RowDivider(),
            _ActionRow(
              icon: _actions[index].$1,
              label: _actions[index].$2,
            ),
          ],
          const _RowDivider(),
          InkWell(
            onTap: checking ? null : onCheckForUpdates,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Check for updates',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (checking)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: AppColors.border,
    );
  }
}
