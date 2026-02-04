import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/app_environment.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 알림 및 백그라운드 서비스 초기화
  await NotificationService.instance.init();
  await BackgroundService.instance.initializeService();
  await NotificationService.instance.requestPermission();

  // 환경 설정 초기화
  // 실제 Backend API 호출 (http://localhost:8000)
  AppEnvironment.init(
    mock: false,
  );

  runApp(
    const ProviderScope(
      child: AutoKtxApp(),
    ),
  );
}
