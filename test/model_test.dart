import 'package:flutter_test/flutter_test.dart';
import 'package:auto_ktx/data/models/train.dart';
import 'package:auto_ktx/data/models/reservation.dart';
import 'package:auto_ktx/data/models/api_error.dart';

void main() {
  // ──────────────────────────────────────────────
  // Train 모델 테스트
  // ──────────────────────────────────────────────
  group('Train model', () {
    final sampleJson = {
      'train_no': 'KTX-101',
      'train_type': 'KTX',
      'dep_station': '서울',
      'arr_station': '부산',
      'dep_time': '09:00',
      'arr_time': '11:30',
      'general_seats': true,
      'special_seats': false,
      'adult_charge': null,
    };

    test('fromJson이 올바르게 파싱한다', () {
      final train = Train.fromJson(sampleJson);

      expect(train.trainNo, 'KTX-101');
      expect(train.trainType, 'KTX');
      expect(train.depStation, '서울');
      expect(train.arrStation, '부산');
      expect(train.depTime, '09:00');
      expect(train.arrTime, '11:30');
      expect(train.generalSeats, true);
      expect(train.specialSeats, false);
    });

    test('toJson이 올바르게 직렬화한다', () {
      final train = Train.fromJson(sampleJson);
      final json = train.toJson();

      expect(json['train_no'], 'KTX-101');
      expect(json['train_type'], 'KTX');
      expect(json['dep_station'], '서울');
      expect(json['arr_station'], '부산');
      expect(json['dep_time'], '09:00');
      expect(json['arr_time'], '11:30');
      expect(json['general_seats'], true);
      expect(json['special_seats'], false);
    });

    test('fromJson -> toJson 라운드트립이 동일하다', () {
      final train = Train.fromJson(sampleJson);
      final roundTripped = train.toJson();

      expect(roundTripped, equals(sampleJson));
    });

    test('좌석이 모두 없는 열차도 정상 파싱된다', () {
      final noSeatsJson = Map<String, dynamic>.from(sampleJson);
      noSeatsJson['general_seats'] = false;
      noSeatsJson['special_seats'] = false;

      final train = Train.fromJson(noSeatsJson);
      expect(train.generalSeats, false);
      expect(train.specialSeats, false);
    });

    test('copyWith이 지정한 필드만 변경한다', () {
      final train = Train.fromJson(sampleJson);
      final copied = train.copyWith(generalSeats: false, depStation: '광명');

      expect(copied.generalSeats, false);
      expect(copied.depStation, '광명');
      // 나머지 필드는 원본과 동일
      expect(copied.trainNo, train.trainNo);
      expect(copied.trainType, train.trainType);
      expect(copied.arrStation, train.arrStation);
      expect(copied.depTime, train.depTime);
      expect(copied.arrTime, train.arrTime);
      expect(copied.specialSeats, train.specialSeats);
    });

    test('toString이 의미 있는 문자열을 반환한다', () {
      final train = Train.fromJson(sampleJson);
      final str = train.toString();

      expect(str, contains('KTX-101'));
      expect(str, contains('서울'));
      expect(str, contains('부산'));
    });
  });

  // ──────────────────────────────────────────────
  // Reservation 모델 테스트
  // ──────────────────────────────────────────────
  group('Reservation model', () {
    final sampleTrainJson = {
      'train_no': 'KTX-103',
      'train_type': 'KTX-산천',
      'dep_station': '서울',
      'arr_station': '동대구',
      'dep_time': '10:00',
      'arr_time': '12:00',
      'general_seats': true,
      'special_seats': true,
    };

    final sampleReservationJson = {
      'reservation_id': 'R20260202ABC',
      'status': 'success',
      'train': sampleTrainJson,
      'message': '예약 성공. 10분 내 결제 필요',
      'reserved_at': '2026-02-02T09:00:00.000',
    };

    test('fromJson이 올바르게 파싱한다', () {
      final reservation = Reservation.fromJson(sampleReservationJson);

      expect(reservation.reservationId, 'R20260202ABC');
      expect(reservation.status, 'success');
      expect(reservation.train.trainNo, 'KTX-103');
      expect(reservation.train.trainType, 'KTX-산천');
      expect(reservation.message, '예약 성공. 10분 내 결제 필요');
      expect(reservation.reservedAt, DateTime.parse('2026-02-02T09:00:00.000'));
    });

    test('toJson이 올바르게 직렬화한다', () {
      final reservation = Reservation.fromJson(sampleReservationJson);
      final json = reservation.toJson();

      expect(json['reservation_id'], 'R20260202ABC');
      expect(json['status'], 'success');
      expect(json['message'], '예약 성공. 10분 내 결제 필요');
      expect(json['train'], isA<Map<String, dynamic>>());
      expect(json['train']['train_no'], 'KTX-103');
      expect(json['reserved_at'], isA<String>());
    });

    test('fromJson -> toJson 라운드트립 시 핵심 필드가 보존된다', () {
      final reservation = Reservation.fromJson(sampleReservationJson);
      final json = reservation.toJson();
      final roundTripped = Reservation.fromJson(json);

      expect(roundTripped.reservationId, reservation.reservationId);
      expect(roundTripped.status, reservation.status);
      expect(roundTripped.message, reservation.message);
      expect(roundTripped.train.trainNo, reservation.train.trainNo);
      expect(roundTripped.train.depStation, reservation.train.depStation);
      expect(roundTripped.train.arrStation, reservation.train.arrStation);
    });

    test('isSuccess가 status == "success"일 때 true를 반환한다', () {
      final reservation = Reservation.fromJson(sampleReservationJson);
      expect(reservation.isSuccess, true);
      expect(reservation.isFailure, false);
    });

    test('isFailure가 status == "failure"일 때 true를 반환한다', () {
      final failedJson = Map<String, dynamic>.from(sampleReservationJson);
      failedJson['status'] = 'failure';

      final reservation = Reservation.fromJson(failedJson);
      expect(reservation.isFailure, true);
      expect(reservation.isSuccess, false);
    });

    test('copyWith이 지정한 필드만 변경한다', () {
      final reservation = Reservation.fromJson(sampleReservationJson);
      final copied = reservation.copyWith(status: 'failure', message: '매진');

      expect(copied.status, 'failure');
      expect(copied.message, '매진');
      expect(copied.reservationId, reservation.reservationId);
      expect(copied.train.trainNo, reservation.train.trainNo);
    });

    test('toString이 의미 있는 문자열을 반환한다', () {
      final reservation = Reservation.fromJson(sampleReservationJson);
      final str = reservation.toString();

      expect(str, contains('R20260202ABC'));
      expect(str, contains('success'));
      expect(str, contains('KTX-103'));
    });
  });

  // ──────────────────────────────────────────────
  // ApiError 모델 테스트
  // ──────────────────────────────────────────────
  group('ApiError model', () {
    group('fromResponseBody 파싱', () {
      test('직접 에러 포맷을 올바르게 파싱한다', () {
        final body = {
          'error': 'LOGIN_FAILED',
          'code': 'AUTH_001',
          'detail': '아이디 또는 비밀번호가 올바르지 않습니다',
        };

        final error = ApiError.fromResponseBody(body, statusCode: 401);

        expect(error.error, 'LOGIN_FAILED');
        expect(error.code, 'AUTH_001');
        expect(error.detail, '아이디 또는 비밀번호가 올바르지 않습니다');
        expect(error.statusCode, 401);
      });

      test('FastAPI HTTPException 포맷 (detail 래핑)을 올바르게 파싱한다', () {
        final body = {
          'detail': {
            'error': 'SOLD_OUT',
            'code': 'RESERVE_001',
            'detail': '매진되었습니다',
          },
        };

        final error = ApiError.fromResponseBody(body, statusCode: 409);

        expect(error.error, 'SOLD_OUT');
        expect(error.code, 'RESERVE_001');
        expect(error.detail, '매진되었습니다');
        expect(error.statusCode, 409);
      });

      test('detail이 문자열인 경우 API_ERROR로 처리한다', () {
        final body = {
          'detail': 'Not Found',
        };

        final error = ApiError.fromResponseBody(body, statusCode: 404);

        expect(error.error, 'API_ERROR');
        expect(error.code, 'SYSTEM_001');
        expect(error.detail, 'Not Found');
        expect(error.statusCode, 404);
      });

      test('알 수 없는 포맷은 UNKNOWN으로 처리한다', () {
        final error = ApiError.fromResponseBody('random string', statusCode: 500);

        expect(error.error, 'UNKNOWN');
        expect(error.code, 'SYSTEM_001');
        expect(error.detail, '알 수 없는 오류가 발생했습니다');
        expect(error.statusCode, 500);
      });

      test('null 필드가 있는 직접 에러 포맷도 기본값이 적용된다', () {
        final body = {
          'error': null,
          'code': null,
          'detail': null,
        };

        final error = ApiError.fromResponseBody(body);

        // error와 code가 null이므로 containsKey('error')는 true이지만 값이 null
        expect(error.error, 'UNKNOWN');
        expect(error.code, 'SYSTEM_001');
        expect(error.detail, '알 수 없는 오류가 발생했습니다');
      });

      test('statusCode 없이도 파싱이 가능하다', () {
        final body = {
          'error': 'SESSION_EXPIRED',
          'code': 'AUTH_003',
          'detail': '세션이 만료되었습니다',
        };

        final error = ApiError.fromResponseBody(body);

        expect(error.error, 'SESSION_EXPIRED');
        expect(error.statusCode, isNull);
      });
    });

    group('편의 getter', () {
      test('isSessionExpired - error가 SESSION_EXPIRED이면 true', () {
        const error = ApiError(
          error: 'SESSION_EXPIRED',
          code: 'AUTH_003',
          detail: '세션 만료',
        );
        expect(error.isSessionExpired, true);
        expect(error.isLoginFailed, false);
        expect(error.isSoldOut, false);
      });

      test('isSessionExpired - code가 AUTH_003이면 true', () {
        const error = ApiError(
          error: 'SOME_ERROR',
          code: 'AUTH_003',
          detail: '세션 만료',
        );
        expect(error.isSessionExpired, true);
      });

      test('isLoginFailed - error가 LOGIN_FAILED이면 true', () {
        const error = ApiError(
          error: 'LOGIN_FAILED',
          code: 'AUTH_001',
          detail: '로그인 실패',
        );
        expect(error.isLoginFailed, true);
        expect(error.isSessionExpired, false);
      });

      test('isLoginFailed - code가 AUTH_001이면 true', () {
        const error = ApiError(
          error: 'SOME_ERROR',
          code: 'AUTH_001',
          detail: '로그인 실패',
        );
        expect(error.isLoginFailed, true);
      });

      test('isSoldOut - error가 SOLD_OUT이면 true', () {
        const error = ApiError(
          error: 'SOLD_OUT',
          code: 'RESERVE_001',
          detail: '매진',
        );
        expect(error.isSoldOut, true);
        expect(error.isSessionExpired, false);
        expect(error.isLoginFailed, false);
      });

      test('isSoldOut - code가 RESERVE_001이면 true', () {
        const error = ApiError(
          error: 'SOME_ERROR',
          code: 'RESERVE_001',
          detail: '매진',
        );
        expect(error.isSoldOut, true);
      });

      test('isServerError - error가 KORAIL_SERVER_ERROR이면 true', () {
        const error = ApiError(
          error: 'KORAIL_SERVER_ERROR',
          code: 'SEARCH_003',
          detail: '서버 오류',
        );
        expect(error.isServerError, true);
      });

      test('isServerError - code가 SYSTEM_002이면 true', () {
        const error = ApiError(
          error: 'SOME_ERROR',
          code: 'SYSTEM_002',
          detail: '서버 오류',
        );
        expect(error.isServerError, true);
      });

      test('isServerError - code가 SEARCH_003이면 true', () {
        const error = ApiError(
          error: 'SOME_ERROR',
          code: 'SEARCH_003',
          detail: '서버 오류',
        );
        expect(error.isServerError, true);
      });

      test('category가 코드의 카테고리 부분을 반환한다', () {
        const authError = ApiError(
          error: 'LOGIN_FAILED',
          code: 'AUTH_001',
          detail: '로그인 실패',
        );
        expect(authError.category, 'AUTH');

        const searchError = ApiError(
          error: 'NO_TRAINS',
          code: 'SEARCH_002',
          detail: '열차 없음',
        );
        expect(searchError.category, 'SEARCH');

        const reserveError = ApiError(
          error: 'SOLD_OUT',
          code: 'RESERVE_001',
          detail: '매진',
        );
        expect(reserveError.category, 'RESERVE');

        const systemError = ApiError(
          error: 'INTERNAL_ERROR',
          code: 'SYSTEM_001',
          detail: '서버 오류',
        );
        expect(systemError.category, 'SYSTEM');
      });

      test('모든 getter가 false인 일반 에러', () {
        const error = ApiError(
          error: 'SOMETHING_ELSE',
          code: 'OTHER_001',
          detail: '기타 오류',
        );
        expect(error.isSessionExpired, false);
        expect(error.isLoginFailed, false);
        expect(error.isSoldOut, false);
        expect(error.isServerError, false);
      });
    });

    test('toString이 detail을 반환한다', () {
      const error = ApiError(
        error: 'SOLD_OUT',
        code: 'RESERVE_001',
        detail: '매진되었습니다',
      );
      expect(error.toString(), '매진되었습니다');
    });

    test('ApiError는 Exception을 구현한다', () {
      const error = ApiError(
        error: 'TEST',
        code: 'TEST_001',
        detail: '테스트',
      );
      expect(error, isA<Exception>());
    });
  });

  // ──────────────────────────────────────────────
  // NetworkError 모델 테스트
  // ──────────────────────────────────────────────
  group('NetworkError model', () {
    test('메시지가 올바르게 설정된다', () {
      const error = NetworkError('서버에 연결할 수 없습니다');
      expect(error.message, '서버에 연결할 수 없습니다');
    });

    test('toString이 메시지를 반환한다', () {
      const error = NetworkError('타임아웃');
      expect(error.toString(), '타임아웃');
    });

    test('NetworkError는 Exception을 구현한다', () {
      const error = NetworkError('테스트');
      expect(error, isA<Exception>());
    });
  });
}
