import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Three dots, rising in sequence, while the tutor is composing a reply.
///
/// A `CircularProgressIndicator` is the right shape for "the app is
/// loading" and the wrong one for "someone is answering you" — it reads as
/// machinery, and it sat where the reply itself was about to appear. This
/// is the convention every chat interface has settled on for the same
/// moment, and it puts the waiting where the answer will land instead of
/// in the composer.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({this.color = AppTokens.muted, this.dotSize = 7, super.key});

  final Color color;
  final double dotSize;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  static const int _dotCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < _dotCount; i++)
              Padding(
                padding: EdgeInsets.only(right: i == _dotCount - 1 ? 0 : widget.dotSize * 0.7),
                child: _dot(i),
              ),
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    // Each dot runs the same curve a third of a cycle behind the last.
    final double phase = (_controller.value + index / _dotCount) % 1.0;
    // Up over the first half of its phase, back down over the second, so
    // the row reads as a wave rather than three independent blinks.
    final double wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final double eased = Curves.easeInOut.transform(wave);
    return Transform.translate(
      offset: Offset(0, -eased * widget.dotSize * 0.55),
      child: Opacity(
        opacity: 0.35 + eased * 0.65,
        child: Container(
          width: widget.dotSize,
          height: widget.dotSize,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
