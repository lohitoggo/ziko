import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// একটা ছোট "delivery route" motif — ড্যাশড রাস্তা + শেষে স্কুটার আইকন।
/// এটা Ziko-র ডেলিভারি থিমকে reflect করে, শুধু ডেকোরেশন না।
class DeliveryRouteDivider extends StatelessWidget {
  final double height;
  const DeliveryRouteDivider({super.key, this.height = 46});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedWavePainter(color: AppColors.gold),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.softGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delivery_dining,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedWavePainter extends CustomPainter {
  final Color color;
  _DashedWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    path.moveTo(14, midY);

    const waveHeight = 8.0;
    const waveLength = 22.0;
    var x = 14.0;
    var i = 0;
    while (x < size.width - 18) {
      final nextX = x + waveLength;
      final controlY = midY + (i.isEven ? -waveHeight : waveHeight);
      path.quadraticBezierTo(x + waveLength / 2, controlY, nextX, midY);
      x = nextX;
      i++;
    }

    // dashed effect
    final dashPath = Path();
    const dashWidth = 6.0;
    const dashGap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        dashPath.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + dashGap;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedWavePainter oldDelegate) => false;
}