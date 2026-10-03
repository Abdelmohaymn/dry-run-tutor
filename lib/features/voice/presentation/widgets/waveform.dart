import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// The live input-level bars, drawn from `Recording.levels`.
///
/// Shared between the full-screen recorder and the in-conversation
/// recording bar so the two can never drift apart; [height] and [width]
/// are what differ between them.
class Waveform extends StatelessWidget {
  const Waveform({required this.levels, this.height = 64, this.width, super.key});

  final List<double> levels;
  final double height;

  /// Null means "take whatever the parent gives" — the in-conversation bar
  /// stretches, the full screen uses a fixed 240.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(painter: _WaveformPainter(levels)),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter(this.levels);

  final List<double> levels;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppTokens.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (levels.isEmpty) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
      return;
    }
    final double barWidth = size.width / levels.length;
    for (int i = 0; i < levels.length; i++) {
      final double level = levels[i].clamp(0.0, 1.0);
      final double barHeight = (size.height * level).clamp(4.0, size.height);
      final double x = i * barWidth + barWidth / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - barHeight / 2),
        Offset(x, size.height / 2 + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => oldDelegate.levels != levels;
}

/// `m:ss`, mono at every call site that shows it.
String formatElapsed(Duration elapsed) {
  final int minutes = elapsed.inMinutes;
  final int seconds = elapsed.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
