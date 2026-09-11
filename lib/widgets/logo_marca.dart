import 'package:flutter/material.dart';
import '../theme.dart';

/// Marca Rapistock: R + cajas. Sirve si aún no copiaste assets/logo.png.
class LogoMarca extends StatelessWidget {
  final double size;
  const LogoMarca({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => CustomPaint(painter: _LogoPainter()),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = R.forest;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.22));
    canvas.drawRRect(r, bg);

    final cream = Paint()..color = const Color(0xFFF4F1EA);
    final s = size.width;

    void caja(double x, double y, double w, double h) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(s * 0.03)),
        cream,
      );
      final line = Paint()
        ..color = R.forest
        ..strokeWidth = s * 0.025
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x + w / 2, y + s * 0.02), Offset(x + w / 2, y + h - s * 0.02), line);
    }

    caja(s * 0.52, s * 0.22, s * 0.28, s * 0.22);
    caja(s * 0.48, s * 0.48, s * 0.36, s * 0.28);

    final tp = TextPainter(
      text: TextSpan(
        text: 'R',
        style: TextStyle(
          color: const Color(0xFFF4F1EA),
          fontSize: s * 0.52,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(s * 0.14, s * 0.22));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}