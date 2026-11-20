import 'package:material_ui/material_ui.dart';

import '../services/staff_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_staff_badge.dart';
import 'admin/ward_officer_management_screen.dart';
import 'staff_login_screen.dart';

/// Landing page for the separate staff sign-in flow.
class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({
    super.key,
    required this.staffIdentifier,
    this.isPhone = false,
  });

  final String staffIdentifier;
  final bool isPhone;

  Future<void> _signOut(BuildContext context) async {
    await StaffAuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StaffLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NsBackground(
        staff: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: const [
                        NsBrand(compact: true),
                        NsStaffBadge(compact: true),
                      ],
                    ),
                    const SizedBox(height: 26),
                    NsEntrance(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Staff workspace',
                                  style: TextStyle(
                                    fontSize: 38,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.forest,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Your municipal queue at a glance.',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const NsMascot(size: 96, mood: NsMascotMood.happy),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    NsEntrance(
                      delay: const Duration(milliseconds: 80),
                      child: _StaffHeroCard(
                        staffIdentifier: staffIdentifier,
                        isPhone: isPhone,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _StatsRow(),
                    const SizedBox(height: 22),
                    const Text(
                      'App admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forest,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _AdminToolsCard(),
                    const SizedBox(height: 22),
                    const Text(
                      "Today's queue",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forest,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _QueueCard(),
                    const SizedBox(height: 24),
                    NsOutlineButton(
                      label: 'Sign out',
                      icon: Icons.logout_rounded,
                      tone: NsOutlineTone.danger,
                      onPressed: () => _signOut(context),
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

class _StaffHeroCard extends StatelessWidget {
  const _StaffHeroCard({required this.staffIdentifier, required this.isPhone});

  final String staffIdentifier;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest, AppColors.forestSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.forestSoft, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.28),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: AppColors.primaryLight,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'SIGNED IN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryLight,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.badge_rounded, size: 26, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Welcome, staff member',
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You are cleared for citizen requests and ward updates.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFFC3D4C8),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPhone
                      ? Icons.phone_android_rounded
                      : Icons.alternate_email_rounded,
                  size: 16,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    staffIdentifier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
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

class _AdminToolsCard extends StatelessWidget {
  const _AdminToolsCard();

  @override
  Widget build(BuildContext context) {
    return NsCard(
      padding: EdgeInsets.zero,
      radius: 22,
      depth: 5,
      child: NsPressable(
        onTap: () => Navigator.of(
          context,
        ).pushNamed(WardOfficerManagementScreen.routeName),
        color: Colors.transparent,
        borderColor: Colors.transparent,
        shadowColor: Colors.transparent,
        borderWidth: 0,
        depth: 0,
        radius: 20,
        padding: const EdgeInsets.all(14),
        semanticLabel: 'Open ward officer management',
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.4,
                ),
              ),
              child: const Icon(
                Icons.manage_accounts_rounded,
                size: 23,
                color: AppColors.primaryDeep,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ward officer management',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forest,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Create accounts, suspend or reactivate access, '
                    'reassign wards and review the audit trail.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.primaryDeep,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(value: '12', label: 'Open', tone: NsChipTone.sun),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '8',
            label: 'Resolved',
            tone: NsChipTone.green,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '2.4h',
            label: 'Avg time',
            tone: NsChipTone.sky,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.tone,
  });

  final String value;
  final String label;
  final NsChipTone tone;

  @override
  Widget build(BuildContext context) {
    return NsCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      radius: 20,
      depth: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
                color: AppColors.forest,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: NsChip(label: label, tone: tone, compact: true),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard();

  static const _items = <(String, String, String, NsChipTone)>[
    ('Road repair', 'Ward 4 · Lakeside Road', 'Priority', NsChipTone.sun),
    ('Streetlight', 'Ward 2 · Durbar Marg', 'New', NsChipTone.sky),
    ('Waste pickup', 'Ward 7 · Baneshwor', 'Open', NsChipTone.green),
  ];

  @override
  Widget build(BuildContext context) {
    return NsCard(
      padding: EdgeInsets.zero,
      radius: 22,
      depth: 5,
      child: Column(
        children: [
          for (var index = 0; index < _items.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1.5,
                indent: 70,
                color: AppColors.border,
              ),
            NsPressable(
              onTap: () {},
              color: Colors.transparent,
              borderColor: Colors.transparent,
              shadowColor: Colors.transparent,
              borderWidth: 0,
              depth: 0,
              radius: 20,
              haptic: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.4,
                      ),
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      size: 20,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _items[index].$1,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _items[index].$2,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  NsChip(
                    label: _items[index].$3,
                    tone: _items[index].$4,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
