import 'package:flutter/material.dart';

class AnimatedIn extends StatelessWidget {
  const AnimatedIn({
    super.key,
    required this.child,
    this.delay = 0,
  });

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        final delayed = delay == 0 ? value : (value * 1.18 - 0.18).clamp(0, 1);
        return Opacity(
          opacity: delayed.toDouble(),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - delayed.toDouble())),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}