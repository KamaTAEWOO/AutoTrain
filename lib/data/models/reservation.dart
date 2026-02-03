import 'train.dart';

/// 예약 결과 모델
class Reservation {
  final String reservationId;
  final String status;
  final Train train;
  final String message;
  final DateTime reservedAt;
  final String? paymentDeadline;

  const Reservation({
    required this.reservationId,
    required this.status,
    required this.train,
    this.message = '',
    required this.reservedAt,
    this.paymentDeadline,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    // reserved_at이 빈 문자열이거나 파싱 불가능한 경우 현재 시간 사용
    DateTime parsedAt;
    try {
      final raw = json['reserved_at'] as String? ?? '';
      parsedAt = raw.isNotEmpty ? DateTime.parse(raw) : DateTime.now();
    } catch (_) {
      parsedAt = DateTime.now();
    }

    return Reservation(
      reservationId: json['reservation_id'] as String,
      status: json['status'] as String,
      train: Train.fromJson(json['train'] as Map<String, dynamic>),
      message: json['message'] as String? ?? '',
      reservedAt: parsedAt,
      paymentDeadline: json['payment_deadline'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reservation_id': reservationId,
      'status': status,
      'train': train.toJson(),
      'message': message,
      'reserved_at': reservedAt.toIso8601String(),
      if (paymentDeadline != null) 'payment_deadline': paymentDeadline,
    };
  }

  bool get isSuccess => status == 'success';
  bool get isFailure => status == 'failure';

  Reservation copyWith({
    String? reservationId,
    String? status,
    Train? train,
    String? message,
    DateTime? reservedAt,
    String? paymentDeadline,
  }) {
    return Reservation(
      reservationId: reservationId ?? this.reservationId,
      status: status ?? this.status,
      train: train ?? this.train,
      message: message ?? this.message,
      reservedAt: reservedAt ?? this.reservedAt,
      paymentDeadline: paymentDeadline ?? this.paymentDeadline,
    );
  }

  @override
  String toString() {
    return 'Reservation($reservationId, $status, ${train.trainNo})';
  }
}
