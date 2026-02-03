/// API 설정 상수
class ApiConfig {
  ApiConfig._();

  /// API 기본 URL (Android 실기기에서 접근 가능하도록 LAN IP 사용)
  static const String baseUrl = 'http://192.168.219.107:8000';

  /// API prefix
  static const String apiPrefix = '/api';

  /// 연결 타임아웃 (초)
  static const int connectTimeoutSeconds = 10;

  /// 응답 수신 타임아웃 (초)
  static const int receiveTimeoutSeconds = 30;

  /// Content-Type 헤더
  static const String contentType = 'application/json';

  /// 인증 엔드포인트
  static const String loginPath = '/api/auth/login';

  /// 열차 조회 엔드포인트
  static const String searchTrainsPath = '/api/trains/search';

  /// 예약 엔드포인트
  static const String reservationPath = '/api/reservation';

  /// 예약 취소 엔드포인트 (뒤에 /{reservation_id} 붙여서 사용)
  static const String cancelReservationPath = '/api/reservation';
}
