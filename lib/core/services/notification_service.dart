import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 로컬 알림 서비스 (싱글톤)
///
/// 예약 성공 등 주요 이벤트를 로컬 푸시 알림으로 표시한다.
class NotificationService {
  static final NotificationService instance = NotificationService._();

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'reservation_channel';
  static const _channelName = '예약 알림';
  static const _channelDescription = 'KTX 예약 성공/실패 알림';

  /// 백그라운드 모니터링 서비스용 채널
  static const monitoringChannelId = 'monitoring_channel';
  static const _monitoringChannelName = '모니터링';
  static const _monitoringChannelDescription = '자동 예약 모니터링 상태 표시';

  /// 알림 서비스 초기화
  Future<void> init() async {
    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정 — 권한은 requestPermission()에서 명시적으로 요청
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    // Android 알림 채널 생성
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // 예약 알림 채널
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // 모니터링 서비스 알림 채널 (foreground service용)
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        monitoringChannelId,
        _monitoringChannelName,
        description: _monitoringChannelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// 알림 권한 요청 (Android 13+ / iOS)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// 예약 성공 알림 표시
  Future<void> showReservationSuccess({
    required String trainNo,
    required String reservationId,
    String? depStation,
    String? arrStation,
  }) async {
    final route = depStation != null && arrStation != null
        ? '$depStation → $arrStation'
        : '';
    final body = '열차 $trainNo $route\n예약번호: $reservationId';

    await _plugin.show(
      0,
      '🚄 KTX 예약 성공!',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
