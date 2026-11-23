import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders the official MediSync brand mark:
/// The Protective Clinical Teal Shield enclosing the Crisp White Healthcare Pill with Teal Crescent.
class BrandShieldPillLogo extends StatelessWidget {
  final double size;
  final Color? shieldRimColor;
  final Color? pillTopColor;
  final bool showShadow;

  const BrandShieldPillLogo({
    super.key,
    this.size = 64,
    this.shieldRimColor,
    this.pillTopColor,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandShieldPillPainter(
          shieldRimColor: shieldRimColor ?? const Color(0xFF5EEAD4),
          pillTopColor: pillTopColor ?? const Color(0xFF0D9488),
          showShadow: showShadow,
        ),
      ),
    );
  }
}

class _BrandShieldPillPainter extends CustomPainter {
  final Color shieldRimColor;
  final Color pillTopColor;
  final bool showShadow;

  _BrandShieldPillPainter({
    required this.shieldRimColor,
    required this.pillTopColor,
    required this.showShadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Standard reference coordinate canvas is 108 x 108
    final scale = size.width / 108.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Build Shield Path
    final shieldPath = Path();
    shieldPath.moveTo(54, 25.5);
    shieldPath.cubicTo(45, 26.2, 36, 28.5, 31.5, 30.5);
    shieldPath.cubicTo(30.2, 31.2, 29.5, 32.5, 29.5, 34);
    shieldPath.lineTo(29.5, 52);
    shieldPath.cubicTo(29.5, 65.5, 40, 75.5, 52.2, 80.5);
    shieldPath.cubicTo(53.4, 81, 54.6, 81, 55.8, 80.5);
    shieldPath.cubicTo(68, 75.5, 78.5, 65.5, 78.5, 52);
    shieldPath.lineTo(78.5, 34);
    shieldPath.cubicTo(78.5, 32.5, 77.8, 31.2, 76.5, 30.5);
    shieldPath.cubicTo(72, 28.5, 63, 26.2, 54, 25.5);
    shieldPath.close();

    // Faint ambient glow behind the shield
    final glowPaint = Paint()
      ..color = const Color(0xFF2DD4BF).withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawPath(shieldPath, glowPaint);

    // Shield shadow
    if (showShadow) {
      final shadowPath = Path();
      shadowPath.moveTo(54, 28);
      shadowPath.cubicTo(45, 28.7, 36, 31, 31.5, 33);
      shadowPath.cubicTo(30.2, 33.7, 29.5, 35, 29.5, 36.5);
      shadowPath.lineTo(29.5, 54.5);
      shadowPath.cubicTo(29.5, 68, 40, 78, 52.2, 83);
      shadowPath.cubicTo(53.4, 83.5, 54.6, 83.5, 55.8, 83);
      shadowPath.cubicTo(68, 78, 78.5, 68, 78.5, 54.5);
      shadowPath.lineTo(78.5, 36.5);
      shadowPath.cubicTo(78.5, 35, 77.8, 33.7, 76.5, 33);
      shadowPath.cubicTo(72, 31, 63, 28.7, 54, 28);
      shadowPath.close();

      canvas.drawPath(
        shadowPath,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }

    // Shield body filled with Teal-to-Sapphire Gradient
    final shieldShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF14B8A6),
        Color(0xFF0D9488),
        Color(0xFF0284C7),
      ],
      stops: [0.0, 0.45, 1.0],
    ).createShader(const Rect.fromLTWH(29.5, 25.5, 49, 55.5));

    canvas.drawPath(
      shieldPath,
      Paint()
        ..shader = shieldShader
        ..style = PaintingStyle.fill,
    );

