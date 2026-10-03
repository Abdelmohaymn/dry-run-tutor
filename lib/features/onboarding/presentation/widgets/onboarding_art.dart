import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// One illustration per welcome slide, drawn rather than shipped.
///
/// The carousel was seven screens of prose with a small icon on each, and
/// read as a wall of text. It wants pictures — but a bitmap per slide is
/// megabytes of assets to license, localise and keep in step with the
/// palette, for art that is a handful of shapes. These are those shapes,
/// painted from the same `AppTokens` as the rest of the app, so they scale
/// to any screen, weigh nothing, and cannot drift from the theme.
enum OnboardingArt { mind, speak, daily, asks, finish, remind, key, share }

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({required this.art, this.height = 180, super.key});

  final OnboardingArt art;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _ArtPainter(art)),
    );
  }
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter(this.art);

  final OnboardingArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double unit = math.min(size.width, size.height) / 2;

    // A soft accent disc behind every piece, so the seven read as one set.
    canvas.drawCircle(
      centre,
      unit * 0.92,
      Paint()..color = AppTokens.accent.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      centre,
      unit * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppTokens.accent.withValues(alpha: 0.18),
    );

    switch (art) {
      case OnboardingArt.mind:
        _mind(canvas, centre, unit);
      case OnboardingArt.speak:
        _speak(canvas, centre, unit);
      case OnboardingArt.daily:
        _daily(canvas, centre, unit);
      case OnboardingArt.asks:
        _asks(canvas, centre, unit);
      case OnboardingArt.finish:
        _finish(canvas, centre, unit);
      case OnboardingArt.remind:
        _remind(canvas, centre, unit);
      case OnboardingArt.key:
        _key(canvas, centre, unit);
      case OnboardingArt.share:
        _share(canvas, centre, unit);
    }
  }

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = AppTokens.accent;

  Paint get _faintStroke => _stroke
    ..color = AppTokens.muted
    ..strokeWidth = 2;

  Paint get _fill => Paint()..color = AppTokens.accent;

  /// A head in profile with a spark inside it: the mind, still yours.
  void _mind(Canvas canvas, Offset c, double u) {
    final Path head = Path()
      ..moveTo(c.dx - u * 0.42, c.dy + u * 0.5)
      ..lineTo(c.dx - u * 0.42, c.dy - u * 0.06)
      ..arcToPoint(
        Offset(c.dx + u * 0.34, c.dy - u * 0.28),
        radius: Radius.circular(u * 0.42),
      )
      ..lineTo(c.dx + u * 0.5, c.dy + u * 0.06)
      ..lineTo(c.dx + u * 0.3, c.dy + u * 0.12)
      ..lineTo(c.dx + u * 0.3, c.dy + u * 0.5);
    canvas.drawPath(head, _stroke);

    // The spark: four rays and a core.
    final Offset spark = Offset(c.dx - u * 0.02, c.dy - u * 0.04);
    canvas.drawCircle(spark, u * 0.1, _fill);
    for (int i = 0; i < 4; i++) {
      final double angle = math.pi / 4 + i * math.pi / 2;
      canvas.drawLine(
        spark + Offset(math.cos(angle), math.sin(angle)) * u * 0.2,
        spark + Offset(math.cos(angle), math.sin(angle)) * u * 0.33,
        _stroke..strokeWidth = 2.5,
      );
    }
  }

  /// A waveform: talking is the whole interface.
  void _speak(Canvas canvas, Offset c, double u) {
    const List<double> bars = <double>[0.22, 0.45, 0.72, 1.0, 0.62, 0.86, 0.4, 0.24];
    final double gap = u * 0.17;
    final double left = c.dx - gap * (bars.length - 1) / 2;
    for (int i = 0; i < bars.length; i++) {
      final double h = u * 0.62 * bars[i];
      final double x = left + i * gap;
      canvas.drawLine(
        Offset(x, c.dy - h),
        Offset(x, c.dy + h),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = i.isEven ? AppTokens.accent : AppTokens.accent.withValues(alpha: 0.45),
      );
    }
  }

  /// A single filled day among empty ones.
  void _daily(Canvas canvas, Offset c, double u) {
    const int columns = 4;
    const int rows = 3;
    final double step = u * 0.34;
    final double left = c.dx - step * (columns - 1) / 2;
    final double top = c.dy - step * (rows - 1) / 2;
    for (int r = 0; r < rows; r++) {
      for (int col = 0; col < columns; col++) {
        final bool today = r == 1 && col == 2;
        final Rect box = Rect.fromCenter(
          center: Offset(left + col * step, top + r * step),
          width: step * 0.66,
          height: step * 0.66,
        );
        final RRect rounded = RRect.fromRectAndRadius(box, Radius.circular(step * 0.18));
        canvas.drawRRect(
          rounded,
          today
              ? _fill
              : (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = AppTokens.border2),
        );
      }
    }
  }

  /// Two bubbles, the tutor's carrying a question mark.
  void _asks(Canvas canvas, Offset c, double u) {
    final RRect theirs = RRect.fromRectAndRadius(
      Rect.fromLTWH(c.dx - u * 0.72, c.dy - u * 0.6, u * 0.95, u * 0.5),
      Radius.circular(u * 0.16),
    );
    canvas.drawRRect(theirs, _faintStroke);

    final RRect mine = RRect.fromRectAndRadius(
      Rect.fromLTWH(c.dx - u * 0.1, c.dy + u * 0.08, u * 0.85, u * 0.45),
      Radius.circular(u * 0.16),
    );
    canvas.drawRRect(mine, Paint()..color = AppTokens.surface3);

    // The question mark, in the tutor's bubble.
    final Offset q = Offset(c.dx - u * 0.24, c.dy - u * 0.35);
    final Path hook = Path()
      ..moveTo(q.dx - u * 0.09, q.dy - u * 0.06)
      ..arcToPoint(Offset(q.dx + u * 0.06, q.dy - u * 0.02), radius: Radius.circular(u * 0.1))
      ..lineTo(q.dx, q.dy + u * 0.06);
    canvas.drawPath(hook, _stroke..strokeWidth = 2.5);
    canvas.drawCircle(Offset(q.dx, q.dy + u * 0.14), 2.2, _fill);
  }

  /// A tick inside a ring: the thing you tap when you are done.
  void _finish(Canvas canvas, Offset c, double u) {
    canvas.drawCircle(
      c,
      u * 0.46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppTokens.accent,
    );
    final Path tick = Path()
      ..moveTo(c.dx - u * 0.2, c.dy)
      ..lineTo(c.dx - u * 0.04, c.dy + u * 0.17)
      ..lineTo(c.dx + u * 0.23, c.dy - u * 0.18);
    canvas.drawPath(tick, _stroke..strokeWidth = 4);
  }

  /// A bell with a sunrise behind it.
  void _remind(Canvas canvas, Offset c, double u) {
    // Horizon and sun.
    canvas.drawLine(
      Offset(c.dx - u * 0.6, c.dy + u * 0.42),
      Offset(c.dx + u * 0.6, c.dy + u * 0.42),
      _faintStroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(c.dx, c.dy + u * 0.42), radius: u * 0.26),
      math.pi,
      math.pi,
      false,
      Paint()..color = AppTokens.amber.withValues(alpha: 0.5),
    );

    final Path bell = Path()
      ..moveTo(c.dx - u * 0.3, c.dy + u * 0.14)
      ..lineTo(c.dx + u * 0.3, c.dy + u * 0.14)
      ..lineTo(c.dx + u * 0.2, c.dy - u * 0.02)
      ..lineTo(c.dx + u * 0.2, c.dy - u * 0.2)
      ..arcToPoint(Offset(c.dx - u * 0.2, c.dy - u * 0.2), radius: Radius.circular(u * 0.24))
      ..lineTo(c.dx - u * 0.2, c.dy - u * 0.02)
      ..close();
    canvas.drawPath(bell, _stroke);
    canvas.drawCircle(Offset(c.dx, c.dy + u * 0.26), u * 0.07, _fill);
  }

  /// A key, drawn as a ring and a shaft.
  void _key(Canvas canvas, Offset c, double u) {
    canvas.drawCircle(
      Offset(c.dx - u * 0.3, c.dy),
      u * 0.22,
      _stroke..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(c.dx - u * 0.08, c.dy),
      Offset(c.dx + u * 0.48, c.dy),
      _stroke..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(c.dx + u * 0.26, c.dy),
      Offset(c.dx + u * 0.26, c.dy + u * 0.16),
      _stroke..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(c.dx + u * 0.44, c.dy),
      Offset(c.dx + u * 0.44, c.dy + u * 0.22),
      _stroke..strokeWidth = 3,
    );
  }

  /// A card with a spark leaving it.
  void _share(Canvas canvas, Offset c, double u) {
    final RRect card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c.dx - u * 0.06, c.dy + u * 0.04), width: u * 0.9, height: u * 0.7),
      Radius.circular(u * 0.14),
    );
    canvas.drawRRect(card, Paint()..color = AppTokens.surface3);
    canvas.drawRRect(card, _faintStroke);
    for (int i = 0; i < 3; i++) {
      final double y = c.dy - u * 0.12 + i * u * 0.16;
      canvas.drawLine(
        Offset(c.dx - u * 0.4, y),
        Offset(c.dx + u * (i == 2 ? 0.02 : 0.2), y),
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = i == 0 ? AppTokens.accent : AppTokens.muted.withValues(alpha: 0.6),
      );
    }
    // The arrow away.
    final Offset tail = Offset(c.dx + u * 0.3, c.dy - u * 0.3);
    canvas.drawLine(tail, Offset(c.dx + u * 0.6, c.dy - u * 0.56), _stroke..strokeWidth = 3);
    final Path head = Path()
      ..moveTo(c.dx + u * 0.36, c.dy - u * 0.56)
      ..lineTo(c.dx + u * 0.6, c.dy - u * 0.56)
      ..lineTo(c.dx + u * 0.6, c.dy - u * 0.32);
    canvas.drawPath(head, _stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _ArtPainter oldDelegate) => oldDelegate.art != art;
}
