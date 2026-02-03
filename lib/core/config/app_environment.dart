/// 앱 환경 설정
///
/// Mock 모드 토글, API Base URL 등 환경별로 달라지는 설정을 관리한다.
/// 앱 시작 시 [AppEnvironment.init]을 호출하여 초기화하거나,
/// 기본값(Mock 모드 활성)을 사용한다.
class AppEnvironment {
  AppEnvironment._();

  /// Mock 모드 사용 여부
  /// - true: Backend 없이 더미 데이터로 동작 (개발/테스트용)
  /// - false: 실제 Backend API 호출
  static bool useMock = false;

  /// API Base URL (기본값: http://localhost:8000)
  static String baseUrl = 'http://localhost:8000';

  /// 환경 초기화
  ///
  /// main.dart에서 앱 시작 전에 호출하여 환경을 설정한다.
  /// [mock]이 false이면 실제 Backend API를 호출한다.
  static void init({
    bool mock = true,
    String? apiBaseUrl,
  }) {
    useMock = mock;
    if (apiBaseUrl != null) {
      baseUrl = apiBaseUrl;
    }
  }
}
