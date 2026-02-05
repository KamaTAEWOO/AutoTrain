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
  static const String device = 'AD';
  static const String version = '190617001';
  static const String loginVersion = '231231001';

  // ── User-Agent ──
  static const String userAgent =
      'Dalvik/2.1.0 (Linux; U; Android 5.1.1; Nexus 4 Build/LMY48T)';

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
