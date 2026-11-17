import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Labelled input with a focus halo, chunky border and optional status chip.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 3, right: 3, bottom: 7),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.forest,
                    letterSpacing: 0.3,
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NsTokens.radius + 2),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      spreadRadius: 4,
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
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.1,
            ),
            cursorColor: AppColors.primaryDeep,
            cursorWidth: 2.4,
            cursorRadius: const Radius.circular(2),
            decoration: InputDecoration(
              counterText: '',
              hintText: widget.hint,
              prefixIcon: widget.icon == null
                  ? null
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        widget.icon,
                        key: ValueKey(widget.icon),
                        size: 20,
                        color: _focused
                            ? AppColors.primaryDeep
                            : AppColors.muted,
                      ),
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
                            size: 20,
                            color: AppColors.muted,
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
            padding: const EdgeInsets.only(left: 4, right: 4, top: 7),
            child: Text(
              widget.helper!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
      ],
    );
  }
}
