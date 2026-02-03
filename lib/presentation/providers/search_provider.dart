import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_enums.dart';
import '../../data/models/search_condition.dart';
import '../../data/models/train.dart';

/// 검색 조건 상태
class SearchState {
  final String depStation;
  final String arrStation;
  final DateTime selectedDate;
  final int selectedHour;
  final int selectedMinute;
  final bool autoReserve;
  final int refreshInterval;
  final int passengerCount;
  final SeatType seatType;

  /// 일회성 검색 결과 (열차 리스트)
  final List<Train> searchResults;
  final bool isSearching;

  /// 사용자가 선택한 열차 목록 (자동예약 대상, 복수 선택 가능)
  final List<Train> selectedTrains;

  const SearchState({
    this.depStation = '',
    this.arrStation = '',
    required this.selectedDate,
    this.selectedHour = 9,
    this.selectedMinute = 0,
    this.autoReserve = true,
    this.refreshInterval = 10,
    this.passengerCount = 1,
    this.seatType = SeatType.general,
    this.searchResults = const [],
    this.isSearching = false,
    this.selectedTrains = const [],
  });

  /// 선택된 열차가 있어 자동예약 시작 가능
  bool get canAutoReserve =>
      isValid && selectedTrains.isNotEmpty && !isSearching;

  SearchState copyWith({
    String? depStation,
    String? arrStation,
    DateTime? selectedDate,
    int? selectedHour,
    int? selectedMinute,
    bool? autoReserve,
    int? refreshInterval,
    int? passengerCount,
    SeatType? seatType,
    List<Train>? searchResults,
    bool? isSearching,
    List<Train>? selectedTrains,
    bool clearSelectedTrains = false,
  }) {
    return SearchState(
      depStation: depStation ?? this.depStation,
      arrStation: arrStation ?? this.arrStation,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedHour: selectedHour ?? this.selectedHour,
      selectedMinute: selectedMinute ?? this.selectedMinute,
      autoReserve: autoReserve ?? this.autoReserve,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      passengerCount: passengerCount ?? this.passengerCount,
      seatType: seatType ?? this.seatType,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      selectedTrains:
          clearSelectedTrains ? const [] : (selectedTrains ?? this.selectedTrains),
    );
  }

  /// 유효성 검증
  bool get isValid => depStation.isNotEmpty && arrStation.isNotEmpty;

  /// SearchCondition 모델로 변환
  SearchCondition toSearchCondition() {
    final dateStr = '${selectedDate.year}'
        '${selectedDate.month.toString().padLeft(2, '0')}'
        '${selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr = '${selectedHour.toString().padLeft(2, '0')}'
        '${selectedMinute.toString().padLeft(2, '0')}00';

    return SearchCondition(
      depStation: depStation,
      arrStation: arrStation,
      date: dateStr,
      time: timeStr,
      autoReserve: autoReserve,
      refreshInterval: refreshInterval,
    );
  }

  /// 표시용 날짜 문자열
  String get formattedDate =>
      '${selectedDate.year}.'
      '${selectedDate.month.toString().padLeft(2, '0')}.'
      '${selectedDate.day.toString().padLeft(2, '0')}';

  /// 표시용 시간 문자열
  String get formattedTime =>
      '${selectedHour.toString().padLeft(2, '0')}:'
      '${selectedMinute.toString().padLeft(2, '0')}';

  /// 승객 수 표시
  String get passengerLabel => '어른 $passengerCount명';

  /// 좌석 유형 표시
  String get seatTypeLabel {
    switch (seatType) {
      case SeatType.general:
        return '일반실';
      case SeatType.special:
        return '특실';
    }
  }
}

/// 검색 조건 StateNotifier
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier()
      : super(SearchState(
          selectedDate: DateTime.now(),
        ));

  void setDepStation(String station) {
    state = state.copyWith(depStation: station);
  }

  void setArrStation(String station) {
    state = state.copyWith(arrStation: station);
  }

  void swapStations() {
    state = state.copyWith(
      depStation: state.arrStation,
      arrStation: state.depStation,
    );
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void setTime(int hour, int minute) {
    state = state.copyWith(selectedHour: hour, selectedMinute: minute);
  }

  void setAutoReserve(bool value) {
    state = state.copyWith(autoReserve: value);
  }

  void setRefreshInterval(int seconds) {
    state = state.copyWith(refreshInterval: seconds);
  }

  void setPassengerCount(int count) {
    state = state.copyWith(passengerCount: count.clamp(1, 9));
  }

  void setSeatType(SeatType type) {
    state = state.copyWith(seatType: type);
  }

  void setSearchResults(List<Train> trains) {
    state = state.copyWith(
      searchResults: trains,
      isSearching: false,
      clearSelectedTrains: true,
    );
  }

  void setSearching(bool value) {
    state = state.copyWith(isSearching: value);
  }

  /// 자동예약 대상 열차 토글 (이미 선택됐으면 해제, 아니면 추가)
  void toggleTrain(Train train) {
    final current = [...state.selectedTrains];
    final index = current.indexWhere((t) => t.trainNo == train.trainNo);
    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(train);
    }
    state = state.copyWith(selectedTrains: current);
  }

  /// 전체 열차 선택 해제
  void clearSelection() {
    state = state.copyWith(clearSelectedTrains: true);
  }

  void clearResults() {
    state = state.copyWith(
      searchResults: [],
      isSearching: false,
      clearSelectedTrains: true,
    );
  }
}

/// 검색 조건 Provider
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});
