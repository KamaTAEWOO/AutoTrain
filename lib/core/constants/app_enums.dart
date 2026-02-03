/// 모니터링 상태 enum
enum MonitorStatus {
  /// 대기 상태 - 조회 미시작
  idle,

  /// 열차 조회 진행 중
  searching,

  /// 좌석 있는 열차 발견
  found,

  /// 예약 시도 진행 중
  reserving,

  /// 예약 성공
  success,

  /// 예약 실패
  failure,
}

/// 좌석 유형
enum SeatType {
  /// 일반실
  general,

  /// 특실
  special,
}
