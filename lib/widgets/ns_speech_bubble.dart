import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Mood tint for a speech bubble.
enum NsSpeechTone { neutral, success, info, error }

/// A chunky sticker-style speech bubble for Sathi.
///
/// The bubble pops in once, animates between messages and can cycle through a
/// list of friendly lines. The little speaker label keeps the mascot's voice
/// distinct from the rest of the screen copy.
class NsSpeechBubble extends StatefulWidget {
  const NsSpeechBubble({
    super.key,
    required this.messages,
    this.speaker = 'Sathi',
    this.tailOnRight = true,
    this.tone = NsSpeechTone.neutral,
    this.cycle = false,
    this.cycleInterval = const Duration(seconds: 9),
    this.animate = true,
  });

  final List<String> messages;
  final String speaker;
  final bool tailOnRight;
  final NsSpeechTone tone;

  /// When true and there is more than one message, the bubble rotates through
  /// them. Contextual messages should stay on [cycle] = false.
  final bool cycle;
  final Duration cycleInterval;
  final bool animate;

  @override
  State<NsSpeechBubble> createState() => _NsSpeechBubbleState();
}

class _NsSpeechBubbleState extends State<NsSpeechBubble> {
  Timer? _timer;
  int _index = 0;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (!_started) {
      _started = true;
      _reduceMotion = reduce;
      _restartCycle();
      return;
    }

    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    _restartCycle();
  }

  @override
  void didUpdateWidget(covariant NsSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMessages(oldWidget.messages, widget.messages)) {
      _index = 0;
      _restartCycle();
    } else if (oldWidget.cycle != widget.cycle ||
        oldWidget.cycleInterval != widget.cycleInterval) {
      _restartCycle();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _sameMessages(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _restartCycle() {
    _timer?.cancel();
    if (!mounted || _reduceMotion) return;
    if (!widget.cycle || widget.messages.length < 2) return;

    _timer = Timer.periodic(widget.cycleInterval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.messages.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final style = _BubbleTone.of(
      widget.tone,
      tokens,
      Theme.of(context).brightness,
    );
    final message = widget.messages.isEmpty
        ? ''
        : widget.messages[_index % widget.messages.length];

    final content = _buildContent(context, tokens, style, message);
    if (!widget.animate || _reduceMotion) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.9 + 0.1 * value,
            alignment: widget.tailOnRight
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  Widget _buildContent(
    BuildContext context,
    NsColors tokens,
    _BubbleTone style,
    String message,
  ) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(widget.tailOnRight ? 16 : 5),
      topRight: Radius.circular(widget.tailOnRight ? 5 : 16),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: radius,
            border: Border.all(color: style.border, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow,
                offset: const Offset(0, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.speaker.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: style.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.speaker.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: style.label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              AnimatedSwitcher(
                duration: _reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 0.18),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: AlignmentDirectional.topStart,
                  children: [...previousChildren, ?currentChild],
                ),
                child: Text(
                  message,
                  key: ValueKey(message),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                    color: tokens.heading,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: widget.tailOnRight ? -5.5 : null,
          left: widget.tailOnRight ? null : -5.5,
          top: widget.speaker.isEmpty ? 9 : 14,
          child: Transform.rotate(
            angle: 0.785,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: style.background,
                border: widget.tailOnRight
                    ? Border(
                        top: BorderSide(color: style.border, width: 1.6),
                        right: BorderSide(color: style.border, width: 1.6),
                      )
                    : Border(
                        left: BorderSide(color: style.border, width: 1.6),
                        bottom: BorderSide(color: style.border, width: 1.6),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTone {
  const _BubbleTone({
    required this.background,
    required this.border,
    required this.dot,
    required this.label,
  });

  final Color background;
  final Color border;
  final Color dot;
  final Color label;

  factory _BubbleTone.of(
    NsSpeechTone tone,
    NsColors tokens,
    Brightness brightness,
  ) {
    switch (tone) {
      case NsSpeechTone.success:
        return _BubbleTone(
          background: Color.alphaBlend(
            tokens.accentBright.withValues(alpha: 0.1),
            tokens.surface,
          ),
          border: tokens.accentBright.withValues(alpha: 0.55),
          dot: tokens.accentBright,
          label: tokens.accentText,
        );
      case NsSpeechTone.error:
        return _BubbleTone(
          background: Color.alphaBlend(
            tokens.errorBorder.withValues(alpha: 0.1),
            tokens.surface,
          ),
          border: tokens.errorBorder.withValues(alpha: 0.7),
          dot: tokens.errorBorder,
          label: brightness == Brightness.dark
              ? tokens.errorBorder
              : AppColors.errorDark,
        );
      case NsSpeechTone.info:
        return _BubbleTone(
          background: Color.alphaBlend(
            AppColors.sky.withValues(alpha: 0.08),
            tokens.surface,
          ),
          border: tokens.border,
          dot: AppColors.sky,
          label: tokens.accentText,
        );
      case NsSpeechTone.neutral:
        return _BubbleTone(
          background: tokens.surface,
          border: tokens.border,
          dot: tokens.accentBright,
          label: tokens.accentText,
        );
    }
  }
}
