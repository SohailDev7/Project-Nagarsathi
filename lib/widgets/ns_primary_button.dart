import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Modern gradient-accented primary CTA with subtle soft shadow and crisp tap scale.
class NsPrimaryButton extends StatefulWidget {
  const NsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 52,
    this.color = AppColors.primary,
    this.shadowColor = AppColors.primaryDark,
    this.borderColor = AppColors.primaryDark,
    this.gradientColors,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final Color color;
  final Color shadowColor;
  final Color borderColor;
  final List<Color>? gradientColors;
  final Color? foregroundColor;

  @override
  State<NsPrimaryButton> createState() => _NsPrimaryButtonState();
}

class _NsPrimaryButtonState extends State<NsPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canTap = !widget.isLoading && widget.onPressed != null;
    final onPrimary =
        widget.foregroundColor ?? Theme.of(context).colorScheme.onPrimary;
    final colors = widget.gradientColors ??
        [
          Color.lerp(widget.color, Colors.white, 0.08)!,
          widget.color,
        ];

    return Semantics(
      button: true,
      enabled: canTap,
      label: widget.label,
      child: MouseRegion(
        cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: canTap
              ? (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: (_) {
            if (_pressed) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (_pressed) setState(() => _pressed = false);
          },
          onTap: canTap ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed && canTap ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: Container(
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: canTap
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      )
                    : null,
                color: canTap ? null : tokens.surfaceSoft,
                borderRadius: BorderRadius.circular(15),
                border: canTap
                    ? null
                    : Border.all(color: tokens.border, width: 1.2),
                boxShadow: canTap
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(
                            alpha: isDark ? 0.25 : 0.28,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: widget.isLoading
                      ? SizedBox(
                          key: const ValueKey('loader'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              onPrimary,
                            ),
                          ),
                        )
                      : FittedBox(
                          key: const ValueKey('label'),
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: canTap ? onPrimary : tokens.muted,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              if (widget.icon != null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  widget.icon,
                                  size: 19,
                                  color: canTap ? onPrimary : tokens.muted,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
