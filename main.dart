import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TimelineDemoPage(),
  ));
}

/// ============================================================
/// Demo 页面
/// ============================================================
class TimelineDemoPage extends StatefulWidget {
  const TimelineDemoPage({super.key});

  @override
  State<TimelineDemoPage> createState() => _TimelineDemoPageState();
}

class _TimelineDemoPageState extends State<TimelineDemoPage> {
  final MonitorTimelineController _controller = MonitorTimelineController();

  Duration _currentTime = Duration.zero;
  TimeRange _clipRange = const TimeRange(
    start: Duration(minutes: 10),
    end: Duration(minutes: 30),
  );

  final List<TimelineEvent> _events = const [
    TimelineEvent(
      start: Duration(minutes: 20),
      end: Duration(hours: 1, minutes: 30),
      color: Colors.green,
    ),
    TimelineEvent(
      start: Duration(hours: 2, minutes: 10),
      end: Duration(hours: 3, minutes: 20),
      color: Colors.red,
    ),
    TimelineEvent(
      start: Duration(hours: 5, minutes: 5),
      end: Duration(hours: 6, minutes: 50),
      color: Colors.blue,
    ),
    TimelineEvent(
      start: Duration(hours: 8, minutes: 0),
      end: Duration(hours: 9, minutes: 40),
      color: Colors.orange,
    ),
    TimelineEvent(
      start: Duration(hours: 12, minutes: 25),
      end: Duration(hours: 13, minutes: 10),
      color: Colors.purple,
    ),
    TimelineEvent(
      start: Duration(hours: 16, minutes: 12),
      end: Duration(hours: 17, minutes: 45),
      color: Colors.teal,
    ),
    TimelineEvent(
      start: Duration(hours: 20, minutes: 0),
      end: Duration(hours: 22, minutes: 0),
      color: Colors.cyan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Flutter 时间轴最终版'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: MonitorTimeline(
              controller: _controller,
              height: 180,
              events: _events,
              initialTime: Duration.zero,
              initialPixelsPerSecond: 0.08,
              onCurrentTimeChanged: (time) {
                setState(() => _currentTime = time);
              },
              onClipRangeChanged: (range) {
                setState(() => _clipRange = range);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _controller.jumpToTime(Duration.zero);
                    },
                    child: const Text('跳到 00:00'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _controller.animateToTime(
                        const Duration(hours: 3, minutes: 15),
                      );
                    },
                    child: const Text('滚到 03:15'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _controller.animateToTime(
                        const Duration(hours: 12, minutes: 0),
                      );
                    },
                    child: const Text('滚到 12:00'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _controller.animateToTime(
                        const Duration(hours: 23, minutes: 0),
                      );
                    },
                    child: const Text('滚到 23:00'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _controller.zoomTo(0.20);
                    },
                    child: const Text('放大'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _controller.zoomTo(0.04);
                    },
                    child: const Text('缩小'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final backendTime = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        16,
                        12,
                        35,
                      );
                      await _controller.animateToDateTime(backendTime);
                    },
                    child: const Text('后台当前时间定位'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _controller.setClipRange(
                        const Duration(hours: 13, minutes: 10),
                        const Duration(hours: 13, minutes: 18, seconds: 30),
                        animated: true,
                        keepVisible: true,
                      );
                    },
                    child: const Text('设置裁剪区间'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month, now.day, 18, 0, 0);
                      final end = DateTime(now.year, now.month, now.day, 18, 15, 0);

                      await _controller.setClipDateTimeRange(
                        start,
                        end,
                        animated: true,
                        keepVisible: true,
                      );
                    },
                    child: const Text('后台起止时间裁剪'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _row('当前中线时间', _format(_currentTime)),
          const SizedBox(height: 8),
          _row('裁剪开始时间', _format(_clipRange.start)),
          const SizedBox(height: 8),
          _row('裁剪结束时间', _format(_clipRange.end)),
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  String _format(Duration d) {
    int sec = d.inSeconds;
    sec = sec.clamp(0, 24 * 3600);
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

/// ============================================================
/// 对外控制器
/// ============================================================
class MonitorTimelineController {
  _MonitorTimelineState? _state;

  void _attach(_MonitorTimelineState state) {
    _state = state;
  }

  void _detach(_MonitorTimelineState state) {
    if (_state == state) {
      _state = null;
    }
  }

  bool get isAttached => _state != null;

  Duration? get currentTime => _state?._currentCenterTime();

  TimeRange? get clipRange => _state?._currentClipRange();

  /// 立即跳到指定时间，让该时间落在中线位置
  void jumpToTime(Duration time) {
    _state?._jumpToTime(time);
  }

  /// 动画滚动到指定时间
  Future<void> animateToTime(
    Duration time, {
    Duration duration = const Duration(milliseconds: 450),
    Curve curve = Curves.easeOutCubic,
  }) async {
    await _state?._animateToTime(
      time,
      duration: duration,
      curve: curve,
    );
  }

  /// 立即跳到指定 DateTime（只取当天时分秒）
  void jumpToDateTime(DateTime dateTime) {
    jumpToTime(Duration(
      hours: dateTime.hour,
      minutes: dateTime.minute,
      seconds: dateTime.second,
    ));
  }

  /// 动画滚动到指定 DateTime（只取当天时分秒）
  Future<void> animateToDateTime(
    DateTime dateTime, {
    Duration duration = const Duration(milliseconds: 450),
    Curve curve = Curves.easeOutCubic,
  }) async {
    await animateToTime(
      Duration(
        hours: dateTime.hour,
        minutes: dateTime.minute,
        seconds: dateTime.second,
      ),
      duration: duration,
      curve: curve,
    );
  }

  /// 设置裁剪区间
  Future<void> setClipRange(
    Duration start,
    Duration end, {
    bool animated = false,
    bool keepVisible = true,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    await _state?._setClipRange(
      start,
      end,
      animated: animated,
      keepVisible: keepVisible,
      duration: duration,
    );
  }

  /// 设置 DateTime 裁剪区间
  Future<void> setClipDateTimeRange(
    DateTime start,
    DateTime end, {
    bool animated = false,
    bool keepVisible = true,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    await setClipRange(
      Duration(hours: start.hour, minutes: start.minute, seconds: start.second),
      Duration(hours: end.hour, minutes: end.minute, seconds: end.second),
      animated: animated,
      keepVisible: keepVisible,
      duration: duration,
    );
  }

  /// 外部控制缩放
  Future<void> zoomTo(
    double pixelsPerSecond, {
    Duration duration = const Duration(milliseconds: 250),
  }) async {
    await _state?._animateZoomTo(
      pixelsPerSecond,
      duration: duration,
    );
  }
}

/// ============================================================
/// 数据模型
/// ============================================================
class TimelineEvent {
  final Duration start;
  final Duration end;
  final Color color;

  const TimelineEvent({
    required this.start,
    required this.end,
    required this.color,
  });
}

class TimeRange {
  final Duration start;
  final Duration end;

  const TimeRange({
    required this.start,
    required this.end,
  });
}

class TickConfig {
  final int majorStep;
  final int minorStep;

  const TickConfig({
    required this.majorStep,
    required this.minorStep,
  });
}

/// ============================================================
/// 时间轴控件
/// ============================================================
class MonitorTimeline extends StatefulWidget {
  final MonitorTimelineController? controller;
  final double height;
  final List<TimelineEvent> events;
  final Duration initialTime;
  final double initialPixelsPerSecond;
  final ValueChanged<Duration>? onCurrentTimeChanged;
  final ValueChanged<TimeRange>? onClipRangeChanged;

  const MonitorTimeline({
    super.key,
    this.controller,
    required this.height,
    required this.events,
    this.initialTime = Duration.zero,
    this.initialPixelsPerSecond = 0.08,
    this.onCurrentTimeChanged,
    this.onClipRangeChanged,
  });

  @override
  State<MonitorTimeline> createState() => _MonitorTimelineState();
}

class _MonitorTimelineState extends State<MonitorTimeline>
    with TickerProviderStateMixin {
  static const double _secondsPerDay = 24 * 60 * 60;

  /// 最小/最大缩放
  static const double _minPixelsPerSecond = 0.02;
  static const double _maxPixelsPerSecond = 2.0;

  /// 裁剪框最小时长
  static const int _minClipSeconds = 10;

  /// 裁剪框最小像素宽度
  static const double _minClipWidthPx = 60;

  static const double _clipTop = 62;
  static const double _clipHeight = 72;
  static const double _handleHitWidth = 28;

  /// 当前每秒对应多少像素
  late double _pixelsPerSecond = widget.initialPixelsPerSecond;

  /// 滚动偏移：
  /// 这里的 scrollOffset 直接对应“中线指向的时间像素值”
  /// 当 scrollOffset = 0 时，中线对齐 00:00
  double _scrollOffset = 0;

  /// 视图宽度
  double _viewWidth = 0;

  bool _didApplyInitialTime = false;

  /// 裁剪框左右边界，都是屏幕坐标
  double _clipLeft = 80;
  double _clipRight = 280;

  /// 手势缓存
  double? _lastFocalX;
  double _lastScale = 1.0;

  late final AnimationController _motionController;
  late final AnimationController _zoomController;
  late final AnimationController _clipController;

  Animation<double>? _zoomAnimation;
  Animation<double>? _clipLeftAnimation;
  Animation<double>? _clipRightAnimation;

  double _zoomFocalTime = 0;
  double _zoomFocalX = 0;

  /// 左右额外留白：
  /// 让 00:00 可以显示在屏幕中线
  double get _sideInset => _viewWidth / 2;

  /// 实际时间轴像素长度（不含左右留白）
  double get _timelinePixels => _secondsPerDay * _pixelsPerSecond;

  /// 总内容宽度 = 左留白 + 时间轴 + 右留白
  double get _contentWidth => _sideInset + _timelinePixels + _sideInset;

  /// 最大滚动值：
  /// 当滚到最大时，中线对齐最后时间
  double get _maxScroll => math.max(0, _timelinePixels);

  @override
  void initState() {
    super.initState();

    _motionController = AnimationController.unbounded(vsync: this);
    _motionController.addListener(() {
      final next = _motionController.value.clamp(0.0, _maxScroll);
      if (next != _scrollOffset) {
        setState(() {
          _scrollOffset = next;
        });
        _notifyCurrentTimeChanged();
        _notifyClipRangeChanged();
      }
    });

    _zoomController = AnimationController(vsync: this);
    _zoomController.addListener(() {
      if (_zoomAnimation == null) return;
      final scale = _zoomAnimation!.value;
      _setScaleKeepingFocal(
        scale,
        focalTime: _zoomFocalTime,
        focalX: _zoomFocalX,
      );
    });

    _clipController = AnimationController(vsync: this);
    _clipController.addListener(() {
      if (_clipLeftAnimation == null || _clipRightAnimation == null) return;
      setState(() {
        _clipLeft = _clipLeftAnimation!.value;
        _clipRight = _clipRightAnimation!.value;
      });
      _notifyClipRangeChanged();
    });

    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant MonitorTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _motionController.dispose();
    _zoomController.dispose();
    _clipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        _viewWidth = constraints.maxWidth;
        final centerX = _viewWidth / 2;

        if (!_didApplyInitialTime && _viewWidth > 0) {
          _didApplyInitialTime = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _jumpToTime(widget.initialTime);
          });
        }

        final currentSec = _currentCenterTime().inSeconds;
        final tickConfig = _calculateTickConfig(_pixelsPerSecond);

        return Container(
          color: Colors.black,
          height: widget.height,
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  _stopAllAnimations();
                  _lastFocalX = details.focalPoint.dx;
                  _lastScale = 1.0;
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount <= 1) {
                    /// 单指横向滚动
                    final dx =
                        details.focalPoint.dx - (_lastFocalX ?? details.focalPoint.dx);
                    _lastFocalX = details.focalPoint.dx;
                    _setScrollOffset(_scrollOffset - dx);
                  } else {
                    /// 双指缩放，保持手指所在时间点不跳
                    final scaleDelta = details.scale / _lastScale;
                    _lastScale = details.scale;

                    final focalX = details.focalPoint.dx;
                    final focalTime = _timeFromViewX(focalX);

                    final newScale = (_pixelsPerSecond * scaleDelta)
                        .clamp(_minPixelsPerSecond, _maxPixelsPerSecond);

                    _setScaleKeepingFocal(
                      newScale,
                      focalTime: focalTime,
                      focalX: focalX,
                    );
                  }
                },
                onScaleEnd: (details) async {
                  final velocity = -details.velocity.pixelsPerSecond.dx;

                  /// 仅保留惯性滚动，不做任何吸附
                  if (velocity.abs() < 50) return;

                  final simulation = FrictionSimulation(
                    0.015,
                    _scrollOffset,
                    velocity,
                  );

                  _motionController.value = _scrollOffset;
                  await _motionController.animateWith(simulation);
                },
                child: CustomPaint(
                  size: Size(_viewWidth, widget.height),
                  painter: _TimelinePainter(
                    pixelsPerSecond: _pixelsPerSecond,
                    scrollOffset: _scrollOffset,
                    sideInset: _sideInset,
                    events: widget.events,
                    tickConfig: tickConfig,
                  ),
                ),
              ),

              /// 中线上方时间文本
              Positioned(
                top: 4,
                left: centerX - 50,
                child: Container(
                  width: 100,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatHms(_currentCenterTime().inSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              /// 中间固定竖线
              Positioned(
                left: centerX - 0.5,
                top: 28,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: Colors.yellow,
                ),
              ),

              /// 裁剪框
              Positioned.fill(
                child: _buildClipOverlay(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ============================================================
  /// 裁剪框 UI
  /// ============================================================
  Widget _buildClipOverlay() {
    final clipRange = _currentClipRange();

    return Stack(
      children: [
        /// 中间主体，可整体拖动
        Positioned(
          left: _clipLeft,
          top: _clipTop,
          width: _clipRight - _clipLeft,
          height: _clipHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              _stopAllAnimations();
            },
            onHorizontalDragUpdate: (details) {
              final width = _clipRight - _clipLeft;
              var newLeft = _clipLeft + details.delta.dx;
              newLeft = newLeft.clamp(0.0, _viewWidth - width);

              setState(() {
                _clipLeft = newLeft;
                _clipRight = newLeft + width;
              });
              _notifyClipRangeChanged();
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 2),
                color: Colors.orange.withOpacity(0.16),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_formatHms(clipRange.start.inSeconds)} - ${_formatHms(clipRange.end.inSeconds)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        /// 左手柄
        Positioned(
          left: _clipLeft - _handleHitWidth / 2,
          top: _clipTop,
          width: _handleHitWidth,
          height: _clipHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _stopAllAnimations(),
            onHorizontalDragUpdate: (details) {
              setState(() {
                _clipLeft = (_clipLeft + details.delta.dx).clamp(
                  0.0,
                  _clipRight - math.max(_minClipWidthPx, _minClipSeconds * _pixelsPerSecond),
                );
              });
              _notifyClipRangeChanged();
            },
            child: Center(
              child: Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),

        /// 右手柄
        Positioned(
          left: _clipRight - _handleHitWidth / 2,
          top: _clipTop,
          width: _handleHitWidth,
          height: _clipHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _stopAllAnimations(),
            onHorizontalDragUpdate: (details) {
              setState(() {
                _clipRight = (_clipRight + details.delta.dx).clamp(
                  _clipLeft + math.max(_minClipWidthPx, _minClipSeconds * _pixelsPerSecond),
                  _viewWidth,
                );
              });
              _notifyClipRangeChanged();
            },
            child: Center(
              child: Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// 对外方法实际实现
  /// ============================================================

 /// 当前中线对应的时间（正确写法）
Duration _currentCenterTime() {
  if (_pixelsPerSecond <= 0 || _viewWidth <= 0) return Duration.zero;
  final centerX = _viewWidth / 2;
  double sec = (centerX + _scrollOffset - _sideInset) / _pixelsPerSecond;
  sec = sec.clamp(0.0, 86400.0);
  return Duration(seconds: sec.toInt());
}

  /// 当前裁剪框对应的时间范围
  TimeRange _currentClipRange() {
    final startSec = _timeFromViewX(_clipLeft).round().clamp(0, _secondsPerDay.toInt());
    final endSec = _timeFromViewX(_clipRight).round().clamp(0, _secondsPerDay.toInt());

    return TimeRange(
      start: Duration(seconds: startSec),
      end: Duration(seconds: endSec),
    );
  }

  /// 立即跳到某个时间，让该时间显示在中线
  void _jumpToTime(Duration time) {
    if (_viewWidth <= 0) return;
    _stopAllAnimations();
    _setScrollOffset(_offsetForCenterTime(time));
  }

  /// 动画滚到某个时间
  Future<void> _animateToTime(
    Duration time, {
    Duration duration = const Duration(milliseconds: 450),
    Curve curve = Curves.easeOutCubic,
  }) async {
    if (_viewWidth <= 0) return;
    _stopAllAnimations();

    final target = _offsetForCenterTime(time);
    _motionController.value = _scrollOffset;
    await _motionController.animateTo(
      target,
      duration: duration,
      curve: curve,
    );
  }

  /// 动画缩放，保持中线时间不变
  Future<void> _animateZoomTo(
    double pixelsPerSecond, {
    Duration duration = const Duration(milliseconds: 250),
  }) async {
    if (_viewWidth <= 0) return;
    _stopAllAnimations();

    final centerX = _viewWidth / 2;
    final centerTime = _timeFromViewX(centerX);
    final targetScale =
        pixelsPerSecond.clamp(_minPixelsPerSecond, _maxPixelsPerSecond);

    _zoomFocalTime = centerTime;
    _zoomFocalX = centerX;

    _zoomAnimation = Tween<double>(
      begin: _pixelsPerSecond,
      end: targetScale,
    ).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );

    _zoomController
      ..stop()
      ..reset();
    await _zoomController.animateTo(1.0, duration: duration);
  }

  /// 设置裁剪区间
  Future<void> _setClipRange(
    Duration start,
    Duration end, {
    bool animated = false,
    bool keepVisible = true,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (_viewWidth <= 0) return;

    _stopAllAnimations();

    int startSec = start.inSeconds;
    int endSec = end.inSeconds;

    if (startSec > endSec) {
      final t = startSec;
      startSec = endSec;
      endSec = t;
    }

    startSec = startSec.clamp(0, _secondsPerDay.toInt());
    endSec = endSec.clamp(0, _secondsPerDay.toInt());

    if (endSec - startSec < _minClipSeconds) {
      endSec = (startSec + _minClipSeconds).clamp(0, _secondsPerDay.toInt());
    }

    if (keepVisible) {
      await _ensureTimeRangeVisible(
        Duration(seconds: startSec),
        Duration(seconds: endSec),
      );
    }

    final leftPx = _viewXFromTime(startSec.toDouble());
    final rightPx = _viewXFromTime(endSec.toDouble());

    final minWidth = math.max(_minClipWidthPx, _minClipSeconds * _pixelsPerSecond);
    final targetLeft = leftPx.clamp(0.0, _viewWidth);
    final targetRight = math.max(
      rightPx,
      targetLeft + minWidth,
    ).clamp(0.0, _viewWidth);

    if (!animated) {
      setState(() {
        _clipLeft = targetLeft;
        _clipRight = targetRight;
      });
      _notifyClipRangeChanged();
      return;
    }

    _clipLeftAnimation = Tween<double>(
      begin: _clipLeft,
      end: targetLeft,
    ).animate(
      CurvedAnimation(parent: _clipController, curve: Curves.easeOutCubic),
    );

    _clipRightAnimation = Tween<double>(
      begin: _clipRight,
      end: targetRight,
    ).animate(
      CurvedAnimation(parent: _clipController, curve: Curves.easeOutCubic),
    );

    _clipController
      ..stop()
      ..reset();
    await _clipController.animateTo(1.0, duration: duration);
  }

  /// ============================================================
  /// 工具方法
  /// ============================================================

  void _stopAllAnimations() {
    if (_motionController.isAnimating) _motionController.stop();
    if (_zoomController.isAnimating) _zoomController.stop();
    if (_clipController.isAnimating) _clipController.stop();
  }

  void _setScrollOffset(double value) {
    final next = value.clamp(0.0, _maxScroll);
    if (next == _scrollOffset) return;

    setState(() {
      _scrollOffset = next;
    });
    _notifyCurrentTimeChanged();
    _notifyClipRangeChanged();
  }

  /// 保持焦点时间不变进行缩放
  void _setScaleKeepingFocal(
    double scale, {
    required double focalTime,
    required double focalX,
  }) {
    final newScale = scale.clamp(_minPixelsPerSecond, _maxPixelsPerSecond);

    /// 核心公式：
    /// viewX = sideInset + time * scale - scrollOffset
    /// 已知 focalTime 与 focalX 不变，求新的 scrollOffset
    final newOffset = (_sideInset + focalTime * newScale - focalX)
        .clamp(0.0, _secondsPerDay * newScale);

    setState(() {
      _pixelsPerSecond = newScale;
      _scrollOffset = newOffset;
    });

    _notifyCurrentTimeChanged();
    _notifyClipRangeChanged();
  }

  /// 让某个时间落在中线位置时，对应的 scrollOffset
  double _offsetForCenterTime(Duration time) {
    final sec = time.inSeconds.clamp(0, _secondsPerDay.toInt()).toDouble();

    /// 当时间在中线时：
    /// centerX = sideInset + sec * pps - scrollOffset
    /// 因为 centerX == sideInset
    /// 所以 scrollOffset == sec * pps
    return (sec * _pixelsPerSecond).clamp(0.0, _maxScroll);
  }

  /// 屏幕 x 转时间（秒）
  double _timeFromViewX(double viewX) {
    /// viewX = sideInset + time * pps - scrollOffset
    /// => time = (viewX + scrollOffset - sideInset) / pps
    return ((viewX + _scrollOffset - _sideInset) / _pixelsPerSecond)
        .clamp(0.0, _secondsPerDay);
  }

  /// 时间（秒）转成屏幕 x
  double _viewXFromTime(double sec) {
    return _sideInset + sec * _pixelsPerSecond - _scrollOffset;
  }

  /// 保证某个时间区间可见
  Future<void> _ensureTimeRangeVisible(Duration start, Duration end) async {
    if (_viewWidth <= 0) return;

    final leftPx = _viewXFromTime(start.inSeconds.toDouble());
    final rightPx = _viewXFromTime(end.inSeconds.toDouble());

    double targetOffset = _scrollOffset;

    if (leftPx < 0) {
      targetOffset = _sideInset + start.inSeconds * _pixelsPerSecond;
    } else if (rightPx > _viewWidth) {
      targetOffset = _sideInset + end.inSeconds * _pixelsPerSecond - _viewWidth;
    }

    targetOffset = targetOffset.clamp(0.0, _maxScroll);

    if ((targetOffset - _scrollOffset).abs() > 0.5) {
      _motionController.value = _scrollOffset;
      await _motionController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _notifyCurrentTimeChanged() {
    widget.onCurrentTimeChanged?.call(_currentCenterTime());
  }

  void _notifyClipRangeChanged() {
    widget.onClipRangeChanged?.call(_currentClipRange());
  }

  TickConfig _calculateTickConfig(double pixelsPerSecond) {
    const candidates = <int>[
      1, 2, 5, 10, 15, 30,
      60, 120, 300, 600, 900, 1800,
      3600, 7200, 10800, 21600, 43200,
    ];

    const targetMajorPx = 100.0;

    int bestMajor = candidates.first;
    double bestDiff = double.infinity;

    for (final sec in candidates) {
      final px = sec * pixelsPerSecond;
      final diff = (px - targetMajorPx).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestMajor = sec;
      }
    }

    int minorStep;
    if (bestMajor >= 3600) {
      minorStep = bestMajor ~/ 6;
    } else if (bestMajor >= 60) {
      minorStep = bestMajor ~/ 5;
    } else {
      minorStep = math.max(1, bestMajor ~/ 5);
    }

    return TickConfig(
      majorStep: bestMajor,
      minorStep: math.max(1, minorStep),
    );
  }

  String _formatHms(int totalSec) {
    final sec = totalSec.clamp(0, 24 * 3600);
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

/// ============================================================
/// Painter
/// ============================================================
class _TimelinePainter extends CustomPainter {
  final double pixelsPerSecond;
  final double scrollOffset;
  final double sideInset;
  final List<TimelineEvent> events;
  final TickConfig tickConfig;

  _TimelinePainter({
    required this.pixelsPerSecond,
    required this.scrollOffset,
    required this.sideInset,
    required this.events,
    required this.tickConfig,
  });

  static const double trackTop = 90.0;
  static const double trackHeight = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawTrack(canvas, size);
    _drawEvents(canvas, size);
    _drawTicks(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
  }

  void _drawTrack(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackTop, size.width, trackHeight),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF2B2B2B),
    );
  }

  void _drawEvents(Canvas canvas, Size size) {
    for (final event in events) {
      final left = sideInset + event.start.inSeconds * pixelsPerSecond - scrollOffset;
      final right = sideInset + event.end.inSeconds * pixelsPerSecond - scrollOffset;

      if (right < 0 || left > size.width) continue;

      final rect = Rect.fromLTRB(
        left,
        trackTop,
        right,
        trackTop + trackHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = event.color,
      );
    }
  }

  void _drawTicks(Canvas canvas, Size size) {
    final majorStep = tickConfig.majorStep;
    final minorStep = tickConfig.minorStep;

    final tickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    /// 因为增加了 sideInset，所以可见区间对应的时间需要减去 sideInset
    final startSec = ((scrollOffset - sideInset) / pixelsPerSecond).floor();
    final endSec = ((scrollOffset + size.width - sideInset) / pixelsPerSecond).ceil();

    final firstMinor = (startSec ~/ minorStep) * minorStep;
    double lastLabelX = -9999;

    for (int sec = firstMinor; sec <= endSec; sec += minorStep) {
      if (sec < 0 || sec > 86400) continue;

      final x = sideInset + sec * pixelsPerSecond - scrollOffset;
      final isMajor = sec % majorStep == 0;
      final tickTop = isMajor ? 52.0 : 64.0;

      canvas.drawLine(
        Offset(x, tickTop),
        Offset(x, trackTop),
        tickPaint,
      );

      if (isMajor && (x - lastLabelX > 36)) {
        final label = _formatAdaptiveLabel(sec, majorStep);
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        );
        textPainter.layout();

        final textX = x - textPainter.width / 2;
        final textY = 28.0;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              textX - 3,
              textY - 1,
              textPainter.width + 6,
              textPainter.height + 2,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = Colors.black54,
        );

        textPainter.paint(canvas, Offset(textX, textY));
        lastLabelX = x;
      }
    }
  }

  String _formatAdaptiveLabel(int sec, int majorStep) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;

    if (majorStep >= 3600) {
      return '${h.toString().padLeft(2, '0')}:00';
    } else if (majorStep >= 60) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}';
    } else {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return pixelsPerSecond != oldDelegate.pixelsPerSecond ||
        scrollOffset != oldDelegate.scrollOffset ||
        sideInset != oldDelegate.sideInset ||
        tickConfig.majorStep != oldDelegate.tickConfig.majorStep ||
        tickConfig.minorStep != oldDelegate.tickConfig.minorStep ||
        events != oldDelegate.events;
  }
}
