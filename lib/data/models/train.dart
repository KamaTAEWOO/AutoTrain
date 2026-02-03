/// KTX 열차 정보 모델
class Train {
  final String trainNo;
  final String trainType;
  final String depStation;
  final String arrStation;
  final String depTime;
  final String arrTime;

  /// 좌석 유무 (null: 미확인 — TAGO 조회 시)
  final bool? generalSeats;
  final bool? specialSeats;

  /// 일반석 운임 (원). TAGO 공공데이터 조회 시 제공됨.
  final int? adultCharge;

  const Train({
    required this.trainNo,
    required this.trainType,
    required this.depStation,
    required this.arrStation,
    required this.depTime,
    required this.arrTime,
    this.generalSeats,
    this.specialSeats,
    this.adultCharge,
  });

  factory Train.fromJson(Map<String, dynamic> json) {
    return Train(
      trainNo: json['train_no'] as String,
      trainType: json['train_type'] as String,
      depStation: json['dep_station'] as String,
      arrStation: json['arr_station'] as String,
      depTime: json['dep_time'] as String,
      arrTime: json['arr_time'] as String,
      generalSeats: json['general_seats'] as bool?,
      specialSeats: json['special_seats'] as bool?,
      adultCharge: json['adult_charge'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'train_no': trainNo,
      'train_type': trainType,
      'dep_station': depStation,
      'arr_station': arrStation,
      'dep_time': depTime,
      'arr_time': arrTime,
      'general_seats': generalSeats,
      'special_seats': specialSeats,
      'adult_charge': adultCharge,
    };
  }

  /// 운임을 포맷팅한 문자열 (예: "59,800원")
  String? get formattedCharge {
    if (adultCharge == null || adultCharge == 0) return null;
    final str = adultCharge.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '${buffer}원';
  }

  Train copyWith({
    String? trainNo,
    String? trainType,
    String? depStation,
    String? arrStation,
    String? depTime,
    String? arrTime,
    bool? generalSeats,
    bool? specialSeats,
    int? adultCharge,
  }) {
    return Train(
      trainNo: trainNo ?? this.trainNo,
      trainType: trainType ?? this.trainType,
      depStation: depStation ?? this.depStation,
      arrStation: arrStation ?? this.arrStation,
      depTime: depTime ?? this.depTime,
      arrTime: arrTime ?? this.arrTime,
      generalSeats: generalSeats ?? this.generalSeats,
      specialSeats: specialSeats ?? this.specialSeats,
      adultCharge: adultCharge ?? this.adultCharge,
    );
  }

  @override
  String toString() {
    return 'Train($trainNo, $depStation->$arrStation, $depTime~$arrTime)';
  }
}
