import 'train.dart';
import '../services/korail_constants.dart';

/// 코레일 검색 API 응답의 전체 필드를 보존하는 내부 모델
///
/// 예약 시 `depCode`, `arrCode`, `runDate`, `trainGroup` 등이 필요하므로
/// 공개 [Train] 모델보다 더 많은 필드를 저장한다.
class KorailTrain {
  final String trainNo;        // h_trn_no
  final String trainType;      // h_trn_clsf_cd
  final String trainTypeName;  // h_trn_clsf_nm
  final String trainGroup;     // h_trn_gp_cd

  final String depStationCode; // h_dpt_rs_stn_cd
  final String depStationName; // h_dpt_rs_stn_nm
  final String depDate;        // h_dpt_dt
  final String depTime;        // h_dpt_tm

  final String arrStationCode; // h_arv_rs_stn_cd
  final String arrStationName; // h_arv_rs_stn_nm
  final String arrDate;        // h_arv_dt
  final String arrTime;        // h_arv_tm

  final String runDate;        // h_run_dt

  final String generalSeatCode;  // h_gen_rsv_cd ('11' = 가능)
  final String specialSeatCode;  // h_spe_rsv_cd ('11' = 가능)

  const KorailTrain({
    required this.trainNo,
    required this.trainType,
    required this.trainTypeName,
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
  });

  factory KorailTrain.fromJson(Map<String, dynamic> json) {
    return KorailTrain(
      trainNo: json['h_trn_no'] as String? ?? '',
      trainType: json['h_trn_clsf_cd'] as String? ?? '',
      trainTypeName: json['h_trn_clsf_nm'] as String? ?? '',
      trainGroup: json['h_trn_gp_cd'] as String? ?? '',
      depStationCode: json['h_dpt_rs_stn_cd'] as String? ?? '',
      depStationName: json['h_dpt_rs_stn_nm'] as String? ?? '',
      depDate: json['h_dpt_dt'] as String? ?? '',
      depTime: json['h_dpt_tm'] as String? ?? '',
      arrStationCode: json['h_arv_rs_stn_cd'] as String? ?? '',
      arrStationName: json['h_arv_rs_stn_nm'] as String? ?? '',
      arrDate: json['h_arv_dt'] as String? ?? '',
      arrTime: json['h_arv_tm'] as String? ?? '',
      runDate: json['h_run_dt'] as String? ?? '',
      generalSeatCode: json['h_gen_rsv_cd'] as String? ?? '',
      specialSeatCode: json['h_spe_rsv_cd'] as String? ?? '',
    );
  }

  /// 일반석 예약 가능 여부
  bool get hasGeneralSeats =>
      generalSeatCode == KorailConstants.seatAvailable;

  /// 특실 예약 가능 여부
  bool get hasSpecialSeats =>
      specialSeatCode == KorailConstants.seatAvailable;

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
      trainType: trainTypeName.trim(),
      depStation: depStationName.trim(),
      arrStation: arrStationName.trim(),
      depTime: depTimeFormatted,
      arrTime: arrTimeFormatted,
      generalSeats: hasGeneralSeats,
      specialSeats: hasSpecialSeats,
    );
  }

  @override
  String toString() =>
      'KorailTrain($trainNo, $depStationName→$arrStationName, $depTime~$arrTime)';
}
