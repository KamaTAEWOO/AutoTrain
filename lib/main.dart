import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/app_environment.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
