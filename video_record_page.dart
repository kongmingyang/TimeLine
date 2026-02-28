import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_boost/flutter_boost.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pawzzflutter/Config/user_cache.dart';
import 'package:pawzzflutter/Http/api.dart';
import 'package:pawzzflutter/Utils/mqtt_client_helper.dart';
import 'package:pawzzflutter/constant/constants.dart';
import 'package:pawzzflutter/constant/mqtt_cmd_constants.dart';
import 'package:pawzzflutter/logic/home/feeder/feeder_real_time_logic.dart';
import 'package:pawzzflutter/model/home/device_list_model.dart';
import 'package:pawzzflutter/model/home/feeder/record_video_model.dart';
import 'package:pawzzflutter/model/home/rtc_room_model.dart';
import 'package:pawzzflutter/model/mqtt/mqtt_send_receive_head.dart';
import 'package:pawzzflutter/model/mqtt/receive/get_feed_location_receive.dart';
import 'package:pawzzflutter/model/mqtt/send/enter_room_send.dart';
import 'package:pawzzflutter/values/z_color.dart';
import 'package:pawzzflutter/widget/screen_marked_dot_date_dialog.dart';
import 'package:volc_engine_rtc/api/bytertc_audio_defines.dart';
import 'package:volc_engine_rtc/api/bytertc_media_defines.dart';
import 'package:volc_engine_rtc/api/bytertc_render_view.dart';
import 'package:volc_engine_rtc/api/bytertc_room_api.dart';
import 'package:volc_engine_rtc/api/bytertc_room_event_handler.dart';
import 'package:volc_engine_rtc/api/bytertc_rts_defines.dart';
import 'package:volc_engine_rtc/api/bytertc_video_api.dart';
import 'package:volc_engine_rtc/api/bytertc_video_defines.dart';
import 'package:volc_engine_rtc/api/bytertc_video_event_handler.dart';

class VideoRecordPage extends StatefulWidget {
  dynamic? data;

  VideoRecordPage({super.key, this.data});

  @override
  State<VideoRecordPage> createState() => _VideoRecordPageState();
}

class _VideoRecordPageState extends State<VideoRecordPage> {
  // 时间轴相关变量
  Timer? _timer; // 定时器
  /// 触摸的手指数量
  int _fingers = 0;
  bool _isDragging = false;
  double _initialScaleFactor = 1.5;
  double _initialScale = 1.0;
  double scaleFactor = 2.0; // 当前缩放因子
  double currentScale = 2.0; // 当前缩放因子
  double offsetX = 0.0; // 滚动偏移量
  final double maxScale = 33; // 最大缩放倍数
  final double minScale = 2.0; // 最小缩放倍数
  final double totalSeconds = 86400.0; // 一天的总秒数
  String chooseDate = '今天';
  String _currentDate = ''; //当前时间
  double _currentCenterSecond = 0.0; //当前播放时间
  double _startPlaySecond = 0.0; //开始播放时间
  MqttClientHelper? mqttHelper;
  int curPage = 1; //当前查询数量
  FeederRealTimeLogic ctrl = Get.put(FeederRealTimeLogic());
  RTCVideo? _rtcVideo;
  RTCRoom? _rtcRoom;
  final RTCVideoEventHandler _videoHandler = RTCVideoEventHandler();
  final RTCRoomEventHandler _roomHandler = RTCRoomEventHandler();
  final startTimes = <int>[]; //所有开始时间数组
  RTCViewContext? _remoteRenderContext;
  String? _remoteUserId;
  double _rate = 0.0; //速率
  bool _isMute = false; //是否静音 默认放声音
  late final DeviceListModel deviceModel;
  RTCRoomModel rtcRoomModel = RTCRoomModel();
  // 模拟事件数据，表示事件的开始和结束时间（单位：秒）
  List<Map<String, int>> events = [
    // {'start': 3600, 'end': 7200}, // 1小时到2小时的事件
    // {'start': 10800, 'end': 14400}, // 3小时到4小时的事件
    // {'start': 43200, 'end': 46800}, // 12小时到13小时的事件
  ];
  String firstStartTime = ""; //第一条录像的开始时间
  String playIngtime = "";
  List<Map<String, dynamic>> videoList = []; //录像事件
  List<String> _dates = []; //有录像的日期
  List<RecorVideodModel> _videoItems = []; //有录像的时间

  double screenWidth = 0.0;
  bool isAudioMuted = false; //是否静音
  bool _isPlaying = true; //是否播放中
  bool _isLeave = false; //是否离开房间
  bool isStopScroll = false; //是否停止滚动时间轴

  double timeSpace = 0.0; //存储时间间隔。记录跨天的时间间隔

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<_UpdatableTextState> _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // _startTimer();
    // _scrollController.addListener(_onScroll);
    mqttHelper = MqttClientHelper();
    DateTime now = DateTime.now();

