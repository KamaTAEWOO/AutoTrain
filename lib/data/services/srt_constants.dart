/// SRT API 상수
class SrtConstants {
  SrtConstants._();

  // ── 서버 ──
  static const String baseUrl = 'https://app.srail.or.kr:443';

  // ── 엔드포인트 ──
  static const String mainUrl = '/main/main.do';
  static const String loginUrl = '/apb/selectListApb01080_n.do';
  static const String logoutUrl = '/login/loginOut.do';
  static const String searchUrl = '/ara/selectListAra10007_n.do';
  static const String reserveUrl = '/arc/selectListArc05013_n.do';
  static const String reservationListUrl = '/atc/selectListAtc14016_n.do';
  static const String cancelUrl = '/ard/selectListArd02045_n.do';
  static const String standbyOptionUrl = '/ata/selectListAta01135_n.do';

  // ── User-Agent (iOS SRT 앱) ──
  static const String userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0_1 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 SRT-APP-iOS V.2.0.18';

  // ── 열차 타입 ──
  static const String trainGroupSrt = '109';
  static const String trainClassSrt = '05';

  // ── 역 코드 맵 ──
  static const Map<String, String> stationCodes = {
    '수서': '0551',
    '동탄': '0552',
    '평택지제': '0553',
    '경주': '0508',
    '곡성': '0049',
    '공주': '0514',
    '광주송정': '0036',
    '구례구': '0050',
    '김천구미': '0507',
    '나주': '0037',
    '남원': '0048',
    '대전': '0010',
    '동대구': '0015',
    '목포': '0041',
    '부산': '0020',
    '서대구': '0556',
    '순천': '0051',
    '신경주': '0508',
    '여수EXPO': '0053',
    '오송': '0297',
    '울산(통도사)': '0509',
    '익산': '0030',
    '전주': '0045',
    '정읍': '0033',
    '진주': '0056',
    '창원': '0057',
    '창원중앙': '0058',
    '천안아산': '0502',
    '포항': '0515',
  };

  /// 역 이름 → 코드
  static String stationCode(String name) {
    return stationCodes[name] ?? '';
  }

  /// 역 코드 → 이름
  static String stationName(String code) {
    for (final entry in stationCodes.entries) {
      if (entry.value == code) return entry.key;
    }
    return code;
  }
}
