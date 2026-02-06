import 'train.dart';
import '../services/srt_constants.dart';

/// SRT 검색 API 응답의 전체 필드를 보존하는 내부 모델
class SrtTrain {
  final String trainNo;          // trnNo 열차번호
  final String trainClassCode;   // stlbTrnClsfCd 열차분류코드 (예: '17'=SRT)
  final String trainType;        // stlbTrnClsfNm 열차종류명
  final String trainGroup;       // trnGpCd (예: '300')

  final String depStationCode;   // dptRsStnCd
  final String depStationName;   // dptRsStnNm
  final String depDate;          // dptDt
  final String depTime;          // dptTm

  final String arrStationCode;   // arvRsStnCd
  final String arrStationName;   // arvRsStnNm
  final String arrDate;          // arvDt
  final String arrTime;          // arvTm

  final String runDate;          // runDt

  final String generalSeatCode;  // gnrmRsvPsbStr ('예약가능' = 가능)
  final String specialSeatCode;  // sprmRsvPsbStr ('예약가능' = 가능)

  /// 예약용 추가 필드
  final String jrnySqno;         // jrnySqno
  final String jrnyTpCd;         // jrnyTpCd
  final String stndFlg;          // stndFlg

  /// 역 순서 (예약 시 필요)
  final String depStationConsOrdr; // dptStnConsOrdr
  final String arrStationConsOrdr; // arvStnConsOrdr
  final String depStationRunOrdr;  // dptStnRunOrdr
  final String arrStationRunOrdr;  // arvStnRunOrdr

  const SrtTrain({
    required this.trainNo,
    required this.trainClassCode,
    required this.trainType,
    required this.trainGroup,
    required this.depStationCode,
    required this.depStationName,
    required this.depDate,
    required this.depTime,
    required this.arrStationCode,
    required this.arrStationName,
    required this.arrDate,
    required this.arrTime,
    required this.runDate,
    required this.generalSeatCode,
    required this.specialSeatCode,
    this.jrnySqno = '001',
    this.jrnyTpCd = '11',
    this.stndFlg = 'N',
    this.depStationConsOrdr = '000000',
    this.arrStationConsOrdr = '000000',
    this.depStationRunOrdr = '000000',
    this.arrStationRunOrdr = '000000',
  });

  factory SrtTrain.fromJson(Map<String, dynamic> json) {
    return SrtTrain(
      trainNo: (json['trnNo'] as String? ?? '').trim(),
      trainClassCode: (json['stlbTrnClsfCd'] as String? ?? '17').trim(),
      trainType: _resolveTrainType(
        json['stlbTrnClsfNm'] as String?,
        json['stlbTrnClsfCd'] as String?,
      ),
      trainGroup: json['trnGpCd'] as String? ?? '300',
      depStationCode: json['dptRsStnCd'] as String? ?? '',
      depStationName: json['dptRsStnNm'] as String? ?? '',
      depDate: json['dptDt'] as String? ?? '',
      depTime: json['dptTm'] as String? ?? '',
      arrStationCode: json['arvRsStnCd'] as String? ?? '',
      arrStationName: json['arvRsStnNm'] as String? ?? '',
      arrDate: json['arvDt'] as String? ?? '',
      arrTime: json['arvTm'] as String? ?? '',
      runDate: json['runDt'] as String? ?? json['dptDt'] as String? ?? '',
      generalSeatCode: json['gnrmRsvPsbStr'] as String? ?? '',
      specialSeatCode: json['sprmRsvPsbStr'] as String? ?? '',
      jrnySqno: json['jrnySqno'] as String? ?? '001',
      jrnyTpCd: json['jrnyTpCd'] as String? ?? '11',
      stndFlg: json['stndFlg'] as String? ?? 'N',
      depStationConsOrdr: json['dptStnConsOrdr'] as String? ?? '000000',
      arrStationConsOrdr: json['arvStnConsOrdr'] as String? ?? '000000',
      depStationRunOrdr: json['dptStnRunOrdr'] as String? ?? '000000',
      arrStationRunOrdr: json['arvStnRunOrdr'] as String? ?? '000000',
    );
  }

  /// 일반석 예약 가능 여부
  bool get hasGeneralSeats =>
      generalSeatCode.contains('예약가능');

  /// 특실 예약 가능 여부
  bool get hasSpecialSeats =>
      specialSeatCode.contains('예약가능');

  /// 출발 시간 포맷 (HHmmss → HH:mm)
  String get depTimeFormatted {
    if (depTime.length >= 4) {
      return '${depTime.substring(0, 2)}:${depTime.substring(2, 4)}';
    }
    return depTime;
  }

  /// 도착 시간 포맷 (HHmmss → HH:mm)
  String get arrTimeFormatted {
    if (arrTime.length >= 4) {
      return '${arrTime.substring(0, 2)}:${arrTime.substring(2, 4)}';
    }
    return arrTime;
  }

  /// 캐시 키 (열차번호 + 출발시간)
  String get cacheKey => '${trainNo}_$depTime';

  /// 공개 [Train] 모델로 변환
  Train toTrain() {
    return Train(
      trainNo: trainNo.trim(),
      trainType: trainType.trim().isEmpty ? 'SRT' : trainType.trim(),
      depStation: _cleanStationName(depStationName),
      arrStation: _cleanStationName(arrStationName),
      depTime: depTimeFormatted,
      arrTime: arrTimeFormatted,
      generalSeats: hasGeneralSeats,
      specialSeats: hasSpecialSeats,
    );
  }

  /// 역 이름 정리 (코드가 포함된 경우 이름만 추출)
  String _cleanStationName(String raw) {
    final name = raw.trim();
    // SRT API 응답에서 역 코드 맵의 이름으로 매칭 시도
    final mapped = SrtConstants.stationName(name);
    if (mapped != name) return mapped;
    return name;
  }

  /// 열차 타입명 결정 (이름이 없으면 코드로 매핑)
  static String _resolveTrainType(String? name, String? code) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return switch (code) {
      '17' => 'SRT',
      '00' => 'KTX',
      '07' || '10' => 'KTX-산천',
      '18' => 'ITX-마음',
      _ => 'SRT',
    };
  }

  @override
  String toString() =>
      'SrtTrain($trainNo, $depStationName→$arrStationName, $depTime~$arrTime)';
}
