import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_enums.dart';
import '../../core/services/background_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/api_error.dart';
import '../../data/models/search_condition.dart';
import '../../data/models/train.dart';
import '../../data/repositories/train_repository.dart';
import 'auth_provider.dart';
import 'log_provider.dart';
import 'reservation_provider.dart';

/// 모니터링 상태
class MonitorState {
  final MonitorStatus status;
  final int searchCount;
  final DateTime? lastSearchTime;
  final List<Train> foundTrains;
  final SearchCondition? condition;
  final String? errorMessage;

  /// 자동예약 대상 열차 번호 목록
  final List<String> targetTrainNos;

  const MonitorState({
    this.status = MonitorStatus.idle,
    this.searchCount = 0,
    this.lastSearchTime,
    this.foundTrains = const [],
    this.condition,
    this.errorMessage,
    this.targetTrainNos = const [],
  });

  MonitorState copyWith({
    MonitorStatus? status,
    int? searchCount,
    DateTime? lastSearchTime,
    List<Train>? foundTrains,
    SearchCondition? condition,
    String? errorMessage,
    List<String>? targetTrainNos,
  }) {
    return MonitorState(
      status: status ?? this.status,
      searchCount: searchCount ?? this.searchCount,
      lastSearchTime: lastSearchTime ?? this.lastSearchTime,
      foundTrains: foundTrains ?? this.foundTrains,
      condition: condition ?? this.condition,
      errorMessage: errorMessage ?? this.errorMessage,
      targetTrainNos: targetTrainNos ?? this.targetTrainNos,
    );
  }
}

