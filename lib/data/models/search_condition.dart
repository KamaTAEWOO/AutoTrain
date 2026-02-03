/// 열차 검색 조건 모델
class SearchCondition {
  final String depStation;
  final String arrStation;
  final String date;
  final String time;
  final String trainType;
  final bool autoReserve;
  final int refreshInterval;

  const SearchCondition({
    required this.depStation,
    required this.arrStation,
    required this.date,
    required this.time,
    this.trainType = 'KTX',
    this.autoReserve = true,
    this.refreshInterval = 10,
  });

  factory SearchCondition.fromJson(Map<String, dynamic> json) {
    return SearchCondition(
      depStation: json['dep_station'] as String,
      arrStation: json['arr_station'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      trainType: json['train_type'] as String? ?? 'KTX',
      autoReserve: json['auto_reserve'] as bool? ?? true,
      refreshInterval: json['refresh_interval'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dep_station': depStation,
      'arr_station': arrStation,
      'date': date,
      'time': time,
      'train_type': trainType,
      'auto_reserve': autoReserve,
      'refresh_interval': refreshInterval,
    };
  }

  SearchCondition copyWith({
    String? depStation,
    String? arrStation,
    String? date,
    String? time,
    String? trainType,
    bool? autoReserve,
    int? refreshInterval,
  }) {
    return SearchCondition(
      depStation: depStation ?? this.depStation,
      arrStation: arrStation ?? this.arrStation,
      date: date ?? this.date,
      time: time ?? this.time,
      trainType: trainType ?? this.trainType,
      autoReserve: autoReserve ?? this.autoReserve,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }

  @override
  String toString() {
    return 'SearchCondition($depStation->$arrStation, $date $time)';
  }
}
