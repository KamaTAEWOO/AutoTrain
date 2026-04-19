/// 코레일 API 상수
class KorailConstants {
  KorailConstants._();

  // ── 서버 ──
  static const String baseUrl = 'https://smart.letskorail.com:443';

  // ── 엔드포인트 ──
  static const String codeUrl =
      '/classes/com.korail.mobile.common.code.do';
  static const String loginUrl =
      '/classes/com.korail.mobile.login.Login';
  static const String scheduleUrl =
      '/classes/com.korail.mobile.seatMovie.ScheduleView';
  static const String reservationUrl =
      '/classes/com.korail.mobile.certification.TicketReservation';
  static const String reservationListUrl =
      '/classes/com.korail.mobile.reservation.ReservationView';
  static const String cancelUrl =
      '/classes/com.korail.mobile.reservationCancel.ReservationCancelChk';

  // ── 디바이스 / 버전 ──
  // dhfhfk/korail2 bypassDynapath 브랜치 기준 — Dynapath 우회에 필요한 최신 값.
  // DEVICE_MODEL(SM-S928N)과 UA의 기기 모델이 일치해야 토큰 검증 통과.
  static const String device = 'AD';
  static const String version = '250601002';
  static const String loginVersion = '250601002';

  // ── 고정 인증 키 / 메뉴 ID ──
  static const String staticKey = 'korail1234567890';
  static const String menuId = '11';

  // ── User-Agent ──
  // Galaxy S24 Ultra (SM-S928N) / Android 13 — Dynapath 토큰 payload의
  // dm(DEVICE_MODEL), os, st, sv 필드와 정합성 유지
  static const String userAgent =
      'Dalvik/2.1.0 (Linux; U; Android 13; SM-S928N Build/UP1A.231005.007)';

  // ── 서버 호스트 (Host 헤더용) ──
  static const String host = 'smart.letskorail.com';

  // ── 에러 코드 ──
  /// 세션 만료 / 로그인 필요
  static const String errNeedLogin = 'P058';

  /// 결과 없음 계열
  static const Set<String> errNoResult = {
    'P100',
    'WRG000000',
    'WRD000061',
    'WRT300005',
  };

  /// 매진
  static const String errSoldOut = 'ERR211161';

  // ── 좌석 가능 코드 ──
  static const String seatAvailable = '11';

  // ── 열차 타입 ──
  static const String trainTypeKtx = '109';
}
