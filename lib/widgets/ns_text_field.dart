import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Sleek soft-filled rounded-14 input with glowing focus halo and status chip.
class NsTextField extends StatefulWidget {
  const NsTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.autocorrect = true,
    this.autofocus = false,
    this.onChanged,
    this.onFocusChange,
    this.suffix,
    this.labelTrailing,
    this.helper,
    this.enabled = true,
    this.focusNode,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onFocusChange;
  final Widget? suffix;
  final Widget? labelTrailing;
  final String? helper;
  final bool enabled;
  final FocusNode? focusNode;
  final int? maxLength;

  @override
  State<NsTextField> createState() => _NsTextFieldState();
}

class _NsTextFieldState extends State<NsTextField> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  late bool _obscured = widget.obscureText;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant NsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocus);
      if (_ownsFocusNode) _focusNode.dispose();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocus);
      _focused = _focusNode.hasFocus;
    }
  }

  void _handleFocus() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
    widget.onFocusChange?.call(_focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = _focused
        ? (isDark ? const Color(0xFF1F332A) : const Color(0xFFB5DCAA))
        : (isDark ? const Color(0xFF1B2B24) : const Color(0xFFA3D194));

    const radius = BorderRadius.all(Radius.circular(14));
    final idleBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: isDark
            ? tokens.border.withValues(alpha: 0.75)
            : const Color(0xFF6B9F60),
        width: 1.2,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 1.8),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: tokens.errorBorder, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _focused ? tokens.accentText : tokens.heading,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              if (widget.labelTrailing != null) ...[
                const SizedBox(width: 8),
                widget.labelTrailing!,
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.15),
                      spreadRadius: 3.5,
                      blurRadius: 0,
                    ),
                  ]
                : const [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            autocorrect: widget.obscureText ? false : widget.autocorrect,
            enableSuggestions: !widget.obscureText,
            validator: widget.validator,
            onFieldSubmitted: widget.onFieldSubmitted,
            onChanged: widget.onChanged,
            autofocus: widget.autofocus,
            maxLength: widget.maxLength,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tokens.ink,
              letterSpacing: -0.1,
            ),
            cursorColor: tokens.accentText,
            cursorWidth: 2.2,
            cursorRadius: const Radius.circular(2),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: fillColor,
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: tokens.muted.withValues(alpha: 0.78),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: idleBorder,
              enabledBorder: idleBorder,
              disabledBorder: idleBorder,
              focusedBorder: focusedBorder,
              errorBorder: errorBorder,
              focusedErrorBorder: errorBorder,
              prefixIcon: widget.icon == null
                  ? null
                  : Icon(
                      widget.icon,
                      size: 19,
                      color: _focused ? tokens.accentText : tokens.muted,
                    ),
              suffixIcon:
                  widget.suffix ??
                  (widget.obscureText
                      ? IconButton(
                          onPressed: () =>
                              setState(() => _obscured = !_obscured),
                          icon: Icon(
                            _obscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 19,
                            color: tokens.muted,
                          ),
                          tooltip: _obscured
                              ? 'Show password'
                              : 'Hide password',
                          splashRadius: 18,
                        )
                      : null),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 24,
              ),
            ),
          ),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 6),
            child: Text(
              widget.helper!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: tokens.muted,
              ),
            ),
          ),
      ],
    );
  }
}