    // Shield delicate inner highlight rim
    final innerHairline = Path();
    innerHairline.moveTo(54, 26.5);
    innerHairline.cubicTo(45.5, 27.2, 36.8, 29.4, 32.5, 31.3);
    innerHairline.cubicTo(31.4, 31.9, 30.7, 33.1, 30.7, 34.4);
    innerHairline.lineTo(30.7, 51.8);
    innerHairline.cubicTo(30.7, 64.8, 40.8, 74.5, 52.5, 79.4);
    innerHairline.cubicTo(53.5, 79.8, 54.5, 79.8, 55.5, 79.4);
    innerHairline.cubicTo(67.2, 74.5, 77.3, 64.8, 77.3, 51.8);
    innerHairline.lineTo(77.3, 34.4);
    innerHairline.cubicTo(77.3, 33.1, 76.6, 31.9, 75.5, 31.3);
    innerHairline.cubicTo(71.2, 29.4, 62.5, 27.2, 54, 26.5);
    innerHairline.close();

    canvas.drawPath(
      innerHairline,
      Paint()
        ..color = shieldRimColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Top Crest Glint
    final glint = Path();
    glint.moveTo(35, 31.5);
    glint.cubicTo(43, 29.2, 49, 27.8, 54, 27.5);
    glint.cubicTo(59, 27.8, 65, 29.2, 73, 31.5);
    canvas.drawPath(
      glint,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );

    // 2. Pure Crisp Medical White Capsule Pill (-35° rotation, centered around 54, 53)
    canvas.save();
    canvas.translate(54, 53);
    canvas.rotate(-35 * math.pi / 180);
    canvas.translate(-54, -53);

    // Pill Upper Half (Pure Crisp Medical White)
    final pillTop = Path();
    pillTop.moveTo(48, 42);
    pillTop.cubicTo(48, 38.5, 50.7, 35.5, 54, 35.5);
    pillTop.cubicTo(57.3, 35.5, 60, 38.5, 60, 42);
    pillTop.lineTo(60, 53);
    pillTop.lineTo(48, 53);
    pillTop.close();

    canvas.drawPath(
      pillTop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Center Hairline Divider Band
    canvas.drawRect(
      const Rect.fromLTWH(47.7, 52, 12.6, 1.5),
      Paint()..color = const Color(0xFFE2E8F0),
    );

    // Lower Half (Pure Medical White / Porcelain)
    final pillBottom = Path();
    pillBottom.moveTo(48, 53.5);
    pillBottom.lineTo(60, 53.5);
    pillBottom.lineTo(60, 60);
    pillBottom.cubicTo(60, 63.5, 57.3, 66.5, 54, 66.5);
    pillBottom.cubicTo(50.7, 66.5, 48, 63.5, 48, 60);
    pillBottom.close();

    canvas.drawPath(
      pillBottom,
      Paint()
        ..color = const Color(0xFFF8FAFC)
        ..style = PaintingStyle.fill,
    );

    // Crescent Symbol inside the Pill (Vibrant Clinical Teal extension from the shield)
    final crescentPath = Path();
    crescentPath.moveTo(54, 39.5);
    crescentPath.cubicTo(51.2, 40.2, 50.8, 45.8, 54, 46.5);
    crescentPath.cubicTo(52.4, 45.0, 52.4, 41.0, 54, 39.5);
    crescentPath.close();

    canvas.drawPath(
      crescentPath,
      Paint()
        ..color = pillTopColor
        ..style = PaintingStyle.fill,
    );

    // Outer Capsule Contour Stroke
    final pillOuter = Path();
    pillOuter.moveTo(48, 42);
    pillOuter.cubicTo(48, 38.5, 50.7, 35.5, 54, 35.5);
    pillOuter.cubicTo(57.3, 35.5, 60, 38.5, 60, 42);
    pillOuter.lineTo(60, 60);
    pillOuter.cubicTo(60, 63.5, 57.3, 66.5, 54, 66.5);
    pillOuter.cubicTo(50.7, 66.5, 48, 63.5, 48, 60);
    pillOuter.close();

    canvas.drawPath(
      pillOuter,
      Paint()
        ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    canvas.restore(); // Restore pill rotation
    canvas.restore(); // Restore canvas scale
  }

  @override
  bool shouldRepaint(covariant _BrandShieldPillPainter oldDelegate) {
    return oldDelegate.shieldRimColor != shieldRimColor ||
        oldDelegate.pillTopColor != pillTopColor ||
        oldDelegate.showShadow != showShadow;
  }
}
