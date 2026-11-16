import 'package:material_ui/material_ui.dart';

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _WoodBackgroundPainter(), child: child),
    );
  }
}

class _WoodBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8EC), Color(0xFFF3E2C7)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.15,
          colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    final grainPaint = Paint()
      ..color = const Color(0xFF8E603C).withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var y = 28.0; y < size.height; y += 42) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x < size.width; x += 96) {
        path.quadraticBezierTo(x + 48, y + 7, x + 96, y);
      }
      canvas.drawPath(path, grainPaint);
    }

    final stonePaint = Paint()
      ..color = const Color(0xFF6E4832).withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(Offset(-18, size.height * 0.18), 72, stonePaint);
    canvas.drawCircle(
      Offset(size.width + 20, size.height * 0.76),
      94,
      stonePaint,
    );

    final sealPaint = Paint()
      ..color = const Color(0xFF9F4635).withValues(alpha: 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 44, size.height * 0.2, 18, 72),
        const Radius.circular(4),
      ),
      sealPaint,
    );
  }

  @override
  bool shouldRepaint(_WoodBackgroundPainter oldDelegate) => false;
}
