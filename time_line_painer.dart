import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pawzzflutter/values/z_color.dart';

class TimeLinePainter extends CustomPainter with ChangeNotifier {
  late double scaleFactor;
  late double offsetX;
  final List<Map<String, int>> events; // 事件列表
  final double totalSeconds;
  late double itemWidth = 0.0; // 时间标签高度
  late double bgWidth = 0.0;
  TimeLinePainter({
    required this.scaleFactor,
    required this.offsetX,
    required this.events,
    required this.totalSeconds,
    required this.itemWidth,
    required this.bgWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    Paint eventPaint = Paint()
      ..color = ZColor.color_845DA1
      ..style = PaintingStyle.fill;
    Paint backPaint = Paint()
      ..color = Color(0xFFE2E2E2)
      ..style = PaintingStyle.fill;

    // 绘制时间轴背景
    canvas.drawRect(Rect.fromLTRB(0, 20, bgWidth, size.height - 20), backPaint);

    // 计算每个时间段的宽度
    double timeStep = itemWidth / (totalSeconds / scaleFactor);

    // 绘制时间轴上的时间刻度（每小时一个刻度）
    double prevXPos = -1;
    // 步长可以调节，下面代码绘制每半小时（30分钟）一个标签
    for (int i = 0; i <= totalSeconds; i += 60 * 60) {
      // 步长为30分钟的秒数
      double xPos = i * timeStep / scaleFactor + offsetX;
      if (xPos - prevXPos < 50) continue; // 避免标签重叠（50是最小间距）

      // 绘制时间刻度
      // canvas.drawLine(
      //   Offset(xPos, size.height / 2 - 10),
      //   Offset(xPos, size.height / 2 + 1),
      //   linePaint,
      // );

      // 绘制时间标签
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: formatTime(i),
          style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(xPos - textPainter.width / 2, 4));

      prevXPos = xPos;
    }

    // 绘制事件区间（紫色部分）
    for (var event in events) {
      double startXPos = event['start']! * timeStep / scaleFactor + offsetX;
      double endXPos = event['end']! * timeStep / scaleFactor + offsetX;

      if (startXPos > size.width || endXPos < 0) continue;

      // 绘制紫色事件块
      canvas.drawRect(
        Rect.fromLTRB(
          startXPos,
          size.height / 2 - 20,
          endXPos,
          size.height / 2 + 20,
        ),
        eventPaint,
      );
    }
  }

 

  // 格式化时间（时:分:秒）
  String formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int sec = seconds % 60;

    // return '$hours:${minutes.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
