import 'package:flutter/material.dart';

/// Fades the top edge of a scrolling conversation, so a bubble scrolled up
/// under the problem card reads as "more above" rather than as a bubble cut
/// off by a rendering bug (found on device).
class TopFade extends StatelessWidget {
  const TopFade({required this.child, super.key});

  final Widget child;

  static const double _height = 20;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final double stop = bounds.height <= 0 ? 0 : (_height / bounds.height).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[Colors.transparent, Colors.black, Colors.black],
          stops: <double>[0, stop, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
