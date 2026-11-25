import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../services/session_service.dart';
import '../services/staff_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_app_lock_prompt.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_remember_me_notification.dart';
import '../widgets/ns_settings_sheet.dart';
import 'admin/ward_officer_management_screen.dart';
import 'settings_screen.dart';
import 'staff_login_screen.dart';

/// Landing page for the separate staff sign-in flow.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({
    super.key,
    required this.staffIdentifier,
    this.isPhone = false,
    this.showRememberMePrompt = false,
  });

  final String staffIdentifier;
  final bool isPhone;
  final bool showRememberMePrompt;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.showRememberMePrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybePromptRememberMe();
      });
    }
  }

  Future<void> _maybePromptRememberMe() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final remembered = await showRememberMeNotification(
      context: context,
      isStaff: true,
      staffIdentifier: widget.staffIdentifier,
      isPhone: widget.isPhone,
    );
    if (!mounted || remembered != true) return;

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await showAppLockOffer(context: context, isStaff: true);
  }

  Future<void> _signOut(BuildContext context) async {
    await StaffAuthService.signOut();
    await const SessionService().clearStaffSession();
    await const SessionService().saveRememberMe(false);
    await const SessionService().saveAppLock(false);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StaffLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showAccountSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NsColors.of(context).surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final tokens = NsColors.of(sheetContext);
        final strings = sheetContext.l10n;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tokens.mint,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Icon(
                        Icons.badge_rounded,
                        size: 23,
                        color: tokens.accentText,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.staffWorkspace,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: tokens.heading,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.staffIdentifier,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    NsChip(label: strings.staffBadge, compact: true),
                  ],
                ),
                const SizedBox(height: 18),
                NsOutlineButton(
                  label: strings.wardOfficerManagement,
                  icon: Icons.manage_accounts_rounded,
                  tone: NsOutlineTone.green,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context)
                        .pushNamed(WardOfficerManagementScreen.routeName);
                  },
                ),
                const SizedBox(height: 12),
                NsOutlineButton(
                  label: strings.signOutOfStaff,
                  icon: Icons.logout_rounded,
                  tone: NsOutlineTone.danger,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _signOut(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Scaffold(
      body: NsBackground(
        staff: true,
        child: SafeArea(
          bottom: false,
          child: NsEntrance(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(context),
                      const SizedBox(height: 26),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.staffWorkspace,
                                  style: TextStyle(
                                    fontSize: 26,
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                    color: tokens.heading,
                                    letterSpacing: -0.9,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  strings.staffWorkspaceSubtitle,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const NsMascot(
                            size: 58,
                            mood: NsMascotMood.happy,
                            look: Offset(0, 0.4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _StaffHeroCard(
                        staffIdentifier: widget.staffIdentifier,
                        isPhone: widget.isPhone,
                      ),
                      const SizedBox(height: 16),
                      const _StatsRow(),
                      const SizedBox(height: 22),
                      _SectionTitle(strings.appAdmin),
                      const SizedBox(height: 10),
                      const _AdminToolsCard(),
                      const SizedBox(height: 22),
                      _SectionTitle(strings.todaysQueue),
                      const SizedBox(height: 10),
                      const _QueueCard(),
                      const SizedBox(height: 20),
                      NsOutlineButton(
                        key: const Key('staff-open-settings'),
                        label: strings.settings,
                        icon: Icons.tune_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      NsOutlineButton(
                        label: strings.signOutOfStaff,
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
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        const NsLogo(size: 32, depth: 2),
        const SizedBox(width: 9),
        Text(
          'NagarSathi',
          style: TextStyle(
            fontSize: 16,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: tokens.heading,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        const NsSettingsButton(),
        const SizedBox(width: 8),
        _StaffAvatarButton(onTap: () => _showAccountSheet(context)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: NsColors.of(context).heading,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

class _StaffAvatarButton extends StatelessWidget {
  const _StaffAvatarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? tokens.mint : AppColors.forest,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.primary : AppColors.primaryLight,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.badge_rounded,
            size: 19,
            color: isDark ? tokens.accentText : Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? tokens.surface : AppColors.forest,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.forestSoft, width: 2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : AppColors.forest.withValues(alpha: 0.28),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: isDark
                          ? tokens.accentText
                          : AppColors.primaryLight,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      strings.staffSignedInLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? tokens.accentText
                            : AppColors.primaryLight,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.badge_rounded,
                size: 26,
                color: isDark ? tokens.muted : Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            strings.staffWelcomeTitle,
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: isDark ? tokens.heading : Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.staffClearedBody,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: isDark ? tokens.muted : const Color(0xFFC3D4C8),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark
                  ? tokens.surfaceSoft
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? tokens.border
                    : Colors.white.withValues(alpha: 0.14),
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
                  color: isDark ? tokens.accentText : AppColors.primaryLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    staffIdentifier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? tokens.ink : Colors.white,
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
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return NsCard(
      padding: EdgeInsets.zero,
      radius: 22,
      depth: 5,
      child: NsPressable(
        onTap: () =>
            Navigator.of(context)
                .pushNamed(WardOfficerManagementScreen.routeName),
        color: Colors.transparent,
        borderColor: Colors.transparent,
        shadowColor: Colors.transparent,
        borderWidth: 0,
        depth: 0,
        radius: 20,
        padding: const EdgeInsets.all(14),
        semanticLabel: strings.wardOfficerManagement,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tokens.mint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.4,
                ),
              ),
              child: Icon(
                Icons.manage_accounts_rounded,
                size: 23,
                color: tokens.accentText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.wardOfficerManagement,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: tokens.heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    strings.wardOfficerManagementDesc,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: tokens.accentText,
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
    final strings = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '12',
            label: strings.statOpen,
            tone: NsChipTone.sun,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '8',
            label: strings.statResolved,
            tone: NsChipTone.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '2.4h',
            label: strings.statAvgTime,
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
    final tokens = NsColors.of(context);
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
              style: TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
                color: tokens.heading,
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

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final items = <(String, String, String, NsChipTone)>[
      (
        strings.queueRoadRepair,
        strings.queueRoadRepairMeta,
        strings.statusPriority,
        NsChipTone.sun,
      ),
      (
        strings.queueStreetlight,
        strings.queueStreetlightMeta,
        strings.statusNew,
        NsChipTone.sky,
      ),
      (
        strings.queueWaste,
        strings.queueWasteMeta,
        strings.statusOpen,
        NsChipTone.green,
      ),
    ];

    return NsCard(
      padding: EdgeInsets.zero,
      radius: 22,
      depth: 5,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1.5,
                indent: 70,
                color: tokens.hairline,
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
                      color: tokens.mint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.4,
                      ),
                    ),
                    child: Icon(
                      Icons.assignment_rounded,
                      size: 20,
                      color: tokens.accentText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index].$1,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: tokens.heading,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[index].$2,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  NsChip(
                    label: items[index].$3,
                    tone: items[index].$4,
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
