import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// 6-box dedicated OTP input with auto-advance, paste support, and auto-submit.
class NsOtpInput extends StatefulWidget {
  const NsOtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.hasError = false,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool hasError;
  final bool autofocus;

  @override
  State<NsOtpInput> createState() => _NsOtpInputState();
}

class _NsOtpInputState extends State<NsOtpInput> {
  late final List<TextEditingController> _boxControllers = List.generate(
    widget.length,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(
    widget.length,
    (index) => FocusNode(
      onKeyEvent: (node, event) => _handleKeyEvent(index, event),
    ),
  );

  bool _syncing = false;
  int _focusedIndex = -1;

  @override
  void initState() {
    super.initState();
    _syncFromParent();
    widget.controller.addListener(_syncFromParent);
    for (var i = 0; i < widget.length; i++) {
      final index = i;
      _focusNodes[index].addListener(() {
        if (!mounted) return;
        setState(() {
          _focusedIndex = _focusNodes[index].hasFocus
              ? index
              : (_focusNodes.indexWhere((n) => n.hasFocus));
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant NsOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromParent);
      widget.controller.addListener(_syncFromParent);
      _syncFromParent();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    for (final c in _boxControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncFromParent() {
    if (_syncing) return;
    final digits = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < widget.length; i++) {
      final ch = i < digits.length ? digits[i] : '';
      if (_boxControllers[i].text != ch) {
        _boxControllers[i].text = ch;
      }
    }
    if (mounted) setState(() {});
  }

  void _commitToParent() {
    _syncing = true;
    final combined = _boxControllers.map((c) => c.text).join();
    widget.controller.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
    _syncing = false;
    widget.onChanged?.call(combined);
    if (combined.length == widget.length) {
      widget.onCompleted?.call(combined);
    }
  }

  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _boxControllers[index].text.isEmpty &&
        index > 0) {
      _boxControllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      _commitToParent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      // Handle pasting an entire code into any box.
      final clipped = digits.substring(
        0,
        digits.length.clamp(0, widget.length),
      );
      for (var i = 0; i < widget.length; i++) {
        _boxControllers[i].text = i < clipped.length ? clipped[i] : '';
      }
      final nextFocus = clipped.length.clamp(0, widget.length - 1);
      if (clipped.length >= widget.length) {
        _focusNodes[widget.length - 1].unfocus();
      } else {
        _focusNodes[nextFocus].requestFocus();
      }
      HapticFeedback.selectionClick();
      _commitToParent();
      setState(() {});
      return;
    }

    if (digits.isEmpty) {
      _boxControllers[index].clear();
      _commitToParent();
      setState(() {});
      return;
    }

    _boxControllers[index].value = TextEditingValue(
      text: digits,
      selection: const TextSelection.collapsed(offset: 1),
    );
    HapticFeedback.selectionClick();
    if (index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    _commitToParent();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _OtpDigitBox(
              key: Key('otp-box-$i'),
              controller: _boxControllers[i],
              focusNode: _focusNodes[i],
              enabled: widget.enabled,
              autofocus: widget.autofocus && i == 0,
              focused: _focusedIndex == i,
              filled: _boxControllers[i].text.isNotEmpty,
              hasError: widget.hasError,
              tokens: tokens,
              primary: scheme.primary,
              onChanged: (val) => _handleChanged(i, val),
            ),
          ),
        ],
      ],
    );
  }
}

class _OtpDigitBox extends StatelessWidget {
  const _OtpDigitBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.autofocus,
    required this.focused,
    required this.filled,
    required this.hasError,
    required this.tokens,
    required this.primary,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool autofocus;
  final bool focused;
  final bool filled;
  final bool hasError;
  final NsColors tokens;
  final Color primary;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? tokens.errorBorder
        : focused
        ? primary
        : filled
        ? tokens.primaryStrong.withValues(alpha: 0.7)
        : tokens.inputBorder;

    final fillColor = focused
        ? tokens.mint.withValues(alpha: 0.45)
        : filled
        ? tokens.surfaceSoft
        : tokens.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      height: 54,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: focused ? 2.4 : 1.8,
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: tokens.heading,
          ),
          cursorColor: tokens.accentText,
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            isCollapsed: true,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
