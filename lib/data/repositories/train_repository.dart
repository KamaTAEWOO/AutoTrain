import 'dart:developer' as dev;

import '../../core/constants/rail_type.dart';
import '../models/api_error.dart';
import '../models/train.dart';
import '../models/reservation.dart';
import '../services/api_client.dart';
import '../services/korail_api.dart';
import '../services/srt_api.dart';
import '../services/train_api_service.dart';

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
/// KTX 또는 SRT 서버와 직접 통신하여 열차 조회, 예약 기능을 제공한다.
class TrainRepository {
  final ApiClient _apiClient;
  final TrainApiService _api;
  final RailType railType;

  /// 마지막으로 조회된 열차 목록 (예약 시 참조)
  List<Train> _lastSearchedTrains = [];

  TrainRepository({
    ApiClient? apiClient,
    this.railType = RailType.ktx,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _api = railType == RailType.ktx
            ? KorailApi.instance
            : SrtApi.instance;

  /// 로그인
  Future<LoginResponse> login(
    String id,
    String pw, {
    bool saveCredentials = true,
  }) async {
    try {
      final result = await _api.login(id, pw);

      if (saveCredentials) {
        await _apiClient.saveCredentials(id, pw, railType: railType);
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
      if (!_api.hasSession) {
        await _tryReLogin();
      }

      final trains = await _api.searchTrains(dep, arr, date, time);
      _lastSearchedTrains = trains;
      _logTrains(dep, arr, date, time, trains);
      return trains;
    } on ApiError catch (e) {
      if (e.isSessionExpired) {
        final reLoggedIn = await _tryReLogin();
        if (reLoggedIn) {
          final trains = await _api.searchTrains(dep, arr, date, time);
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
      if (!_api.hasSession) {
        await _tryReLogin();
      }

      return await _api.reserve(
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
          return await _api.reserve(
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
      if (!_api.hasSession) {
        await _tryReLogin();
      }

      return await _api.fetchReservations();
    } on ApiError catch (e) {
      if (e.isSessionExpired) {
        final reLoggedIn = await _tryReLogin();
        if (reLoggedIn) {
          return await _api.fetchReservations();
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
      if (!_api.hasSession) {
        await _tryReLogin();
      }

      return await _api.cancelReservation(reservationId);
    } on ApiError catch (e) {
      if (e.isSessionExpired) {
        final reLoggedIn = await _tryReLogin();
        if (reLoggedIn) {
          return await _api.cancelReservation(reservationId);
        }
      }
      rethrow;
    } on NetworkError {
      rethrow;
    }
  }

  /// API 서버 로그아웃 (쿠키/세션 정리)
  void logout() {
    _api.logout();
  }

  /// 마지막 조회된 열차 목록
  List<Train> get lastSearchedTrains => _lastSearchedTrains;

  /// 저장된 자격 증명으로 재로그인 시도
  Future<bool> _tryReLogin() async {
    final creds = await _apiClient.readSavedCredentials(railType: railType);
    if (creds == null) return false;

    try {
      await _api.login(creds.id, creds.pw);
      dev.log('자동 재로그인 성공 (${railType.displayName})',
          name: 'TrainRepository');
      return true;
    } catch (e) {
      dev.log('자동 재로그인 실패 (${railType.displayName}): $e',
          name: 'TrainRepository');
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
    final label = railType.displayName;
    final buf = StringBuffer()
      ..writeln('═══ [$label] 열차 조회 결과 ═══')
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
