import 'dart:developer' as dev;

import '../models/api_error.dart';
import '../models/train.dart';
import '../models/reservation.dart';
import '../services/api_client.dart';
import '../services/korail_api.dart';

/// 로그인 응답 모델
class LoginResponse {
  final String sessionToken;
  final String expiresAt;
  final String name;
  final String message;

  const LoginResponse({
    required this.sessionToken,
    required this.expiresAt,
    this.name = '',
    required this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      sessionToken: json['session_token'] as String,
      expiresAt: json['expires_at'] as String,
      name: json['name'] as String? ?? '',
      message: json['message'] as String,
    );
  }
}

/// 열차 조회/예약 Repository
///
/// 코레일 서버와 직접 통신하여 열차 조회, 예약 기능을 제공한다.
class TrainRepository {
  final ApiClient _apiClient;
  final KorailApi _korailApi;

  /// 마지막으로 조회된 열차 목록 (예약 시 참조)
  List<Train> _lastSearchedTrains = [];

  TrainRepository({
    ApiClient? apiClient,
    KorailApi? korailApi,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _korailApi = korailApi ?? KorailApi.instance;

  /// 코레일 로그인
  ///
  /// [saveCredentials]가 true이면 자격 증명을 암호화 저장하여
  /// 자동 로그인 및 재로그인에 사용한다.
  Future<LoginResponse> login(
    String id,
    String pw, {
    bool saveCredentials = true,
  }) async {
    try {
      final result = await _korailApi.login(id, pw);

      if (saveCredentials) {
        await _apiClient.saveCredentials(id, pw);
      }

      return LoginResponse(
        sessionToken: result.sessionKey,
        expiresAt: '',
        name: result.userName,
        message: '로그인 성공',
      );
    } on ApiError {
      rethrow;
    } on NetworkError {
      rethrow;
    } catch (e) {
      throw NetworkError('로그인 중 오류가 발생했습니다: $e');
    }
  }

  /// 열차 목록 조회
  Future<List<Train>> searchTrains(
    String dep,
    String arr,
    String date,
    String time,
  ) async {
    try {
      // 세션 만료 시 자동 재로그인
      if (!_korailApi.hasSession) {
        await _tryReLogin();
      }

      final trains = await _korailApi.searchTrains(dep, arr, date, time);
      _lastSearchedTrains = trains;
      _logTrains(dep, arr, date, time, trains);
      return trains;
    } on ApiError catch (e) {
      // 세션 만료 시 재로그인 후 재시도
      if (e.isSessionExpired) {
        final reLoggedIn = await _tryReLogin();
        if (reLoggedIn) {
          final trains = await _korailApi.searchTrains(dep, arr, date, time);
          _lastSearchedTrains = trains;
          _logTrains(dep, arr, date, time, trains);
          return trains;
        }
      }
      rethrow;
    } on NetworkError {
      rethrow;
    }
  }

  /// 예약 시도
  Future<Reservation> reserve(
    String trainNo,
    String seatType, {
    required String depStation,
    required String arrStation,
    required String date,
    String time = '000000',
  }) async {
    try {
      if (!_korailApi.hasSession) {
        await _tryReLogin();
      }

      return await _korailApi.reserve(
        trainNo,
        seatType,
        depStation: depStation,
        arrStation: arrStation,
        date: date,
        time: time,
      );
    } on ApiError catch (e) {
      if (e.isSessionExpired) {
        final reLoggedIn = await _tryReLogin();
        if (reLoggedIn) {
          return await _korailApi.reserve(
            trainNo,
            seatType,
            depStation: depStation,
            arrStation: arrStation,
            date: date,
            time: time,
          );
        }
      }
      rethrow;
    } on NetworkError {
      rethrow;
    }
  }

  /// 내 예약 목록 조회
  Future<List<Reservation>> fetchReservations() async {
    try {
      if (!_korailApi.hasSession) {
        await _tryReLogin();
      }

      return await _korailApi.fetchReservations();
    } on ApiError catch (e) {
      if (e.isSessionExpired) {
        final reLoggedIn = await _tryReLogin();
        if (reLoggedIn) {
          return await _korailApi.fetchReservations();
        }
      }
      rethrow;
    } on NetworkError {
      rethrow;
    }
  }

  /// 예약 취소
  Future<Map<String, dynamic>> cancelReservation(String reservationId) async {
    try {
      if (!_korailApi.hasSession) {
        await _tryReLogin();
      }

      return await _korailApi.cancelReservation(reservationId);
    } on ApiError catch (e) {
      if (e.isSessionExpired) {
        final reLoggedIn = await _tryReLogin();
        if (reLoggedIn) {
          return await _korailApi.cancelReservation(reservationId);
        }
      }
      rethrow;
    } on NetworkError {
      rethrow;
    }
  }

  /// 마지막 조회된 열차 목록
  List<Train> get lastSearchedTrains => _lastSearchedTrains;

  /// 저장된 자격 증명으로 재로그인 시도
  Future<bool> _tryReLogin() async {
    final creds = await _apiClient.readSavedCredentials();
    if (creds == null) return false;

    try {
      await _korailApi.login(creds.id, creds.pw);
      dev.log('자동 재로그인 성공', name: 'TrainRepository');
      return true;
    } catch (e) {
      dev.log('자동 재로그인 실패: $e', name: 'TrainRepository');
      return false;
    }
  }

  /// 열차 조회 결과 로그 출력
  void _logTrains(
    String dep,
    String arr,
    String date,
    String time,
    List<Train> trains,
  ) {
    final buf = StringBuffer()
      ..writeln('═══ [KorailApi] 열차 조회 결과 ═══')
      ..writeln('  $dep → $arr | $date $time')
      ..writeln('  총 ${trains.length}건')
      ..writeln('  ┌──────┬──────────┬───────┬───────┬──────────┬────────┬────────┐')
      ..writeln('  │ 번호 │ 열차종류   │ 출발  │ 도착  │   운임    │ 일반실 │  특실  │')
      ..writeln('  ├──────┼──────────┼───────┼───────┼──────────┼────────┼────────┤');
    for (final t in trains) {
      final charge = t.formattedCharge ?? '-';
      final gen = t.generalSeats == null ? '-' : (t.generalSeats! ? 'O' : 'X');
      final spe = t.specialSeats == null ? '-' : (t.specialSeats! ? 'O' : 'X');
      buf.writeln(
        '  │ ${t.trainNo.padRight(4)} '
        '│ ${t.trainType.padRight(8)} '
        '│ ${t.depTime} '
        '│ ${t.arrTime} '
        '│ ${charge.padLeft(8)} '
        '│   $gen    '
        '│   $spe    │',
      );
    }
    buf.writeln('  └──────┴──────────┴───────┴───────┴──────────┴────────┴────────┘');
    dev.log(buf.toString(), name: 'TrainRepository');
  }
}
