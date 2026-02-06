import '../models/reservation.dart';
import '../models/train.dart';

/// KTX / SRT 공통 열차 API 인터페이스
abstract class TrainApiService {
  /// 로그인 → (sessionKey, userName)
  Future<({String sessionKey, String userName})> login(
    String id,
    String pw,
  );

  /// 열차 목록 조회 (하루 전체)
  Future<List<Train>> searchTrains(
    String dep,
    String arr,
    String date,
    String time,
  );

  /// 예약
  Future<Reservation> reserve(
    String trainNo,
    String seatType, {
    required String depStation,
    required String arrStation,
    required String date,
    String time,
  });

  /// 내 예약 목록 조회
  Future<List<Reservation>> fetchReservations();

  /// 예약 취소
  Future<Map<String, dynamic>> cancelReservation(String reservationId);

  /// 로그아웃
  void logout();

  /// 세션 활성 여부
  bool get hasSession;

  /// 로그인한 사용자 이름
  String? get userName;
}
