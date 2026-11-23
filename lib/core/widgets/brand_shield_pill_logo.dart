import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders the official MediSync brand mark:
/// The Clinical Shield of Protection enclosing the Angled Healthcare Pill with Medical Cross.
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
          shieldRimColor: shieldRimColor ?? const Color(0xFF2DD4BF),
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

    // Shield background translucent fill
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = pillTopColor.withValues(alpha: 0.38)
        ..style = PaintingStyle.fill,
    );

    // Shield outer rim glow
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = shieldRimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Shield inner hairline contour
    final innerHairline = Path();
    innerHairline.moveTo(54, 28);
    innerHairline.cubicTo(46, 28.6, 38, 30.7, 33.8, 32.5);
    innerHairline.cubicTo(32.7, 33.1, 32, 34.2, 32, 35.5);
    innerHairline.lineTo(32, 51.5);
    innerHairline.cubicTo(32, 63.5, 41.5, 72.5, 52.4, 77);
    innerHairline.cubicTo(53.5, 77.4, 54.5, 77.4, 55.6, 77);
    innerHairline.cubicTo(66.5, 72.5, 76, 63.5, 76, 51.5);
    innerHairline.lineTo(76, 35.5);
    innerHairline.cubicTo(76, 34.2, 75.3, 33.1, 74.2, 32.5);
    innerHairline.cubicTo(70, 30.7, 62, 28.6, 54, 28);
    innerHairline.close();

    canvas.drawPath(
      innerHairline,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Top Crest Glint
    final glint = Path();
    glint.moveTo(35, 31.5);
    glint.cubicTo(43, 29.2, 49, 27.8, 54, 27.5);
    glint.cubicTo(59, 27.8, 65, 29.2, 73, 31.5);
    canvas.drawPath(
      glint,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // 2. Slender Capsule Pill (-35° rotation, centered around 54, 53)
    canvas.save();
    canvas.translate(54, 53);
    canvas.rotate(-35 * math.pi / 180);
    canvas.translate(-54, -53);

    // Pill Upper Half (Teal)
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
        ..color = pillTopColor
        ..style = PaintingStyle.fill,
    );

    // Medical Cross (+) on Top Half
    // Vertical Bar
    canvas.drawRect(
      const Rect.fromLTWH(53, 39, 2, 6.5),
      Paint()..color = Colors.white,
    );
    // Horizontal Bar
    canvas.drawRect(
      const Rect.fromLTWH(50.5, 41.2, 7, 2.1),
      Paint()..color = Colors.white,
    );

    // Center Cyan Divider Band
    canvas.drawRect(
      const Rect.fromLTWH(47.7, 52, 12.6, 1.8),
      Paint()..color = const Color(0xFF38BDF8),
    );

    // Lower Half (Pure Medical White)
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
        ..color = Colors.white
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
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.restore(); // Restore pill rotation

    // 3. Sparkling Sapphire Gem on Shield Crest (Top Right)
    canvas.drawCircle(
      const Offset(72, 31.5),
      1.8,
      Paint()..color = const Color(0xFF38BDF8),
    );

    canvas.restore(); // Restore canvas scale
  }

  @override
  bool shouldRepaint(covariant _BrandShieldPillPainter oldDelegate) {
    return oldDelegate.shieldRimColor != shieldRimColor ||
        oldDelegate.pillTopColor != pillTopColor ||
        oldDelegate.showShadow != showShadow;
  }
}
