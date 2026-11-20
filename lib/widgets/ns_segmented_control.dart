import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Minimal segmented control: text tabs with a thin sliding underline.
class NsSegmentedControl extends StatelessWidget {
  const NsSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < segments.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(index),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: index == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: index == selectedIndex
                              ? tokens.ink
                              : tokens.muted,
                          letterSpacing: -0.1,
                        ),
                        child: Text(segments[index]),
                      ),
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 2,
                        color: index == selectedIndex
                            ? scheme.primary
                            : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
