import 'package:flutter_test/flutter_test.dart';
import 'package:auto_ktx/core/constants/app_enums.dart';
import 'package:auto_ktx/data/models/train.dart';
import 'package:auto_ktx/presentation/providers/monitor_provider.dart';

Train _train({bool? general, bool? special}) => Train(
      trainNo: '001',
      trainType: 'KTX',
      depStation: '서울',
      arrStation: '부산',
      depTime: '10:00',
      arrTime: '12:30',
      generalSeats: general,
      specialSeats: special,
    );

void main() {
  // ──────────────────────────────────────────────
  // reserveSeatCode: 사용자 선택 → 예약 API 코드
  // ──────────────────────────────────────────────
  group('reserveSeatCode', () {
    test('일반실 선택 → general', () {
      expect(reserveSeatCode(SeatType.general), 'general');
    });

    test('특실 선택 → special', () {
      expect(reserveSeatCode(SeatType.special), 'special');
    });
  });

  // ──────────────────────────────────────────────
  // hasDesiredSeat: 선택한 등급 기준 빈자리 판정
  // ──────────────────────────────────────────────
  group('hasDesiredSeat', () {
    test('특실 선택 + 일반석·특실 모두 있음 → 트리거 (회귀)', () {
      // 과거 버그: 일반석이 있으면 특실 선택을 무시하고 일반석을 예약했다.
      // 이제는 특실 좌석이 있으므로 트리거되고, 예약도 특실로 나가야 한다.
      expect(
        hasDesiredSeat(_train(general: true, special: true), SeatType.special),
        true,
      );
    });

    test('특실 선택 + 일반석만 있음 → 트리거 안 함 (회귀)', () {
      // 과거 버그: 일반석만 있어도 트리거되어 일반석이 예약됐다.
      expect(
        hasDesiredSeat(_train(general: true, special: false), SeatType.special),
        false,
      );
    });

    test('특실 선택 + 특실만 있음 → 트리거', () {
      expect(
        hasDesiredSeat(_train(general: false, special: true), SeatType.special),
        true,
      );
    });

    test('일반실 선택 + 일반석 있음 → 트리거', () {
      expect(
        hasDesiredSeat(_train(general: true, special: false), SeatType.general),
        true,
      );
    });

    test('일반실 선택 + 특실만 있음 → 트리거 안 함', () {
      expect(
        hasDesiredSeat(_train(general: false, special: true), SeatType.general),
        false,
      );
    });

    test('좌석 정보 둘 다 미확인(null) → 일단 트리거', () {
      expect(
        hasDesiredSeat(_train(general: null, special: null), SeatType.special),
        true,
      );
      expect(
        hasDesiredSeat(_train(general: null, special: null), SeatType.general),
        true,
      );
    });
  });
}
