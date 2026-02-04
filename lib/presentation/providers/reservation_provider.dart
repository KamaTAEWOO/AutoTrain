import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/api_error.dart';
import '../../data/models/reservation.dart';
import '../../data/repositories/train_repository.dart';

/// 예약 결과 상태
class ReservationState {
  final Reservation? reservation;
  final bool hasResult;
  final bool isCancelling;
  final bool isCancelled;
  final String? cancelError;

  /// 내 예약 목록
  final List<Reservation> reservations;
  final bool isLoadingList;
  final String? listError;

  const ReservationState({
    this.reservation,
    this.hasResult = false,
    this.isCancelling = false,
    this.isCancelled = false,
    this.cancelError,
    this.reservations = const [],
    this.isLoadingList = false,
    this.listError,
  });

  ReservationState copyWith({
    Reservation? reservation,
    bool? hasResult,
    bool? isCancelling,
    bool? isCancelled,
    String? cancelError,
    List<Reservation>? reservations,
    bool? isLoadingList,
    String? listError,
    bool clearListError = false,
  }) {
    return ReservationState(
      reservation: reservation ?? this.reservation,
      hasResult: hasResult ?? this.hasResult,
      isCancelling: isCancelling ?? this.isCancelling,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelError: cancelError,
      reservations: reservations ?? this.reservations,
      isLoadingList: isLoadingList ?? this.isLoadingList,
      listError: clearListError ? null : (listError ?? this.listError),
    );
  }
}

/// 예약 결과 StateNotifier
class ReservationNotifier extends StateNotifier<ReservationState> {
  final TrainRepository _repository;

  ReservationNotifier({TrainRepository? repository})
      : _repository = repository ?? TrainRepository(),
        super(const ReservationState());

  /// 예약 결과 설정
  void setReservation(Reservation reservation) {
    state = ReservationState(
      reservation: reservation,
      hasResult: true,
      reservations: state.reservations,
    );
  }

  /// 내 예약 목록 조회
  Future<void> fetchReservations() async {
    state = state.copyWith(isLoadingList: true, clearListError: true);
    try {
      final list = await _repository.fetchReservations();
      state = state.copyWith(
        reservations: list,
        isLoadingList: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingList: false,
        listError: _parseError(e),
      );
    }
  }

  /// 예약 취소
  Future<bool> cancelReservation(String reservationId) async {
    state = state.copyWith(isCancelling: true, cancelError: null);

    try {
      await _repository.cancelReservation(reservationId);

      // 목록에서 해당 예약 즉시 제거 (서버 반영 지연 대비)
      final updatedList = state.reservations
          .where((r) => r.reservationId != reservationId)
          .toList();

      state = state.copyWith(
        isCancelling: false,
        isCancelled: true,
        reservations: updatedList,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCancelling: false,
        cancelError: _parseError(e),
      );
      return false;
    }
  }

  String _parseError(Object e) {
    if (e is ApiError) {
      return e.detail;
    }
    if (e is NetworkError) {
      return '서버에 연결할 수 없습니다';
    }
    return '예약 취소에 실패했습니다: $e';
  }

  /// 상태 초기화
  void reset() {
    state = const ReservationState();
  }
}

/// 예약 결과 Provider
final reservationProvider =
    StateNotifierProvider<ReservationNotifier, ReservationState>((ref) {
  return ReservationNotifier();
});
