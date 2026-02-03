import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/train_list_screen.dart';
import 'presentation/screens/my_reservation_screen.dart';

/// 앱 전역 Navigator 키
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// BottomNavigationBar Shell 위젯 (3탭)
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onTabChange: changeTab),
          TrainListScreen(onTabChange: changeTab),
          MyReservationScreen(onTabChange: changeTab),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: '홈',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.train),
            icon: Icon(Icons.train_outlined),
            label: '열차조회',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.confirmation_number),
            icon: Icon(Icons.confirmation_number_outlined),
            label: '내 예약',
          ),
        ],
      ),
    );
  }
}

/// 인증 상태 변경을 GoRouter에 알려주는 ChangeNotifier
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// GoRouter Provider (Riverpod 연동)
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.isLoggedIn;
      final isOnLogin = state.matchedLocation == '/login';

      // 아직 인증 확인 중이면 리다이렉트 없음
      if (authState.isCheckingAuth) return null;

      // 로그인 안 됐으면 → 로그인 화면
      if (!isLoggedIn && !isOnLogin) return '/login';

      // 로그인 됐는데 로그인 화면이면 → 홈
      if (isLoggedIn && isOnLogin) return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainShell(),
      ),
    ],
  );
});