    // 2. 提取日期/时间各字段
    int year = now.year; // 年（如 2024）
    int month = now.month; // 月（1-12）
    int day = now.day; // 日（1-31）
    _currentDate =
        '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';

    deviceModel = DeviceListModel.fromJson(widget.data);
    ctrl.userModel.value = HiveUserCache.getCurrentUserModel()!;

    ctrl.refreshMutteringList();
    _remoteUserId = '${Constants.DEVICE_USER_PRE}video_${deviceModel.deviceSn}';
    Api.getRTCRoomInfo(deviceModel.deviceSn!).then((data) {
      if (null != data) {
        ctrl.rtcRoomModel = RTCRoomModel.fromJson(data);
        print("deviceModel的appid${ctrl.rtcRoomModel.appId}");
        _initVideoAndJoinRoom();
        _initVideoEventHandler();
        _initRoomEventHandler();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    // 释放定时器
    _scrollController.dispose();
    _timer?.cancel();
    _timer = null; // 置空避免野指针
    _rtcRoom?.destroy();
    _rtcRoom = null;
    _rtcVideo?.destroy();
    _rtcVideo = null;
    leavePlayBack();
    _isLeave = true;
  }

  void _initVideoEventHandler() {
    /// SDK收到第一帧远端视频解码数据后，用户收到此回调。
    _videoHandler.onFirstRemoteVideoFrameDecoded =
        (RemoteStreamKey streamKey, VideoFrameInfo videoFrameInfo) {
          debugPrint(
            '-----------onFirstRemoteVideoFrameDecoded: ${streamKey.uid}',
          );
          String? uid = streamKey.uid;
          if (_remoteRenderContext?.uid == uid) {
            return;
          }

          /// 设置远端用户视频渲染视图
          if (_remoteRenderContext == null) {
            setState(() {
              _remoteRenderContext = RTCViewContext.remoteContext(
                roomId: ctrl.rtcRoomModel.roomId!,
                uid: uid,
              );
            });
          } else {}
        };
    _videoHandler.onRemoteVideoStateChanged =
        (
          RemoteStreamKey streamKey,
          RemoteVideoState state,
          RemoteVideoStateChangeReason reason,
        ) {
          print(
            "-----------远端视频流-------   uid: ${streamKey.uid}    streamIndex: ${streamKey.streamIndex}   state: ${state.hashCode}====$_remoteUserId",
          );
          if (streamKey.uid == _remoteUserId) {
            _rtcRoom!.subscribeStream(
              uid: streamKey.uid,
              type: MediaStreamType.both,
            );
          }
        };
    _videoHandler.onLocalAudioPropertiesReport =
        (List<LocalAudioPropertiesInfo> audioPropertiesInfos) {
          //会周期性收到此回调，获取本地麦克风和屏幕采集的音量信息
          /// 线性音量，与原始音量呈线性关系，数值越大，音量越大。取值范围是：`[0,255]`。
          ///
          /// - `[0, 25]`：无声
          /// - `[26, 75]`：低音量
          /// - `[76, 204]`：中音量
          /// - `[205, 255]`：高音量
          final int? linearVolume;

          /// 非线性音量，由原始音量的对数值转化而来，因此在中低音量时更灵敏，可以用作 Active Speaker（房间内最活跃用户）的识别。取值范围是：`[-127，0]`，单位：dB。
          ///
          /// - `[-127, -60]`：无声
          /// - `[-59, -40]`：低音量
          /// - `[-39, -20]`：中音量
          /// - `[-19, 0]`：高音量
          final int? nonlinearVolume;

          /// 人声检测（VAD）结果
          ///
          /// - 1：检测到人声
          /// - 0：未检测到人声
          /// - -1：未开启 VAD
          final int? vad;

          /// 本地用户的人声基频，单位为赫兹
          ///
          /// v3.57 新增。
          ///
          /// 同时满足以下两个条件时，返回的值为本地用户的人声基频：
          /// + 调用 [RTCVideo.enableAudioPropertiesReport]，并设置参数 enableVoicePitch 的值为 `true`；
          /// + 本地采集的音频中包含本地用户的人声。
          ///
          /// 其他情况下返回 `0`。
          final double? voicePitch;
          print(
            "========  本地音频信息  ===== linearVolume ： ${audioPropertiesInfos[0].audioPropertiesInfo!.linearVolume}    nonlinearVolume： ${audioPropertiesInfos[0].audioPropertiesInfo!.nonlinearVolume}   vad： ${audioPropertiesInfos[0].audioPropertiesInfo!.vad}   voicePitch：${audioPropertiesInfos[0].audioPropertiesInfo!.voicePitch}",
          );
        };

    /// 警告回调，详细可以看 {https://pub.dev/documentation/volc_engine_rtc/latest/api_bytertc_common_defines/WarningCode.html}
    _videoHandler.onWarning = (WarningCode code) {
      debugPrint('warningCode: $code');
    };

    /// 错误回调，详细可以看 {https://pub.dev/documentation/volc_engine_rtc/latest/api_bytertc_common_defines/ErrorCode.html}
    _videoHandler.onError = (ErrorCode code) {
      debugPrint('errorCode: $code');
      //_showAlert('errorCode: $code');
    };
  }

  void _initVideoAndJoinRoom() async {
    _rtcVideo = await RTCVideo.createRTCVideo(
      RTCVideoContext(ctrl.rtcRoomModel.appId!, eventHandler: _videoHandler),
    );

    if (_rtcVideo == null) {
      return;
    }

    VideoEncoderConfig solution = VideoEncoderConfig(
      width: 360,
      height: 640,
      frameRate: 15,
      maxBitrate: 800,
      encoderPreference: VideoEncoderPreference.maintainFrameRate,
    );
    _rtcVideo?.setMaxVideoEncoderConfig(solution);

    AudioPropertiesConfig audioPropertiesConfig = AudioPropertiesConfig(
      interval: 100,
      enableSpectrum: true,
      enableVad: false,
      localMainReportMode: AudioReportMode.normal,
      audioReportMode: AudioPropertiesMode.microphone,
      smooth: 0.3,
    ); //信息提示间隔单位：ms  是否开启音频频谱检测  是否开启人声检测 (VAD)  音量回调模式  适用于音频属性信息提示的平滑系数。取值范围是 (0.0, 1.0]。默认值为 1.0，不开启平滑效果；值越小，提示音量平滑效果越明显。如果要开启平滑效果，可以设置为 0.3。  是否回调本地用户的人声基频。
    _rtcVideo?.enableAudioPropertiesReport(audioPropertiesConfig);
    _rtcVideo?.stopAudioCapture();

    /// 开启本地视频采集
    //_rtcVideo?.startVideoCapture();

    /// 开启本地音频采集
    // _rtcVideo?.startAudioCapture();

    /// 创建房间
    _rtcRoom = await _rtcVideo?.createRTCRoom(ctrl.rtcRoomModel.roomId!);

    /// 设置房间事件回调处理
    _rtcRoom?.setRTCRoomEventHandler(_roomHandler);

    /// 加入房间
    UserInfo userInfo = UserInfo(uid: ctrl.rtcRoomModel.userId!);
    RoomConfig roomConfig = RoomConfig(
      isAutoPublish: false,
      isAutoSubscribeAudio: true,
      isAutoSubscribeVideo: true,
    );
    _rtcRoom?.joinRoom(
      token: ctrl.rtcRoomModel.token!,
      userInfo: userInfo,
      roomConfig: roomConfig,
    );

    _rtcVideo?.setPlaybackVolume(100);

    // AudioPropertiesConfig audioPropertiesConfig = AudioPropertiesConfig(100, true, false, AudioReportMode.AUDIO_REPORT_MODE_NORMAL, 0.3f, AudioPropertiesMode.AUDIO_PROPERTIES_MODE_MICROPHONE); //信息提示间隔单位：ms  是否开启音频频谱检测  是否开启人声检测 (VAD)  音量回调模式  适用于音频属性信息提示的平滑系数。取值范围是 (0.0, 1.0]。默认值为 1.0，不开启平滑效果；值越小，提示音量平滑效果越明显。如果要开启平滑效果，可以设置为 0.3。  是否回调本地用户的人声基频。

    // _rtcRoom?.publishStream(MediaStreamType.audio);
    // _rtcRoom?.publishStream(MediaStreamType.audio);
    // _rtcVideo?.stopAudioCapture();
    // _rtcVideo?.setCaptureVolume(volume: 100);
    // _rtcRoom?.publishStream(MediaStreamType.audio);
    // _rtcVideo?.setCaptureVolume(volume: 0);
  }

  void _initRoomEventHandler() {
    /// 远端主播角色用户加入房间回调。
    _roomHandler.onUserJoined = (UserInfo userInfo, int elapsed) {
      debugPrint(
        '+++++++++++++++++++   -----------   onUserJoined: ${userInfo.uid}',
      );
    };
    // _roomHandler.onRoomMessageReceived = (String uid, String message) {
    //   //收到广播消息
    //   debugPrint('onRoomMessageReceived: $uid message: $message');
    // };
    // _roomHandler.onUserMessageReceived = (String uid, String message) {
    //   //收到点对点消息
    //   debugPrint('onUserMessageReceived: $uid message: $message');
    // };
    /// 远端用户离开房间回调。
    _roomHandler.onUserLeave = (String uid, UserOfflineReason reason) {
      debugPrint('onUserLeave: $uid reason: $reason');
      if (_remoteRenderContext?.uid == uid) {
        setState(() {
          _remoteRenderContext = null;
        });
        _rtcVideo?.removeRemoteVideo(
          uid: uid,
          roomId: ctrl.rtcRoomModel.roomId!,
        );
      }
    };

    _roomHandler.onRemoteStreamStats = (RemoteStreamStats stats) {
      print("接受的id====$_remoteUserId ==== ${stats.uid}");
      if (stats.uid! == _remoteUserId) {
        // 接收码率。统计周期内的视频接收码率，单位为 kbps 。
        RemoteVideoStats remoteVideoStats = stats.videoStats!;
        print("接受码流====${remoteVideoStats.receivedKBitrate}");
        setState(() {
          _rate = remoteVideoStats.receivedKBitrate! / 8;
        });
      }
    };

    _roomHandler.onRoomStateChanged =
        (String roomId, String uid, int state, String extraInfo) {
          print("---------加入房间-------- $uid");
          if (uid == ctrl.rtcRoomModel.userId!) {
            //用户自己进入房间，发送 enter_view   和  upload_info
            _enterRoom();
          }
        };
  }

  //发送回看信息
  Future<void> _enterRoom() async {
    String sendTopic =
        "${Constants.MQTT_DEVICE_SUBSCRIBE_PRE}${Constants.MQTT_DEVICE_MODEL}/${deviceModel.deviceSn}${Constants.MQTT_SUBSCRIBE_send}";

    EnterRoomSend sendModel = EnterRoomSend(
      head: MqttSendReceiveHead(cmd: MqttCmdConstants.ENTER_PLAYBACK),
      body: EnterRoomSendBody(),
    );

    await mqttHelper?.publishMessage(sendTopic, jsonEncode(sendModel));
    listRecordDay();
    listRecordDetail(_currentDate);
  }

  //查询回放日期
  Future<void> listRecordDay() async {
    String sendTopic =
        "${Constants.MQTT_DEVICE_SUBSCRIBE_PRE}${Constants.MQTT_DEVICE_MODEL}/${deviceModel.deviceSn}${Constants.MQTT_SUBSCRIBE_send}";
    EnterRoomSend sendModel = EnterRoomSend(
      head: MqttSendReceiveHead(cmd: "list_record_day"),
      body: EnterRoomSendBody(),
    );

    await mqttHelper?.publishMessage(sendTopic, jsonEncode(sendModel));
  }

  //查询每天的信息
  Future<void> listRecordDetail(String dateStr) async {
    final String s_sec = dateStr + " 00:00:00";
    final String e_sec = dateStr + " 23:59:59";

    final Map body = {
      "s_sec": s_sec,
      "e_sec": e_sec,
      "curPage": curPage,
      "pageSize": 10,
    };
    Map<String, dynamic> msg = {
      "head": MqttSendReceiveHead(cmd: "list_record_detail").toJson(),
      "body": body,
    };
    String sendTopic =
        "${Constants.MQTT_DEVICE_SUBSCRIBE_PRE}${Constants.MQTT_DEVICE_MODEL}/${deviceModel.deviceSn}${Constants.MQTT_SUBSCRIBE_send}";

    await mqttHelper?.publishMessage(sendTopic, jsonEncode(msg));
    mqttMessageHandle();
  }

  /// 核心转换方法：提取s_sec/e_sec并转为当天秒数，构造start/end数组
  List<Map<String, int>> convertVideoTimeToSeconds(List<dynamic> videoList) {
    List<Map<String, int>> result = [];
    print("输出要转换视频列表: $videoList");
    // 时间格式解析器（匹配 yyyy/MM/dd HH:mm:ss）
    final dateFormat = 'yyyy/MM/dd HH:mm:ss';

    for (var video in videoList) {
      try {
        // 提取s_sec/e_sec字符串
        String sSecStr = video['s_sec'];
        String eSecStr = video['e_sec'];
        String sDateStr = sSecStr.substring(0, 10);
        String eDateStr = eSecStr.substring(0, 10);

        if (sDateStr != _currentDate && eDateStr != _currentDate) {
          sSecStr = "$_currentDate 00:00:00";
          eSecStr = "$_currentDate 00:00:00";
        } else {
          if (sDateStr != _currentDate) {
            sSecStr = "$_currentDate 00:00:00";
          }
          if (eDateStr != _currentDate) {
            eSecStr = "$_currentDate 23:59:59";
          }
        }

        // 解析为DateTime对象（处理格式异常）
        DateTime sTime = DateTime.parse(sSecStr.replaceAll('/', '-'));
        DateTime eTime = DateTime.parse(eSecStr.replaceAll('/', '-'));

        // 计算当前时间相对于「当天0点0分0秒」的总秒数
        int startSeconds = sTime.hour * 3600 + sTime.minute * 60 + sTime.second;
        int endSeconds = eTime.hour * 3600 + eTime.minute * 60 + eTime.second;
        startTimes.add(startSeconds);
        // 添加到结果数组
        result.add({'start': startSeconds, 'end': endSeconds});
      } catch (e) {
        // 解析失败时的容错处理（可根据需求调整，比如添加默认值/跳过）
        print('输出解析视频${video['s_sec']}时间失败：$e');
        result.add({'start': 0, 'end': 0});
      }
    }

    return result;
  }

  //时间字符串转换为秒数
  int timeStrToSeconds(String timeStr) {
    final dateFormat = 'yyyy/MM/dd HH:mm:ss';
    DateTime sTime = DateTime.parse(timeStr.replaceAll('/', '-'));
    int startSeconds = sTime.hour * 3600 + sTime.minute * 60 + sTime.second;
    return startSeconds;
  }

  //开始播放指定时间
  Future<void> startPlayRecord(String s_sec) async {
    if (s_sec.length < 1) {
      setState(() {
        _isPlaying = false;
      });
      return;
    }
    String sendTopic =
        "${Constants.MQTT_DEVICE_SUBSCRIBE_PRE}${Constants.MQTT_DEVICE_MODEL}/${deviceModel.deviceSn}${Constants.MQTT_SUBSCRIBE_send}";

    final Map body = {"s_sec": s_sec};
    Map<String, dynamic> sendModel = {
      "head": MqttSendReceiveHead(cmd: "start_play_record").toJson(),
      "body": body,
    };

    s_sec = s_sec.replaceAll('  ', ' ');
    print("输出开始播放时间: $s_sec");
    _startPlaySecond = timeStrToSeconds(s_sec).toDouble();
    await mqttHelper?.publishMessage(sendTopic, jsonEncode(sendModel));
  }

  //暂停播放
  Future<void> stopPlayRecord() async {
    String sendTopic =
        "${Constants.MQTT_DEVICE_SUBSCRIBE_PRE}${Constants.MQTT_DEVICE_MODEL}/${deviceModel.deviceSn}${Constants.MQTT_SUBSCRIBE_send}";
    EnterRoomSend sendModel = EnterRoomSend(
      head: MqttSendReceiveHead(cmd: "stop_play_record"),
      body: EnterRoomSendBody(),
    );

    await mqttHelper?.publishMessage(sendTopic, jsonEncode(sendModel));
  }

  //退出观看
  leavePlayBack() {
    String sendTopic =
        "${Constants.MQTT_DEVICE_SUBSCRIBE_PRE}${Constants.MQTT_DEVICE_MODEL}/${deviceModel.deviceSn}${Constants.MQTT_SUBSCRIBE_send}";
    EnterRoomSend sendModel = EnterRoomSend(
      head: MqttSendReceiveHead(cmd: "leave_playback"),
      body: EnterRoomSendBody(),
    );
    print("输出离开房间====");
    mqttHelper?.publishMessage(sendTopic, jsonEncode(sendModel));
  }

  void mqttMessageHandle() {
    mqttHelper?.setMessageCallback((String topic, String message) {
      if (_isLeave) {
        return;
      }
      Map<String, dynamic> jsonMap = jsonDecode(message);
      GetFeedLocationReceive receive = GetFeedLocationReceive.fromJson(jsonMap);
      final cmd = receive.head?.cmd ?? "";
      final body = jsonMap["body"] ?? {};
      int resultStatus = jsonMap["code"] ?? 0;
      final msg = jsonMap["message"] ?? "";
        print("输出进入回放失败信息: ===$cmd ======${body["code"]}");
        if (receive.user_id != HiveUserCache.getCurrentUserModel()?.id!){
          return;
        }
     
      if (cmd == "list_record_detail") {
        final curpage = body["curPage"] ?? 1;
        final totalPage = body["totalPage"] ?? 1;
        // 1. 修复：替换不安全的强转，兜底为空数组（核心！避免null导致的隐性空数组）
        final List<dynamic> video_list = body["video_list"] is List
            ? List.from(body["video_list"]) // 深拷贝避免原数组被修改
            : [];
        print("输出当天录像时间: $body");

        // 2. 修复：map遍历中添加return，正确转换模型（否则modelList全为null）
        final modelList = video_list
            .where((json) {
              final isMap = json is Map<String, dynamic>;
              if (!isMap) {
                print("json不是Map类型，跳过转换: $json");
              }
              return isMap;
            })
            .map((json) {
              try {
                String sSecStr = json['s_sec'];
                String eSecStr = json['e_sec'];
                String sDateStr = sSecStr.substring(0, 10);
                String eDateStr = eSecStr.substring(0, 10);

                if (sDateStr != _currentDate && eDateStr != _currentDate) {
                  sSecStr = "$_currentDate 00:00:00";
                  eSecStr = "$_currentDate 00:00:00";
                  json['s_sec'] = sSecStr;
                  json['e_sec'] = eSecStr;
                  json['video_id'] = json['video_id'];
                } else {
                  if (sDateStr != _currentDate) {
                    timeSpace = (86400 - timeStrToSeconds(sSecStr)) as double;
                    sSecStr = "$_currentDate 00:00:00";
                  }
                  if (eDateStr != _currentDate) {
                    eSecStr = "$_currentDate 23:59:59";
                  }
                  json['s_sec'] = sSecStr;
                  json['e_sec'] = eSecStr;
                }
                return RecorVideodModel.fromJson(json as Map<String, dynamic>);
              } catch (e, stack) {
                print("json解析为RecorVideodModel失败: $json, 错误: $e, 堆栈: $stack");
                return null; // 解析失败返回null
              }
            })
            .where((model) => model != null) // 过滤解析失败的null
            .cast<RecorVideodModel>() // 安全移除可空标记（因为已过滤null）
            .toList();

        print("输出录像信息: $modelList");
        _videoItems.addAll(modelList);
        String jsonUrl = "";
        // 3. 修复：判空用isNotEmpty（语义更清晰），且修正变量名video_list（而非videoList）
        if (video_list.isNotEmpty) {
          // 修复：增加类型校验+兜底，避免非Map类型导致崩溃
          final videoListMap = video_list[0] as Map<String, dynamic>? ?? {};
          List<Map<String, int>> resultList = convertVideoTimeToSeconds(
            video_list,
          );
          print("输出转换后录像信息: $resultList");

          String jsonUrlStr = videoListMap["json_url"]?.toString().trim() ?? "";

          jsonUrl = jsonUrlStr.isNotEmpty ? "https://$jsonUrlStr" : "";
          if (curpage == 1) {
            firstStartTime = videoListMap["s_sec"]?.toString().trim() ?? "";

            String sSecStr = videoListMap['s_sec'];
            String sDateStr = sSecStr.substring(0, 10);
            if (sDateStr != _currentDate) {
              firstStartTime = "$_currentDate 00:00:00";
            }
            print("输出第一条录像开始时间: $firstStartTime");
            startPlayRecord(firstStartTime);
          }
          events.addAll(resultList);
          print("输出录像信息数量: ${events.length} ");
        } else {
          print("video_list为空，跳过数据处理");
        }

        if (curpage < totalPage) {
          curPage += 1;
          listRecordDetail(_currentDate);
        } else {
          Api.fetchJsonWithDio(jsonUrl).then((value) {
            print("输出录像信息: $value");
            final persons = value["persons"] is List
                ? List.from(value["persons"]) // 深拷贝避免原数组被修改
                : [];
            final pets = value["pet"] is List
                ? List.from(value["pet"]) // 深拷贝避免原数组被修改
                : [];
            if (persons.isNotEmpty) {
              // 添加人脸数据
              List<Map<String, int>> personList = convertVideoTimeToSeconds(
                persons,
              );
              events.addAll(personList);
            }
            if (pets.isNotEmpty) {
              // 添加人脸数据
              List<Map<String, int>> petList = convertVideoTimeToSeconds(pets);
              events.addAll(petList);
            }
          });
          setState(() {
            print("输出录像信息数量: ${events.length} ");
            events = events;
          });
        }
      }
      if (cmd == "enter_playback") {
      
          final code = jsonMap["code"] ?? 0;
          print("enter_playback===== $body=======$code");
         if (code == 500) {
        showToast(msg);
        // _rtcRoom?.destroy();
        // _rtcVideo?.destroy();
        Navigator.of(context).pop();

        return;
      }
        if (resultStatus != 0) {
          showToast(msg);
        }
      }
      //播放录像
      if (cmd == "start_play_record") {
        final status = body["status"] ?? true;
        if (status == false) {
          stopPlayRecord();
          if (isStopScroll) {
            final int? closestTime = findClosestNumber(
              _currentCenterSecond.toInt(),
            );
            String startTime = "$_currentDate ${formatTime(closestTime ?? 0)}";
            startPlayRecord(startTime);
          } else {
            showToast(msg);
          }
          setState(() {
            _isPlaying = false;
          });
        } else {
          setState(() {
            isStopScroll = false;
            _isPlaying = true;
          });
        }
      }
      if (cmd == "play_progress_broadcast") {
        final video_id = body["video_id"] ?? 0;
        print("play_progress_broadcast=====");
        double times = body["time"] ?? 0.0;
        double startSecond = 0;
        if (resultStatus != 0) {
          showToast(msg);
        } else {
          setState(() {
            try {
              // 匹配第一个 ID 相等的对象
              print(
                "输出视频ID: ${_videoItems.map((e) => e.videoId).toList()} ==== $video_id",
              );
              final videoItem = _videoItems.firstWhere(
                (user) => user.videoId == video_id,
              );
              print("获取匹配对象==$videoItem");
              if (videoItem != null && videoItem.sSec.contains("00:00:00")) {
                times = times - timeSpace;
                print("开始0点播放: $times");
                startSecond = timeStrToSeconds(videoItem.sSec).toDouble();
              }
              _startPlaySecond = timeStrToSeconds(videoItem.sSec).toDouble();
              print("获取匹配对象===${videoItem.sSec}=====$_startPlaySecond");
            } on StateError {
              // 无匹配时抛出 StateError，捕获后返回 null
            }
            // _currentCenterSecond = _startPlaySecond + times;
            if (_currentCenterSecond > 86400) {
              _currentCenterSecond = 86400;
              stopPlayRecord();
            }
            _currentCenterSecond = _startPlaySecond + times;
            print(
              "输出当前播放时间: $_currentCenterSecond ====== $_startPlaySecond====== $times",
            );

            _startTimer();
          });
        }
      }
      if (cmd == "leave_playback") {
        // final status = body["status"] ?? true;
        // if (status == false) {
        //   showToast(msg);
        // }
      }
      if (cmd == "stop_play_record") {
        final status = body["status"] ?? true;
        if (status == false) {
          _isPlaying = true;
          showToast(msg);
        } else {
          _isPlaying = false;
        }
        setState(() {});
      }
      if (cmd == "list_record_day") {
        final dates = body["date"] ?? [];

        _dates = dates
            .map<String>((e) => e.toString().replaceAll('/', '-'))
            .toList();
        print("输出录像日期: $_dates=====$dates");
        setState(() {});
      }
    });
  }

  void _enableMute() {
    setState(() {
      isAudioMuted = !isAudioMuted;
    });

    if (isAudioMuted) {
      _rtcVideo?.setPlaybackVolume(0);
    } else {
      _rtcVideo?.setPlaybackVolume(100);
    }
  }

  // 格式化秒数为时间字符串
  String _formatSeconds(double seconds) {
    int roundedSeconds = seconds.round();
    final hours = (roundedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((roundedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (roundedSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secs';
  }

  Widget _buildRtcView() {
    return _remoteRenderContext == null
        ? Container(
            width: double.infinity,
            height: double.infinity,
            color: ZColor.black,
            child: Text(''),
          )
        : RTCSurfaceView(
            context: _remoteRenderContext!,
            backgroundColor: 0xff000000,
          );
  }

  void showCalendarDialog(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // 允许全屏高度
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: ScreenMarkedDotDateDialog(type: 2, recordDates: _dates),
        );
      },
    );
    if (result != null) {
      setState(() {
        curPage = 1;
        _videoItems.clear();
        events.clear();
        startTimes.clear();
        chooseDate = result;
        _currentDate = result.trim().replaceAll('-', '/');
        listRecordDetail(_currentDate);
      });

      print(
        "--------=========================  -------   操作结果:     $result === ${_currentDate}  ",
      );
    }
  }

  // 启动定时器，定时更新时间轴偏移
  void _startTimer() {
    const duration = Duration(seconds: 1);
    // _timer = Timer.periodic(duration, (timer) {
    //   print("定时器运行中... $_fingers...$_isDragging");
    if (_isDragging || _fingers > 1 || _currentCenterSecond >= totalSeconds) {
      print("被阻止了");
      return; // 用户正在拖动，跳过自动滚动
    }
    setState(() {
      print("定时器_currentCenterSecond: $_currentCenterSecond");
      double scrollViewoffset =
          _currentCenterSecond * (scaleFactor - 1) * screenWidth / totalSeconds;
      _scrollController.jumpTo(scrollViewoffset);
      // 每秒钟更新 offsetX 来让时间轴滚动
      double timeStep = screenWidth / (totalSeconds / scaleFactor);
      double showDate =
          scrollViewoffset *
          (totalSeconds / (screenWidth * scaleFactor - screenWidth));

      _textKey.currentState?.updateText("${_formatSeconds(showDate)}");
      playIngtime = "$_currentDate ${_formatSeconds(_currentCenterSecond)}";
    });
  }

  //筛选最接近滚动时间轴的时间
  int? findClosestNumber(int target) {
    print("输出筛选时间: $target ==== $startTimes");
    if (startTimes.isEmpty) return null;
    int closestNum = startTimes.first;
    int minDiff = (closestNum - target).abs();
    for (int num in startTimes.skip(1)) {
      int currentDiff = (num - target).abs();
      if (currentDiff < minDiff) {
        minDiff = currentDiff;
        closestNum = num;
      }
    }
    return closestNum;
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('录像视频', style: TextStyle(fontSize: 20)),
            Text(
              deviceModel.deviceName ?? '',
              style: TextStyle(fontSize: 10, color: ZColor.black_70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 视频预览区域
          GestureDetector(
            child: Container(
              color: Colors.black,
              height: screenWidth / 1.09,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  events.isNotEmpty
                      ? _buildRtcView()
                      : Center(
                          child: Text(
                            "暂无视频内容",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                  Positioned(
                    top: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          playIngtime,
                          style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          events.isEmpty ? "" : " $_rate" + 'kb/s',
                          style: GoogleFonts.notoSans(
                            color: ZColor.color_F5F5F5,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _isPlaying
                      ? Container()
                      : Image.asset(
                          'assets/images/my_icon_play.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        ),
                ],
              ),
            ),
            onTap: () {
              setState(() {
                if (events.isEmpty) {
                  _isPlaying = false;
                  showToast("暂无录像");
                  return;
                }
                if (_isPlaying) {
                  stopPlayRecord();
                } else {
                  startPlayRecord(playIngtime);
                }
                _isPlaying = !_isPlaying;
              });
            },
          ),

          SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _enableMute();
              });
            },
            child: Image.asset(
              isAudioMuted
                  ? "assets/images/record_audio_close.png"
                  : "assets/images/record_audio_open.png",
              width: 20,
              height: 20,
              fit: BoxFit.cover,
            ),
          ),

          SizedBox(height: 30),
          // 日期选择
          GestureDetector(
            onTap: () {
              // 显示日期选择弹窗
              showCalendarDialog(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  chooseDate,
                  style: GoogleFonts.notoSans(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Image.asset(
                  "assets/images/choose_date_arrow.png",
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          mounted
              ?
                // 时间轴区域
                Container(
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
                            scaleFactor = (_initialScaleFactor * currentScale)
                                .clamp(minScale, maxScale);

                            double scrollViewoffset =
                                _currentCenterSecond /
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
                                // computerTime(offset);
                              }
                              if (notification is ScrollStartNotification) {
                                // 滚动开始时
                                // _timer?.cancel();

                                if (_isDragging == false && _fingers == 1) {
                                  _isDragging = true;
                                  stopPlayRecord();
                                  print("滚动开始: ${notification.metrics.pixels}");
                                }
                              }
                              if (notification is ScrollEndNotification) {
                                // 滚动结束时
                                // _startTimer(); // 重新启动定时器

                                if (_isDragging == true && _fingers == 0) {
                                  computerTime(offset);

                                  _isDragging = false;
                                  String startTime =
                                      "$_currentDate ${formatTime(_startPlaySecond.toInt())}";
                                  isStopScroll = true;
                                  _currentCenterSecond = _startPlaySecond;
                                  startPlayRecord(startTime);
                                  print("滚动结束: ${notification.metrics.pixels}");
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
                                  size: Size(double.infinity, 80), // 高度为74
                                  painter: TimeLinePainter(
                                    scaleFactor: scaleFactor,
                                    offsetX: offsetX + screenWidth / 2,
                                    events: events,
                                    totalSeconds: totalSeconds,
                                    itemWidth:
                                        screenWidth * scaleFactor - screenWidth,
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
                        // child: Expanded(
                        child: // 可独立更新的文本组件
                        UpdatableText(
                          key: _textKey,
                          initialText: formatTime(_currentCenterSecond.toInt()),
                        ),
                        // ),
                        top: 62,
                        left: 10,
                        right: 10,
                      ),
                    ],
                  ),
                )
              : Container(),

          // 说明文字
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/icon_fxyr.png",
                  width: 16,
                  height: 16,
                  fit: BoxFit.cover,
                ),
                SizedBox(width: 8),
                Text(
                  '宠物画面变动视频录像（非连续回放录像）',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.7),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //更新时间信息
  void computerTime(double offset) {
    double timeStep = totalSeconds / (screenWidth * scaleFactor - screenWidth);

    _startPlaySecond = offset * timeStep.abs();
    if (_startPlaySecond >= totalSeconds) {
      _startPlaySecond = totalSeconds;
    } else if (_startPlaySecond <= 0) {
      _startPlaySecond = 0;
    }
    _textKey.currentState?.updateText("${_formatSeconds(_startPlaySecond)}");
  }

  // 格式化时间（时:分:秒）
  String formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int sec = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

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
    // 动态计算时间刻度的步长
    double stepInSeconds = calculateStepInSeconds(scaleFactor);
    for (int i = 0; i <= totalSeconds; i += stepInSeconds.toInt()) {
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

  // 根据缩放因子计算时间刻度的步长
  double calculateStepInSeconds(double scaleFactor) {
    if (scaleFactor >= 25) {
      return 60; // 最大缩放倍数下，单位为1秒
    } else if (scaleFactor >= 20 && scaleFactor < 25) {
      return 5; // 缩放倍数为20到30之间，单位为5秒
    } else if (scaleFactor >= 15 && scaleFactor < 20) {
      return 10; // 缩放倍数为15到20之间，单位为10秒
    } else if (scaleFactor >= 10 && scaleFactor < 15) {
      return 300; // 缩放倍数为10到15之间，单位为30秒
    } else if (scaleFactor >= 5 && scaleFactor < 10) {
      return 600; // 缩放倍数为5到10之间，单位为1分钟
    } else {
      return 3600; // 缩放倍数小于5，单位为5分钟
    }
  }
}

// 封装独立的可更新文本组件
class UpdatableText extends StatefulWidget {
  final String initialText;
  final double? fontSize;
  final Color? color;
  final FontWeight? fontWeight;

  const UpdatableText({
    super.key,
    required this.initialText,
    this.fontSize = 12.0,
    this.color = Colors.black,
    this.fontWeight = FontWeight.normal,
  });

  @override
  State<UpdatableText> createState() => _UpdatableTextState();
}

class _UpdatableTextState extends State<UpdatableText> {
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
    // 仅当 _text 变化时，该 Text 才会重建
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
