import 'package:flutter/material.dart';

/// CustomPainter rendering an authentic offline topographic reserve map.
/// Provides rich visual context when satellite data / online OSM tiles are unavailable in dense jungle.
class OfflineReserveMapPainter extends CustomPainter {
  final double? latitude;
  final double? longitude;

  OfflineReserveMapPainter({this.latitude, this.longitude});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base Terrain Canvas (Wilderness Reserve Green)
    final bgPaint = Paint()..color = const Color(0xFFEDF4EB);
    canvas.drawRect(rect, bgPaint);

    // 2. Forest Density Zones (Soft green canopy polygons)
    final canopyPaint = Paint()
      ..color = const Color(0xFFDCEAD8)
      ..style = PaintingStyle.fill;

    final forestPath1 = Path()
      ..moveTo(0, size.height * 0.2)
      ..cubicTo(size.width * 0.25, size.height * 0.1, size.width * 0.4, size.height * 0.35, size.width * 0.65, size.height * 0.25)
      ..cubicTo(size.width * 0.85, size.height * 0.15, size.width * 0.9, size.height * 0.45, size.width, size.height * 0.4)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(forestPath1, canopyPaint);

    final forestPath2 = Path()
      ..moveTo(0, size.height * 0.65)
      ..cubicTo(size.width * 0.3, size.height * 0.55, size.width * 0.5, size.height * 0.8, size.width * 0.8, size.height * 0.7)
      ..lineTo(size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(forestPath2, canopyPaint);

    // 3. Topographic Elevation Contour Lines
    final contourPaint = Paint()
      ..color = const Color(0xFFBDD4B7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 4; i++) {
      final cp = Path()
        ..moveTo(0, size.height * (0.15 * i))
        ..cubicTo(size.width * 0.3, size.height * (0.15 * i + 0.08), size.width * 0.7, size.height * (0.15 * i - 0.06), size.width, size.height * (0.15 * i + 0.04));
      canvas.drawPath(cp, contourPaint);
    }

    // 4. Coordinate Grid Lines (Tactical Map Lat/Lon Ticks)
    final gridPaint = Paint()
      ..color = const Color(0xFF88A580).withValues(alpha: 0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final double stepX = size.width / 5;
    final double stepY = size.height / 4;

    for (double x = stepX; x < size.width; x += stepX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = stepY; y < size.height; y += stepY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 5. Menik River Channel (Flowing River in Soft Blue)
    final riverPaint = Paint()
      ..color = const Color(0xFF81D4FA)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final riverPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.05)
      ..cubicTo(size.width * 0.35, size.height * 0.25, size.width * 0.3, size.height * 0.6, size.width * 0.7, size.height * 0.65)
      ..cubicTo(size.width * 0.85, size.height * 0.7, size.width * 0.9, size.height * 0.85, size.width * 0.95, size.height);
    canvas.drawPath(riverPath, riverPaint);

    final riverInner = Paint()
      ..color = const Color(0xFFB3E5FC)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(riverPath, riverInner);

    // 6. Patrol Trail Beat (Dashed Trail Line)
    final trailPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final trailPath = Path()
      ..moveTo(size.width * 0.2, size.height * 0.85)
      ..lineTo(size.width * 0.45, size.height * 0.5)
      ..lineTo(size.width * 0.75, size.height * 0.35);
    canvas.drawPath(trailPath, trailPaint);

    // 7. Tactical Landmark Labels & Icons
    _drawLandmark(canvas, Offset(size.width * 0.2, size.height * 0.85), 'Palatupana HQ', Icons.shield, const Color(0xFF2E7D32));
    _drawLandmark(canvas, Offset(size.width * 0.45, size.height * 0.5), 'Menik Crossing', Icons.water, const Color(0xFF0288D1));
    _drawLandmark(canvas, Offset(size.width * 0.75, size.height * 0.35), 'Central Waterhole', Icons.pets, const Color(0xFFE65100));

    // 8. Watermark Header ("OFFLINE TACTICAL MAP · YALA NATIONAL PARK")
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '📡 OFFLINE VECTOR GRID · YALA RESERVE',
        style: TextStyle(
          color: Color(0xFF558B2F),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 10, size.height - textPainter.height - 8));
  }

  void _drawLandmark(Canvas canvas, Offset pos, String label, IconData icon, Color color) {
    // Dot
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(pos, 4.5, dotPaint);
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, 8.0, ringPaint);

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx + 10, pos.dy - 6));
  }

  @override
  bool shouldRepaint(covariant OfflineReserveMapPainter oldDelegate) {
    return oldDelegate.latitude != latitude || oldDelegate.longitude != longitude;
  }
}
