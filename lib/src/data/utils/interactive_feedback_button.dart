import 'dart:async';

import 'package:setgo/src/data/services/haptic_helper.dart';
import 'package:flutter/material.dart';

class InteractiveFeedbackButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Function(LongPressEndDetails)? onLongPressEnd;

  final double scaleFactor;
  final Duration duration;

  final HapticImpact tapImpact;
  final HapticImpact longPressImpact;

  const InteractiveFeedbackButton({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.onLongPressEnd,
    this.scaleFactor = 1.1,
    this.duration = const Duration(milliseconds: 150),
    this.tapImpact = HapticImpact.light,
    this.longPressImpact = HapticImpact.heavy,
  });

  @override
  State<InteractiveFeedbackButton> createState() =>
      _InteractiveFeedbackButtonState();
}

class _InteractiveFeedbackButtonState extends State<InteractiveFeedbackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Invoke [onPressed] immediately so navigation is not lost if a parent
  /// ListView rebuild cancels the gesture mid-animation (common "first tap
  /// ignored" symptom). Haptic + scale run afterward without blocking.
  void _handleTap() {
    if (widget.onPressed == null) return;
    widget.onPressed!();
    unawaited(_playTapFeedback(widget.tapImpact));
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    widget.onLongPress!();
    unawaited(_playTapFeedback(widget.longPressImpact, reverse: false));
  }

  Future<void> _handleLongPressEnd(LongPressEndDetails details) async {
    if (_controller.value > 0) {
      await _controller.reverse();
    }
    widget.onLongPressEnd?.call(details);
  }

  Future<void> _playTapFeedback(
    HapticImpact impact, {
    bool reverse = true,
  }) async {
    if (!mounted) return;
    await HapticHelper.impact(impact);
    if (!mounted) return;
    await _controller.forward();
    if (!mounted) return;
    if (reverse) {
      await _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed == null ? null : _handleTap,
      onLongPress: widget.onLongPress == null ? null : _handleLongPress,
      onLongPressEnd:
          widget.onLongPressEnd == null ? null : _handleLongPressEnd,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
