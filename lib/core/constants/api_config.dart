/// API 설정 상수
///
/// ⚠️ 주의: 현재 이 클래스는 사용되지 않습니다.
/// 프로젝트는 Python 백엔드 없이 KorailApi(korail_api.dart)를 통해
/// 코레일 서버를 직접 호출합니다.
///
/// 이 파일은 향후 백엔드 추가 시 또는 Mock 모드 테스트를 위해 유지됩니다.
class ApiConfig {
  ApiConfig._();

  /// API 기본 URL
  /// ⚠️ 실제 사용 시 환경 변수나 AppEnvironment.baseUrl을 사용하세요
  /// (하드코딩된 IP 주소는 보안상 권장하지 않음)
  static const String baseUrl = 'http://localhost:8000';

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
