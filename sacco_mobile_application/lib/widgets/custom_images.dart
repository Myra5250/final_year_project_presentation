import 'package:flutter/material.dart';
import 'dart:math' as math;

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Glow/Ring
    final paintRing = Paint()
      ..color = const Color(0xFFB8E6C8).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius * 0.9, paintRing);

    final paintInnerRing = Paint()
      ..color = const Color(0xFF8FD4A8).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius * 0.8, paintInnerRing);

    // Shield Background
    final pathShield = Path();
    pathShield.moveTo(center.dx, center.dy - radius * 0.7);
    pathShield.lineTo(center.dx + radius * 0.6, center.dy - radius * 0.4);
    pathShield.lineTo(center.dx + radius * 0.6, center.dy);
    pathShield.quadraticBezierTo(
        center.dx + radius * 0.6, center.dy + radius * 0.5, center.dx, center.dy + radius * 0.8);
    pathShield.quadraticBezierTo(
        center.dx - radius * 0.6, center.dy + radius * 0.5, center.dx - radius * 0.6, center.dy);
    pathShield.lineTo(
      center.dx - radius * 0.6, center.dy - radius * 0.4,
    );
    pathShield.close();

    final paintShield = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF00B84A), const Color(0xFF007A2E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
      
    // Shadow for shield
    canvas.drawShadow(pathShield, Colors.black45, 10.0, true);
    canvas.drawPath(pathShield, paintShield);

    // Plant Icon
    final plantPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final pathPlant = Path();
    // Stem
    pathPlant.moveTo(center.dx, center.dy + radius * 0.4);
    pathPlant.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius * 0.2);
    
    // Left Leave
    pathPlant.moveTo(center.dx, center.dy + radius * 0.1);
    pathPlant.quadraticBezierTo(
        center.dx - radius * 0.3, center.dy, center.dx - radius * 0.2, center.dy - radius * 0.2);
    pathPlant.quadraticBezierTo(
        center.dx - radius * 0.1, center.dy - radius * 0.1, center.dx, center.dy);
        
    // Right Leave
    pathPlant.moveTo(center.dx, center.dy - radius * 0.05);
    pathPlant.quadraticBezierTo(
        center.dx + radius * 0.3, center.dy - radius * 0.15, center.dx + radius * 0.2, center.dy - radius * 0.35);
    pathPlant.quadraticBezierTo(
        center.dx + radius * 0.1, center.dy - radius * 0.25, center.dx, center.dy - radius * 0.1);

    canvas.drawPath(pathPlant, plantPaint);
    
    // Coin/Circle at top
    canvas.drawCircle(Offset(center.dx, center.dy - radius * 0.35), 8, Paint()..color = Colors.amber.shade400);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CommunityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Abstract People
    void drawPerson(Offset position, Color color, double scale) {
      final paint = Paint()..color = color;
      // Head
      canvas.drawCircle(Offset(position.dx, position.dy - 20 * scale), 15 * scale, paint);
      // Body
      final path = Path();
      path.moveTo(position.dx - 20 * scale, position.dy);
      path.quadraticBezierTo(position.dx, position.dy - 10 * scale, position.dx + 20 * scale, position.dy);
      path.lineTo(position.dx + 20 * scale, position.dy + 30 * scale);
      path.lineTo(position.dx - 20 * scale, position.dy + 30 * scale);
      path.close();
      canvas.drawPath(path, paint);
    }
    
    // Center Person
    drawPerson(Offset(center.dx, center.dy + 20), const Color(0xFF009639), 1.2);
    // Left Person
    drawPerson(Offset(center.dx - 60, center.dy + 40), const Color(0xFF00B84A), 0.9);
    // Right Person
    drawPerson(Offset(center.dx + 60, center.dy + 40), const Color(0xFF00B84A), 0.9);
    
    // Connection arcs
    final paintLine = Paint()
      ..color = Colors.orange.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    // Simple dotted line simulation
    for (double i = 0; i < 1; i += 0.1) {
       // Left to center
       canvas.drawCircle(
         Offset.lerp(Offset(center.dx - 60, center.dy + 10), Offset(center.dx, center.dy), i)!, 
         2, 
         Paint()..color = Colors.orange.shade300
       );
       // Right to center
       canvas.drawCircle(
         Offset.lerp(Offset(center.dx + 60, center.dy + 10), Offset(center.dx, center.dy), i)!, 
         2, 
         Paint()..color = Colors.orange.shade300
       );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GrowthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Grid lines
    final paintGrid = Paint()..color = Colors.grey.shade300..strokeWidth = 1;
    canvas.drawLine(Offset(0, h * 0.8), Offset(w, h * 0.8), paintGrid);
    canvas.drawLine(Offset(0, h * 0.6), Offset(w, h * 0.6), paintGrid);
    
    // Graph Line
    final pathGraph = Path();
    pathGraph.moveTo(0, h * 0.8);
    pathGraph.cubicTo(w * 0.2, h * 0.75, w * 0.4, h * 0.85, w * 0.5, h * 0.6);
    pathGraph.cubicTo(w * 0.6, h * 0.4, w * 0.8, h * 0.5, w, h * 0.2);
    
    final paintGraph = Paint()
      ..color = const Color(0xFF009639)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
      
    canvas.drawPath(pathGraph, paintGraph);
    
    // Area under graph
    final pathArea = Path.from(pathGraph);
    pathArea.lineTo(w, h);
    pathArea.lineTo(0, h);
    pathArea.close();
    
    final paintArea = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFB8E6C8).withOpacity(0.5), const Color(0xFFE8F8EE).withOpacity(0.1)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      
    canvas.drawPath(pathArea, paintArea);
    
    // Points
    final points = [
      Offset(w * 0.5, h * 0.6),
      Offset(w, h * 0.2),
    ];
    
    for (var p in points) {
      canvas.drawCircle(p, 6, Paint()..color = Colors.orange);
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
