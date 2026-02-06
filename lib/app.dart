import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'router.dart';

/// KTX / SRT 자동 예약 앱 루트 위젯
class AutoKtxApp extends ConsumerWidget {
  const AutoKtxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authProvider);
    final railType = authState.railType;

    return MaterialApp.router(
      title: railType.appBarTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(railType: railType),
      routerConfig: router,
    );
  }
}
