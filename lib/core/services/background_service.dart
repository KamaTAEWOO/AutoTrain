import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

/// 백그라운드 서비스 (싱글톤)
///
/// Android에서 Foreground Service를 사용하여 앱이 백그라운드에서도
/// Dart VM을 유지하여 폴링이 중단되지 않도록 한다.
class BackgroundService {
  static final BackgroundService instance = BackgroundService._();

  BackgroundService._();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  /// 서비스 초기화 (앱 시작 시 1회 호출)
  Future<void> initializeService() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        notificationChannelId: 'monitoring_channel',
        initialNotificationTitle: 'Auto KTX',
        initialNotificationContent: '서비스 준비 중...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Android Foreground Service 시작
  Future<void> startService() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
    // 알림 내용 업데이트
    _service.invoke('update', {
      'title': 'Auto KTX',
      'content': '자동 예약 모니터링 중...',
    });
  }

  /// 서비스 중지
  Future<void> stopService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stop');
    }
  }

  /// Foreground 알림 내용 업데이트
  void updateNotification(String text) {
    _service.invoke('update', {
      'title': 'Auto KTX',
      'content': text,
    });
  }

  /// 서비스 실행 중 여부
  Future<bool> get isRunning => _service.isRunning();
}

/// 서비스 시작 콜백 (별도 isolate에서 실행)
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // stop 이벤트 리스닝
  service.on('stop').listen((_) {
    service.stopSelf();
  });

  // 알림 업데이트 이벤트 리스닝
  if (service is AndroidServiceInstance) {
    service.on('update').listen((event) {
      if (event != null) {
        service.setForegroundNotificationInfo(
          title: event['title'] as String? ?? 'Auto KTX',
          content: event['content'] as String? ?? '모니터링 중...',
        );
      }
    });

    // setAsForegroundService 호출로 foreground 모드 유지
    service.setAsForegroundService();
  }
}

/// iOS 백그라운드 콜백
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
