import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import '../../core/constants/api_config.dart';
import '../models/api_error.dart';
import '../models/train.dart';
import '../models/reservation.dart';
import '../services/api_client.dart';

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
/// Backend API를 통해 열차 조회, 예약 기능을 제공한다.
class TrainRepository {
  final ApiClient _apiClient;

  /// 마지막으로 조회된 열차 목록 (예약 시 참조)
  List<Train> _lastSearchedTrains = [];

  TrainRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  /// 코레일 로그인
  ///
  /// [saveCredentials]가 true이면 자격 증명을 암호화 저장하여
  /// 자동 로그인 및 401 재로그인에 사용한다.
  Future<LoginResponse> login(
    String id,
    String pw, {
    bool saveCredentials = true,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.loginPath,
        data: {'korail_id': id, 'korail_pw': pw},
      );
      final loginResponse = LoginResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      _apiClient.setSessionToken(loginResponse.sessionToken);
      if (saveCredentials) {
        await _apiClient.saveCredentials(id, pw);
      }
      return loginResponse;
    } on DioException catch (e) {
      throw _handleError(e);
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
      final response = await _apiClient.dio.get(
        ApiConfig.searchTrainsPath,
        queryParameters: {
          'dep': dep,
          'arr': arr,
          'date': date,
          'time': time,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final trainsList = data['trains'] as List<dynamic>;
      final trains = trainsList
          .map((json) => Train.fromJson(json as Map<String, dynamic>))
          .toList();
      _lastSearchedTrains = trains;
      _logTrains(dep, arr, date, time, trains);
      return trains;
    } on DioException catch (e) {
      throw _handleError(e);
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
      final response = await _apiClient.dio.post(
        ApiConfig.reservationPath,
        data: {
          'train_no': trainNo,
          'seat_type': seatType,
          'dep_station': depStation,
          'arr_station': arrStation,
          'date': date,
          'time': time,
        },
      );
      return Reservation.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 내 예약 목록 조회
  Future<List<Reservation>> fetchReservations() async {
    try {
      final response = await _apiClient.dio.get(
        ApiConfig.reservationPath,
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['reservations'] as List<dynamic>;
      return list
          .map((json) => Reservation.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 예약 취소
  Future<Map<String, dynamic>> cancelReservation(String reservationId) async {
    try {
      final response = await _apiClient.dio.delete(
        '${ApiConfig.cancelReservationPath}/$reservationId',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 마지막 조회된 열차 목록
  List<Train> get lastSearchedTrains => _lastSearchedTrains;

  /// 열차 조회 결과 로그 출력
  void _logTrains(
    String dep,
    String arr,
    String date,
    String time,
    List<Train> trains,
  ) {
    final buf = StringBuffer()
      ..writeln('═══ [API] 열차 조회 결과 ═══')
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

  /// DioException을 구조화된 에러로 변환
  Exception _handleError(DioException e) {
    final response = e.response;
    if (response != null) {
      return ApiError.fromResponseBody(
        response.data,
        statusCode: response.statusCode,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkError('서버 연결 시간이 초과되었습니다');
      case DioExceptionType.receiveTimeout:
        return const NetworkError('응답 대기 시간이 초과되었습니다');
      case DioExceptionType.connectionError:
        return const NetworkError('서버에 연결할 수 없습니다');
      default:
        return NetworkError(e.message ?? '네트워크 오류가 발생했습니다');
    }
  }
}
