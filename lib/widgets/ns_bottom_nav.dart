import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// The floating bottom navigation shared by the citizen home and profile
/// screens, so the bar stays put as the citizen moves between them.
class NsBottomNav extends StatelessWidget {
  const NsBottomNav({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  /// 0 Home, 1 Reports, 2 Map, 3 Profile.
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <_NavItemData>[
      _NavItemData(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: strings.navHome,
      ),
      _NavItemData(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment_rounded,
        label: strings.navReports,
      ),
      _NavItemData(
        icon: Icons.map_outlined,
        activeIcon: Icons.map_rounded,
        label: strings.navMap,
      ),
      _NavItemData(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: strings.navProfile,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.08),
                offset: const Offset(0, 8),
                blurRadius: 22,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                _NavItem(
                  data: items[index],
                  active: index == activeIndex,
                  onTap: () {
                    if (index == activeIndex) return;
                    HapticFeedback.selectionClick();
                    onSelect(index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final _NavItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? tokens.accentText : tokens.muted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: data.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? tokens.mint : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active
                            ? AppColors.primary.withValues(
                                alpha: isDark ? 0.65 : 0.4,
                              )
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      active ? data.activeIcon : data.icon,
                      size: 21,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      color: color,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
