import 'package:flutter_test/flutter_test.dart';
import 'package:auto_ktx/presentation/providers/search_provider.dart';

void main() {
  // ──────────────────────────────────────────────
  // SearchNotifier 테스트
  // ──────────────────────────────────────────────
  group('SearchNotifier', () {
    late SearchNotifier notifier;

    setUp(() {
      notifier = SearchNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('초기 상태가 올바르다', () {
      final state = notifier.debugState;

      expect(state.depStation, '');
      expect(state.arrStation, '');
      expect(state.selectedHour, 9);
      expect(state.selectedMinute, 0);
      expect(state.autoReserve, true);
      expect(state.refreshInterval, 10);
      expect(state.isValid, false);
    });

    group('역 설정', () {
      test('setDepStation이 출발역을 설정한다', () {
        notifier.setDepStation('서울');

        expect(notifier.debugState.depStation, '서울');
      });

      test('setArrStation이 도착역을 설정한다', () {
        notifier.setArrStation('부산');

        expect(notifier.debugState.arrStation, '부산');
      });

      test('출발역과 도착역 모두 설정하면 isValid가 true가 된다', () {
        notifier.setDepStation('서울');
        notifier.setArrStation('부산');

        expect(notifier.debugState.isValid, true);
      });

      test('한쪽만 설정하면 isValid가 false이다', () {
        notifier.setDepStation('서울');

        expect(notifier.debugState.isValid, false);
      });

      test('빈 문자열 설정 시 isValid가 false이다', () {
        notifier.setDepStation('서울');
        notifier.setArrStation('부산');
        notifier.setArrStation('');

        expect(notifier.debugState.isValid, false);
      });
    });

    group('역 교환', () {
      test('swapStations이 출발역과 도착역을 교환한다', () {
        notifier.setDepStation('서울');
        notifier.setArrStation('부산');

        notifier.swapStations();

        expect(notifier.debugState.depStation, '부산');
        expect(notifier.debugState.arrStation, '서울');
      });

      test('한쪽만 설정된 상태에서도 교환이 동작한다', () {
        notifier.setDepStation('서울');

        notifier.swapStations();

        expect(notifier.debugState.depStation, '');
        expect(notifier.debugState.arrStation, '서울');
      });

      test('두 번 교환하면 원래대로 돌아온다', () {
        notifier.setDepStation('서울');
        notifier.setArrStation('부산');

        notifier.swapStations();
        notifier.swapStations();

        expect(notifier.debugState.depStation, '서울');
        expect(notifier.debugState.arrStation, '부산');
      });
    });

    group('날짜/시간 설정', () {
      test('setDate가 선택 날짜를 변경한다', () {
        final newDate = DateTime(2026, 3, 15);
        notifier.setDate(newDate);

        expect(notifier.debugState.selectedDate, newDate);
      });

      test('setTime이 시/분을 변경한다', () {
        notifier.setTime(14, 30);

        expect(notifier.debugState.selectedHour, 14);
        expect(notifier.debugState.selectedMinute, 30);
      });

      test('setTime으로 자정(00:00) 설정이 가능하다', () {
        notifier.setTime(0, 0);

        expect(notifier.debugState.selectedHour, 0);
        expect(notifier.debugState.selectedMinute, 0);
      });

      test('setTime으로 23:59 설정이 가능하다', () {
        notifier.setTime(23, 59);

        expect(notifier.debugState.selectedHour, 23);
        expect(notifier.debugState.selectedMinute, 59);
      });
    });

    group('자동 예약 설정', () {
      test('setAutoReserve가 자동 예약 여부를 변경한다', () {
        notifier.setAutoReserve(false);
        expect(notifier.debugState.autoReserve, false);

        notifier.setAutoReserve(true);
        expect(notifier.debugState.autoReserve, true);
      });

      test('setRefreshInterval이 조회 주기를 변경한다', () {
        notifier.setRefreshInterval(20);

        expect(notifier.debugState.refreshInterval, 20);
      });
    });

    group('toSearchCondition 변환', () {
      test('기본 날짜/시간으로 SearchCondition을 생성한다', () {
        notifier.setDepStation('서울');
        notifier.setArrStation('부산');
        notifier.setDate(DateTime(2026, 2, 5));
        notifier.setTime(9, 0);

        final condition = notifier.debugState.toSearchCondition();

        expect(condition.depStation, '서울');
        expect(condition.arrStation, '부산');
        expect(condition.date, '20260205');
        expect(condition.time, '090000');
        expect(condition.autoReserve, true);
        expect(condition.refreshInterval, 10);
      });

      test('한 자리 월/일에 0이 패딩된다', () {
        notifier.setDepStation('서울');
        notifier.setArrStation('부산');
        notifier.setDate(DateTime(2026, 1, 3));
        notifier.setTime(5, 7);

        final condition = notifier.debugState.toSearchCondition();

        expect(condition.date, '20260103');
        expect(condition.time, '050700');
      });

      test('두 자리 월/일/시/분이 올바르게 포맷된다', () {
        notifier.setDepStation('대전');
        notifier.setArrStation('동대구');
        notifier.setDate(DateTime(2026, 12, 25));
        notifier.setTime(18, 30);

        final condition = notifier.debugState.toSearchCondition();

        expect(condition.date, '20261225');
        expect(condition.time, '183000');
        expect(condition.depStation, '대전');
        expect(condition.arrStation, '동대구');
      });

      test('autoReserve와 refreshInterval이 SearchCondition에 전달된다', () {
        notifier.setDepStation('서울');
        notifier.setArrStation('부산');
        notifier.setAutoReserve(false);
        notifier.setRefreshInterval(25);

        final condition = notifier.debugState.toSearchCondition();

        expect(condition.autoReserve, false);
        expect(condition.refreshInterval, 25);
      });
    });

    group('표시용 포맷', () {
      test('formattedDate가 YYYY.MM.DD 형식을 반환한다', () {
        notifier.setDate(DateTime(2026, 2, 5));

        expect(notifier.debugState.formattedDate, '2026.02.05');
      });

      test('formattedDate에 월/일 패딩이 적용된다', () {
        notifier.setDate(DateTime(2026, 1, 3));

        expect(notifier.debugState.formattedDate, '2026.01.03');
      });

      test('formattedTime이 HH:mm 형식을 반환한다', () {
        notifier.setTime(14, 30);

        expect(notifier.debugState.formattedTime, '14:30');
      });

      test('formattedTime에 시/분 패딩이 적용된다', () {
        notifier.setTime(5, 7);

        expect(notifier.debugState.formattedTime, '05:07');
      });
    });
  });
}
