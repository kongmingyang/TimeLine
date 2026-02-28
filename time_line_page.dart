import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawzzflutter/widget/recordTimeLine/time_line_painer.dart';

class TimeLinePage extends StatefulWidget {
   final Function(String endDate) onTimeChange; //滚动结束

  const TimeLinePage({super.key, required this.onTimeChange});
  @override
  State<TimeLinePage> createState() => _TimeLinePageState();
}

class _TimeLinePageState extends State<TimeLinePage> {
  /// 触摸的手指数量
  int _fingers = 0;
  bool _isDragging = false;
  double _initialScaleFactor = 1.5;
  double _initialScale = 1.0;
  double scaleFactor = 2.0; // 当前缩放因子
  double currentScale = 2.0; // 当前缩放因子
  double offsetX = 0.0; // 滚动偏移量
  final double maxScale = 5.0; // 最大缩放倍数
  final double minScale = 2.0; // 最小缩放倍数
  final double totalSeconds = 86400.0; // 一天的总秒数
   double screenWidth = 0.0;
  double _currentCenterSecond = 0.0;
    // 模拟事件数据，表示事件的开始和结束时间（单位：秒）
  List<Map<String, int>> events = [
    {'start': 3600, 'end': 7200}, // 1小时到2小时的事件
    {'start': 10800, 'end': 14400}, // 3小时到4小时的事件
    {'start': 43200, 'end': 46800}, // 12小时到13小时的事件
  ];
    final GlobalKey<_TimeTextState> _textKey = GlobalKey<_TimeTextState>();

  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    // ensure we have the current screen width each build
    screenWidth = MediaQuery.of(context).size.width;

    return Container(
      // height: 100,
      child: Stack(
        children: [
          Listener(
            onPointerDown: (details) {
              _fingers++;
              if (_fingers == 2) {
                setState(() {});
              }
            },
            onPointerUp: (_) {
              _fingers--;
              // if (_fingers == 0) {
              //   setState(() {});
              // }
            },
            onPointerCancel: (_) {
              _fingers--;
              if (_fingers == 0) {
                setState(() {});
              }
            },
            child: GestureDetector(
              onScaleStart: (details) {
                _initialScaleFactor = scaleFactor;
                _initialScale = 1.0;
              },
              onScaleUpdate: (details) {
                // 缩放操作，更新缩放因子
                double currentScale = details.scale / _initialScale;
                // 基于初始缩放因子计算新值，并用 clamp 限制范围
                scaleFactor =
                    (_initialScaleFactor * currentScale).clamp(minScale, maxScale);

                double scrollViewoffset = _currentCenterSecond /
                    totalSeconds *
                    (screenWidth * scaleFactor - screenWidth);
                _scrollController.jumpTo(scrollViewoffset);
                setState(() {});

                print("======scaleFactor:$scaleFactor");
              },
              onScaleEnd: (details) {},

              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  double offset = _scrollController.offset;
                  if (notification is ScrollUpdateNotification) {
                    // 滚动更新时

                    // _timer?.cancel(); // 取消现有定时器
                    print("正在滚动: ${notification.metrics.pixels}");
                    computerTime(offset);
                  }
                  if (notification is ScrollStartNotification) {
                    // 滚动开始时
                    // _timer?.cancel();

                    if (_isDragging == false && _fingers == 1) {
                      _isDragging = true;
                      print("滚动开始: ${notification.metrics.pixels}");
                    }
                  }
                  if (notification is ScrollEndNotification) {
                    // 滚动结束时
                    // _startTimer(); // 重新启动定时器

                    if (_isDragging == true && _fingers == 0) {
                      computerTime(offset);

                      _isDragging = false;
                      print("滚动结束的时间: ${_currentCenterSecond}");
                      //滚动的回调
                      widget.onTimeChange(_formatSeconds(_currentCenterSecond));
                    }
                  }

                  return true; // 返回 true 表示事件已消费，不传递给其他通知
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: _fingers > 1
                      ? NeverScrollableScrollPhysics()
                      : BouncingScrollPhysics(),
                  child: Container(
                    width: screenWidth * scaleFactor,
                    child: CustomPaint(
                      size: Size(screenWidth * scaleFactor, 80), // 固定宽度和高度
                      painter: TimeLinePainter(
                        scaleFactor: scaleFactor,
                        offsetX: offsetX + screenWidth / 2,
                        events: events,
                        totalSeconds: totalSeconds,
                        itemWidth: screenWidth * scaleFactor - screenWidth,
                        bgWidth: screenWidth * scaleFactor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: screenWidth / 2 - 0.5,
            child: Container(
              width: 1,
              height: 45,
              color: Color(0xFF515151),
            ),
          ),

          Positioned(
            top: 62,
            left: 10,
            right: 10,
            child: // 可独立更新的文本组件
                TimeText(
              key: _textKey,
              initialText: _formatSeconds(_currentCenterSecond),
            ),
          ),
        ],
      ),
    );
  }

   //更新时间信息
  void computerTime(double offset) {
    double timeStep = totalSeconds / (screenWidth * scaleFactor - screenWidth);

    _currentCenterSecond = offset * timeStep.abs();
    if (_currentCenterSecond >= totalSeconds) {
      _currentCenterSecond = totalSeconds;
    } else if (_currentCenterSecond <= 0) {
      _currentCenterSecond = 0;
    }
    _textKey.currentState?.updateText(
      "${_formatSeconds(_currentCenterSecond)}",
    );
  }
   void scrollToSecond(double offset) {
    _scrollController.jumpTo(offset);

   }

   // 格式化秒数为时间字符串
  String _formatSeconds(double seconds) {
    int roundedSeconds = seconds.round();
    final hours = (roundedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((roundedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (roundedSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secs';
  }
   
}


class TimeText extends StatefulWidget {
  final String initialText;
  final double? fontSize;
  final Color? color;
  final FontWeight? fontWeight;

  const TimeText({
    super.key,
    required this.initialText,
    this.fontSize = 12.0,
    this.color = Colors.black,
    this.fontWeight = FontWeight.normal,
  });

  @override
  State<TimeText> createState() => _TimeTextState();
}

class _TimeTextState extends State<TimeText> {
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
  }

  // 提供外部更新文本的方法
  void updateText(String newText) {
    setState(() {
      _text = newText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      textAlign: TextAlign.center,
      style: GoogleFonts.notoSans(
        fontSize: widget.fontSize,
        color: Colors.black.withOpacity(0.9),
        fontWeight: widget.fontWeight,
      ),
    );
  }
}