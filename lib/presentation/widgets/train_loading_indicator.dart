import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/korail_colors.dart';

/// KTX 열차가 달리는 로딩 애니메이션 위젯
///
/// 열차 아이콘이 좌→우로 이동하면서 뒤에 연기 트레일을 남긴다.
/// 자동 예약 대기(조회 중, 예약 중) 상태에서 표시한다.
class TrainLoadingIndicator extends StatefulWidget {
  final double? width;
  final double height;
  final Color? color;

  const TrainLoadingIndicator({
    super.key,
    this.width,
    this.height = 48,
    this.color,
  });

  @override
  State<TrainLoadingIndicator> createState() => _TrainLoadingIndicatorState();
}

class _TrainLoadingIndicatorState extends State<TrainLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? KorailColors.korailBlue;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _TrainLoadingPainter(
                  progress: _controller.value,
                  color: color,
                ),
                size: Size(w, h),
              );
            },
          );
        },
      ),
    );
  }
}

class _TrainLoadingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _TrainLoadingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // 레일 (하단 선)
    final railPaint = Paint()
      ..color = color.withAlpha(40)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, centerY + 10),
      Offset(size.width, centerY + 10),
      railPaint,
    );

    // 레일 침목 (짧은 세로선)
    final tiePaint = Paint()
      ..color = color.withAlpha(30)
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(
        Offset(x, centerY + 7),
        Offset(x, centerY + 13),
        tiePaint,
      );
    }

    // 열차 위치 (좌 → 우 이동)
    final trainX = progress * (size.width + 40) - 20;

    // 연기/트레일 효과 (점들)
    final trailPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final trailX = trainX - 18 - (i * 10);
      if (trailX < 0 || trailX > size.width) continue;
      final alpha = ((1.0 - (i / 5)) * 80).toInt();
      trailPaint.color = color.withAlpha(alpha);
      final radius = 2.0 + (i * 0.5);
      final yOffset = sin(progress * pi * 4 + i) * 2;
      canvas.drawCircle(
        Offset(trailX, centerY - 4 + yOffset),
        radius,
        trailPaint,
      );
    }

    // 열차 본체
    if (trainX > -20 && trainX < size.width + 20) {
      _drawTrain(canvas, trainX, centerY);
    }
  }

  void _drawTrain(Canvas canvas, double x, double centerY) {
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 열차 몸체
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x - 16, centerY - 6, 32, 14),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(8),
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // 창문
    final windowPaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 10, centerY - 3, 6, 4),
        const Radius.circular(1),
      ),
      windowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - 3, 6, 4),
        const Radius.circular(1),
      ),
      windowPaint,
    );

    // 앞부분 하이라이트
    final nosePaint = Paint()
      ..color = Colors.white.withAlpha(100)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 10, centerY - 4, 5, 3),
        const Radius.circular(1),
      ),
      nosePaint,
    );

    // 바퀴
    final wheelPaint = Paint()
      ..color = color.withAlpha(180)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x - 8, centerY + 10), 3, wheelPaint);
    canvas.drawCircle(Offset(x + 8, centerY + 10), 3, wheelPaint);
  }

  @override
  bool shouldRepaint(_TrainLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
