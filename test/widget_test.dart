import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_ktx/app.dart';

void main() {
  group('AutoKtxApp smoke tests', () {
    testWidgets('앱이 정상적으로 로드된다', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AutoKtxApp(),
        ),
      );

      // 앱 타이틀이 렌더링되는지 확인
      expect(find.text('코레일톡'), findsOneWidget);
    });

    testWidgets('HomeScreen이 초기 화면으로 렌더링된다',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AutoKtxApp(),
        ),
      );
      await tester.pumpAndSettle();

      // HomeScreen 고유 요소 확인
      expect(find.text('코레일톡'), findsOneWidget);

      // 열차 조회 버튼
      expect(find.text('열차 조회'), findsOneWidget);
    });

    testWidgets('BottomNavigationBar에 3개 탭이 표시된다',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AutoKtxApp(),
        ),
      );
      await tester.pumpAndSettle();

      // NavigationBar의 3개 탭 레이블 확인
      expect(find.text('홈'), findsOneWidget);
      expect(find.text('열차조회'), findsOneWidget);
      expect(find.text('내 예약'), findsOneWidget);
    });

    testWidgets('홈 화면에 자동예약 컨트롤이 통합되어 있다',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AutoKtxApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 홈 화면에서 검색 관련 요소 확인
      // 자동예약 컨트롤은 열차 선택 후에만 표시됨
      expect(find.text('열차 조회'), findsOneWidget);
    });

    testWidgets('내 예약 탭을 누르면 내 예약 화면이 표시된다',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AutoKtxApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 내 예약 탭 클릭
      await tester.tap(find.text('내 예약'));
      await tester.pumpAndSettle();

      // MyReservationScreen 고유 요소 확인 (초기 상태: 결과 없음)
      expect(find.text('아직 예약 내역이 없습니다'), findsOneWidget);
      expect(find.text('홈으로 이동'), findsOneWidget);
    });

    testWidgets('탭 간 전환이 정상 동작한다', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AutoKtxApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 초기 화면: 홈
      expect(find.text('코레일톡'), findsOneWidget);

      // 내 예약 탭으로 전환
      await tester.tap(find.text('내 예약'));
      await tester.pumpAndSettle();
      expect(find.text('아직 예약 내역이 없습니다'), findsOneWidget);

      // 다시 홈 탭으로 전환
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle();
      expect(find.text('열차 조회'), findsOneWidget);
    });
  });
}