/// 모니터링 StateNotifier
/// Timer.periodic 기반 자동 조회 및 상태 전이 관리
class MonitorNotifier extends StateNotifier<MonitorState>
    with WidgetsBindingObserver {
  final TrainRepository _repository;
  final LogNotifier _logNotifier;
  final ReservationNotifier _reservationNotifier;
  final AuthNotifier _authNotifier;
  Timer? _timer;

  /// 탭 전환 콜백 (success/failure 시 결과 탭으로 이동)
  void Function(int tabIndex)? onTabChange;

  MonitorNotifier({
    required TrainRepository repository,
    required LogNotifier logNotifier,
    required ReservationNotifier reservationNotifier,
    required AuthNotifier authNotifier,
  })  : _repository = repository,
        _logNotifier = logNotifier,
        _reservationNotifier = reservationNotifier,
        _authNotifier = authNotifier,
        super(const MonitorState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onBackground();
        break;
      case AppLifecycleState.resumed:
        _onForeground();
        break;
      default:
        break;
    }
  }

  /// 자동 조회 시작
  ///
  /// [targetTrains]가 지정되면 해당 열차들만 좌석을 모니터링한다.
  void startMonitoring(SearchCondition condition, {List<Train> targetTrains = const []}) {
    // 이전 타이머 정리
    _stopTimer();

    final trainNos = targetTrains.map((t) => t.trainNo).toList();

    state = MonitorState(
      status: MonitorStatus.searching,
      condition: condition,
      searchCount: 0,
      targetTrainNos: trainNos,
    );

    final targetInfo = targetTrains.isNotEmpty
        ? ' [${targetTrains.map((t) => '${t.trainNo} ${t.depTime}→${t.arrTime}').join(', ')}]'
        : '';

    _logNotifier.addLog(
      action: 'search',
      result: 'info',
      detail:
          '자동 조회 시작 - ${condition.depStation} → ${condition.arrStation}$targetInfo',
    );

    // 즉시 1회 조회 후 타이머 시작
    _performSearch();

    _timer = Timer.periodic(
      Duration(seconds: condition.refreshInterval),
      (_) => _performSearch(),
    );
  }

  /// 조회 수행
  Future<void> _performSearch() async {
    if (state.condition == null) return;
    if (state.status != MonitorStatus.searching) return;

    final condition = state.condition!;

    try {
      final trains = await _repository.searchTrains(
        condition.depStation,
        condition.arrStation,
        condition.date,
        condition.time,
      );

      final now = DateTime.now();
      final newCount = state.searchCount + 1;
      final targetNos = state.targetTrainNos;

      // 포그라운드 서비스 알림 업데이트 (실패해도 조회에는 영향 없음)
      try {
        BackgroundService.instance.updateNotification(
          '조회 #$newCount - ${condition.depStation} → ${condition.arrStation}',
        );
      } catch (_) {}

      // 대상 열차 필터링: targetTrainNos가 있으면 해당 열차들만 확인
      final candidates = targetNos.isNotEmpty
          ? trains.where((t) => targetNos.contains(t.trainNo)).toList()
          : trains;

      // 좌석이 있는 열차 찾기
      // TAGO API는 좌석 정보를 제공하지 않아 null로 옴.
      // null(미확인)인 경우에도 예약 가능성이 있으므로 후보에 포함.
      // korail2 reserve()가 실제 매진 여부를 판단한다.
      final availableTrains = candidates
          .where((t) =>
              (t.generalSeats == true) ||
              (t.specialSeats == true) ||
              (t.generalSeats == null && t.specialSeats == null))
          .toList();

      if (availableTrains.isNotEmpty) {
        // 좌석 발견
        state = state.copyWith(
          status: MonitorStatus.found,
          searchCount: newCount,
          lastSearchTime: now,
          foundTrains: availableTrains,
        );

        final trainNosStr = availableTrains.map((t) => t.trainNo).join(', ');
        _logNotifier.addLog(
          action: 'search',
          result: 'success',
          detail: '조회 #$newCount - 좌석 발견! $trainNosStr',
        );

        // 자동 예약이 ON이면 순서대로 예약 시도
        if (condition.autoReserve) {
          await _attemptReservations(availableTrains);
        }
      } else {
        final detail = targetNos.isNotEmpty
            ? '조회 #$newCount - ${targetNos.join(', ')} 좌석 없음'
            : '조회 #$newCount - 좌석 없음';

        // 좌석 없음 - 계속 조회
        state = state.copyWith(
          searchCount: newCount,
          lastSearchTime: now,
          foundTrains: trains,
        );

        _logNotifier.addLog(
          action: 'search',
          result: 'no_seats',
          detail: detail,
        );
      }
    } on ApiError catch (e) {
      final newCount = state.searchCount + 1;
      final errorDetail = '[${e.code}] ${e.detail}';

      if (e.isSessionExpired) {
        // 세션 만료 시 모니터링 중지 → 로그인 화면으로 이동
        _stopTimer();
        _safeStopBackgroundService();
        state = state.copyWith(
          status: MonitorStatus.failure,
          searchCount: newCount,
          lastSearchTime: DateTime.now(),
          errorMessage: e.detail,
        );
        _logNotifier.addLog(
          action: 'error',
          result: 'failure',
          detail: '세션 만료 - 로그인 화면으로 이동',
        );
        _authNotifier.onSessionExpired();
      } else {
        // 기타 API 에러 - 조회는 계속
        state = state.copyWith(
          searchCount: newCount,
          lastSearchTime: DateTime.now(),
          errorMessage: e.detail,
        );
        _logNotifier.addLog(
          action: 'error',
          result: 'failure',
          detail: '조회 #$newCount - $errorDetail',
        );
      }
    } on NetworkError catch (e) {
      final newCount = state.searchCount + 1;
      state = state.copyWith(
        searchCount: newCount,
        lastSearchTime: DateTime.now(),
        errorMessage: e.message,
      );
      _logNotifier.addLog(
        action: 'error',
        result: 'failure',
        detail: '조회 #$newCount - 네트워크 오류: ${e.message}',
      );
    } catch (e) {
      final newCount = state.searchCount + 1;
      state = state.copyWith(
        searchCount: newCount,
        lastSearchTime: DateTime.now(),
        errorMessage: e.toString(),
      );

      _logNotifier.addLog(
        action: 'error',
        result: 'failure',
        detail: '조회 #$newCount - 오류: $e',
      );
    }
  }

  /// 복수 열차 순서대로 예약 시도
  ///
  /// 하나라도 성공하면 즉시 중지하고 내예약 탭으로 이동.
  /// 모두 매진이면 폴링을 재개한다.
  Future<void> _attemptReservations(List<Train> trains) async {
    _stopTimer();

    state = state.copyWith(status: MonitorStatus.reserving);
    final condition = state.condition;

    bool allSoldOut = true;

    for (final train in trains) {
      _logNotifier.addLog(
        action: 'reserve',
        result: 'info',
        detail: '예약 시도 - ${train.trainNo} (${condition?.depStation}→${condition?.arrStation})',
      );

      try {
        // 좌석 유형 결정: 특실이 확실히 있으면 special, 그 외 general 우선
        final seatType = (train.specialSeats == true && train.generalSeats != true)
            ? 'special'
            : 'general';

        // 열차의 실제 출발시간을 HHmmss 포맷으로 변환하여 전달
        // TAGO depTime은 "HH:MM" 형식, 백엔드는 "HHmmss" 기대
        final trainTime = train.depTime.replaceAll(':', '').padRight(6, '0');

        final reservation = await _repository.reserve(
          train.trainNo,
          seatType,
          depStation: condition?.depStation ?? train.depStation,
          arrStation: condition?.arrStation ?? train.arrStation,
          date: condition?.date ?? '',
          time: trainTime,
        );

        if (reservation.isSuccess) {
          state = state.copyWith(status: MonitorStatus.success);

          _logNotifier.addLog(
            action: 'reserve',
            result: 'success',
            detail: '예약 성공 - ${train.trainNo} ${reservation.reservationId}',
          );

          // 로컬 알림 표시
          try {
            await NotificationService.instance.showReservationSuccess(
              trainNo: train.trainNo,
              reservationId: reservation.reservationId,
              depStation: condition?.depStation,
              arrStation: condition?.arrStation,
            );
          } catch (_) {}

          // 백그라운드 서비스 중지
          _safeStopBackgroundService();

          _reservationNotifier.setReservation(reservation);
          onTabChange?.call(2); // 내 예약 탭으로 이동
          return; // 성공 시 즉시 중지
        } else {
          state = state.copyWith(status: MonitorStatus.failure);

          _logNotifier.addLog(
            action: 'reserve',
            result: 'failure',
            detail: '예약 실패 - ${train.trainNo} ${reservation.message}',
          );

          _safeStopBackgroundService();
          _reservationNotifier.setReservation(reservation);
          onTabChange?.call(2); // 내 예약 탭으로 이동
          return; // API가 실패 응답을 준 경우 중지
        }
      } on ApiError catch (e) {
        String logDetail;
        if (e.isSoldOut) {
          logDetail = '${train.trainNo} 매진 - ${e.detail}';
        } else if (e.isSessionExpired) {
          logDetail = '세션 만료 - 다시 로그인이 필요합니다';
        } else {
          logDetail = '${train.trainNo} 예약 오류 [${e.code}] - ${e.detail}';
        }

        _logNotifier.addLog(
          action: 'reserve',
          result: 'failure',
          detail: logDetail,
        );

        if (e.isSoldOut || e.isNoTrains) {
          // 매진 또는 열차 매칭 실패면 다음 열차로 계속
          continue;
        } else {
          // 세션 만료 등 기타 에러는 즉시 중지
          allSoldOut = false;
          state = state.copyWith(
            status: MonitorStatus.failure,
            errorMessage: e.detail,
          );
          _safeStopBackgroundService();
          if (e.isSessionExpired) {
            _authNotifier.onSessionExpired();
          } else {
            onTabChange?.call(2); // 내 예약 탭으로 이동
          }
          return;
        }
      } on NetworkError catch (e) {
        allSoldOut = false;
        state = state.copyWith(
          status: MonitorStatus.failure,
          errorMessage: e.message,
        );

        _logNotifier.addLog(
          action: 'reserve',
          result: 'failure',
          detail: '${train.trainNo} 예약 오류 - 네트워크: ${e.message}',
        );

        _safeStopBackgroundService();
        onTabChange?.call(2); // 내 예약 탭으로 이동
        return;
      } catch (e) {
        allSoldOut = false;
        state = state.copyWith(
          status: MonitorStatus.failure,
          errorMessage: e.toString(),
        );

        _logNotifier.addLog(
          action: 'reserve',
          result: 'failure',
          detail: '${train.trainNo} 예약 오류 - $e',
        );

        _safeStopBackgroundService();
        onTabChange?.call(2); // 내 예약 탭으로 이동
        return;
      }
    }

    // 모든 열차가 매진 → 폴링 재개
    if (allSoldOut && state.condition != null) {
      _logNotifier.addLog(
        action: 'reserve',
        result: 'info',
        detail: '선택한 열차 모두 매진 - 조회 재개',
      );
      state = state.copyWith(status: MonitorStatus.searching);
      _timer = Timer.periodic(
        Duration(seconds: state.condition!.refreshInterval),
        (_) => _performSearch(),
      );
    }
  }

  /// 모니터링 중지
  void stopMonitoring() {
    _stopTimer();
    _safeStopBackgroundService();
    state = state.copyWith(status: MonitorStatus.idle);

    _logNotifier.addLog(
      action: 'search',
      result: 'info',
      detail: '사용자에 의해 중지됨',
    );
  }

  /// 재시도 (실패 후)
  void retry() {
    if (state.condition != null) {
      startMonitoring(state.condition!);
    }
  }

  /// 상태 초기화
  void reset() {
    _stopTimer();
    state = const MonitorState();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 앱 백그라운드 전환 시: 모니터링 중이면 foreground service 시작
  void _onBackground() {
    if (_timer != null && state.status == MonitorStatus.searching) {
      _safeStartBackgroundService();
      _logNotifier.addLog(
        action: 'search',
        result: 'info',
        detail: '앱 백그라운드 전환 - 모니터링 계속',
      );
    }
  }

  /// 앱 포그라운드 복귀 시: foreground service 중지
  void _onForeground() {
    if (state.status == MonitorStatus.searching) {
      _safeStopBackgroundService();
      _logNotifier.addLog(
        action: 'search',
        result: 'info',
        detail: '앱 포그라운드 복귀',
      );
    }
  }

  /// 백그라운드 서비스를 안전하게 시작
  void _safeStartBackgroundService() {
    try {
      BackgroundService.instance.startService();
    } catch (e) {
      _logNotifier.addLog(
        action: 'service',
        result: 'failure',
        detail: '백그라운드 서비스 시작 실패: $e',
      );
    }
  }

  /// 백그라운드 서비스를 안전하게 중지
  void _safeStopBackgroundService() {
    try {
      BackgroundService.instance.stopService();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// 모니터 Provider
///
/// Backend API를 통해 열차 조회/예약을 수행한다.
final monitorProvider =
    StateNotifierProvider<MonitorNotifier, MonitorState>((ref) {
  final logNotifier = ref.read(logProvider.notifier);
  final reservationNotifier = ref.read(reservationProvider.notifier);
  final authNotifier = ref.read(authProvider.notifier);
  final railType = ref.watch(authProvider).railType;
  return MonitorNotifier(
    repository: TrainRepository(railType: railType),
    logNotifier: logNotifier,
    reservationNotifier: reservationNotifier,
    authNotifier: authNotifier,
  );
});
