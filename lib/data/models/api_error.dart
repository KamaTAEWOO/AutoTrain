/// Backend API 에러 응답 모델
///
/// Backend가 반환하는 에러 포맷:
/// ```json
/// {"error": "TYPE", "code": "CATEGORY_NNN", "detail": "메시지"}
/// ```
///
/// FastAPI의 HTTPException은 이를 `detail` 키로 감싸서 반환하므로,
/// 실제 HTTP 응답 본문은 다음과 같을 수 있다:
/// ```json
/// {"detail": {"error": "TYPE", "code": "CATEGORY_NNN", "detail": "메시지"}}
/// ```
class ApiError implements Exception {
  /// 에러 타입 (대문자 SNAKE_CASE, 예: LOGIN_FAILED, SOLD_OUT)
  final String error;

  /// 에러 코드 (카테고리_숫자 3자리, 예: AUTH_001, RESERVE_001)
  final String code;

  /// 사용자에게 표시 가능한 에러 설명 (한국어)
  final String detail;

  /// HTTP 상태 코드
  final int? statusCode;

  const ApiError({
    required this.error,
    required this.code,
    required this.detail,
    this.statusCode,
  });

  /// JSON 응답 본문에서 ApiError를 파싱한다.
  ///
  /// FastAPI의 HTTPException은 에러 정보를 `detail` 키로 감싸서 반환하므로,
  /// 두 가지 형태를 모두 처리한다:
  /// 1. {"error": "...", "code": "...", "detail": "..."}
  /// 2. {"detail": {"error": "...", "code": "...", "detail": "..."}}
  factory ApiError.fromResponseBody(
    dynamic body, {
    int? statusCode,
  }) {
    if (body is Map<String, dynamic>) {
      // FastAPI HTTPException 형태: {"detail": {...}}
      final detailField = body['detail'];
      if (detailField is Map<String, dynamic> &&
          detailField.containsKey('error')) {
        return ApiError(
          error: detailField['error'] as String? ?? 'UNKNOWN',
          code: detailField['code'] as String? ?? 'SYSTEM_001',
          detail: detailField['detail'] as String? ?? '알 수 없는 오류가 발생했습니다',
          statusCode: statusCode,
        );
      }

      // 직접 에러 포맷: {"error": "...", "code": "...", "detail": "..."}
      if (body.containsKey('error') && body.containsKey('code')) {
        return ApiError(
          error: body['error'] as String? ?? 'UNKNOWN',
          code: body['code'] as String? ?? 'SYSTEM_001',
          detail: body['detail'] as String? ?? '알 수 없는 오류가 발생했습니다',
          statusCode: statusCode,
        );
      }

      // detail이 문자열인 경우
      if (detailField is String) {
        return ApiError(
          error: 'API_ERROR',
          code: 'SYSTEM_001',
          detail: detailField,
          statusCode: statusCode,
        );
      }
    }

    return ApiError(
      error: 'UNKNOWN',
      code: 'SYSTEM_001',
      detail: '알 수 없는 오류가 발생했습니다',
      statusCode: statusCode,
    );
  }

  /// 세션 만료 에러인지 확인
  bool get isSessionExpired =>
      error == 'SESSION_EXPIRED' || code == 'AUTH_003';

  /// 로그인 실패 에러인지 확인
  bool get isLoginFailed =>
      error == 'LOGIN_FAILED' || code == 'AUTH_001';

  /// 매진 에러인지 확인
  bool get isSoldOut =>
      error == 'SOLD_OUT' || code == 'RESERVE_001';

  /// 열차 없음 에러인지 확인 (TAGO-korail2 열차번호 불일치 등)
  bool get isNoTrains =>
      error == 'NO_TRAINS' || code == 'SEARCH_002';

  /// 코레일 서버 오류인지 확인
  bool get isServerError =>
      error == 'KORAIL_SERVER_ERROR' ||
      code == 'SYSTEM_002' ||
      code == 'SEARCH_003';

  /// 에러 코드의 카테고리 (AUTH, SEARCH, RESERVE, SYSTEM)
  String get category {
    final parts = code.split('_');
    return parts.isNotEmpty ? parts.first : 'UNKNOWN';
  }

  @override
  String toString() => detail;
}

/// 네트워크 연결 자체의 오류 (서버 미응답, 타임아웃 등)
class NetworkError implements Exception {
  final String message;

  const NetworkError(this.message);

  @override
  String toString() => message;
}
