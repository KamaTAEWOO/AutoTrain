/// KTX 주요 정차역 목록
class Stations {
  Stations._();

  static const List<String> ktxStations = [
    // 경부선
    '서울',
    '용산',
    '영등포',
    '광명',
    '수서',
    '수원',
    '동탄',
    '평택지제',
    '천안아산',
    '오송',
    '대전',
    '김천구미',
    '서대구',
    '동대구',
    '경산',
    '신경주',
    '울산',
    '물금',
    '구포',
    '밀양',
    '부산',
    // 호남선
    '공주',
    '익산',
    '정읍',
    '광주송정',
    '나주',
    '목포',
    // 전라선
    '전주',
    '남원',
    '순천',
    '여수엑스포',
    // 동해선
    '포항',
    // 경전선
    '창원중앙',
    '마산',
    // 경강선
    '강릉',
    '만종',
    '둔내',
    '평창',
    '진부',
    // 기타
    '행신',
    '청량리',
    '상봉',
    '양평',
  ];

  /// 주어진 쿼리로 역명을 필터링한다.
  static List<String> filter(String query) {
    if (query.isEmpty) return ktxStations;
    return ktxStations
        .where((station) => station.contains(query))
        .toList();
  }

  /// 유효한 역명인지 확인한다.
  static bool isValid(String name) {
    return ktxStations.contains(name);
  }
}
