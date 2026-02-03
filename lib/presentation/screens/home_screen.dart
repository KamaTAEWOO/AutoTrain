import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_enums.dart';
import '../../core/constants/stations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/korail_colors.dart';
import '../../data/repositories/train_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/horizontal_date_picker.dart';
import '../widgets/station_selector.dart';

/// 코레일톡 스타일 홈/검색 화면
class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onTabChange;

  const HomeScreen({super.key, this.onTabChange});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '코레일톡',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (authState.userName.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${authState.userName}님',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            tooltip: '로그아웃',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 블루 그라데이션 영역
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: KorailColors.blueGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    // 역 선택 박스
                    StationSelector(
                      departure: searchState.depStation,
                      arrival: searchState.arrStation,
                      onDepartureChanged: (station) {
                        ref
                            .read(searchProvider.notifier)
                            .setDepStation(station);
                      },
                      onArrivalChanged: (station) {
                        ref
                            .read(searchProvider.notifier)
                            .setArrStation(station);
                      },
                      onSwap: () {
                        ref.read(searchProvider.notifier).swapStations();
                      },
                    ),

                    const SizedBox(height: 16),

                    // 수평 날짜 선택
                    HorizontalDatePicker(
                      selectedDate: searchState.selectedDate,
                      onDateSelected: (date) {
                        ref.read(searchProvider.notifier).setDate(date);
                      },
                    ),

                    const SizedBox(height: 16),

                    // 시간 + 승객 + 좌석유형
                    Row(
                      children: [
                        // 시간 선택
                        Expanded(
                          child: _buildOptionChip(
                            icon: Icons.access_time,
                            label: '${searchState.formattedTime} 이후',
                            onTap: () =>
                                _pickTime(context, searchState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 승객수
                        Expanded(
                          child: _buildOptionChip(
                            icon: Icons.person,
                            label: searchState.passengerLabel,
                            onTap: () =>
                                _showPassengerPicker(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 좌석유형
                        Expanded(
                          child: _buildOptionChip(
                            icon: Icons.event_seat,
                            label: searchState.seatTypeLabel,
                            onTap: () =>
                                _showSeatTypePicker(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 열차 조회 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _canSearch(searchState)
                            ? () => _searchTrains(searchState)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: KorailColors.korailBlue,
                          disabledBackgroundColor:
                              Colors.white.withAlpha(100),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusButton),
                          ),
                        ),
                        child: Text(
                          searchState.isSearching
                              ? '조회 중...'
                              : '열차 조회',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: KorailColors.statusFailure),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, SearchState searchState) async {
    int selectedHour = searchState.selectedHour;
    // 10분 단위 인덱스로 변환 (가장 가까운 값)
    int selectedMinuteIndex =
        ((searchState.selectedMinute + 5) ~/ 10).clamp(0, 5);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더: 타이틀 + 완료 버튼
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '시간 선택',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: KorailColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(searchProvider.notifier).setTime(
                                  selectedHour,
                                  selectedMinuteIndex * 10,
                                );
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: KorailColors.korailBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 스피너 영역
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        // 시 스피너
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedHour,
                            ),
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            selectionOverlay:
                                CupertinoPickerDefaultSelectionOverlay(
                              background:
                                  KorailColors.korailBlue.withAlpha(20),
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedHour = index);
                            },
                            children: List.generate(24, (i) {
                              return Center(
                                child: Text(
                                  '$i시',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              );
                            }),
                          ),
                        ),
                        // 분 스피너
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedMinuteIndex,
                            ),
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            selectionOverlay:
                                CupertinoPickerDefaultSelectionOverlay(
                              background:
                                  KorailColors.korailBlue.withAlpha(20),
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedMinuteIndex = index);
                            },
                            children: List.generate(6, (i) {
                              return Center(
                                child: Text(
                                  '${(i * 10).toString().padLeft(2, '0')}분',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPassengerPicker(BuildContext context) {
    final current = ref.read(searchProvider).passengerCount;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '승객 수',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: List.generate(9, (i) {
                  final count = i + 1;
                  return ChoiceChip(
                    label: Text('$count명'),
                    selected: count == current,
                    onSelected: (_) {
                      ref
                          .read(searchProvider.notifier)
                          .setPassengerCount(count);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showSeatTypePicker(BuildContext context) {
    final current = ref.read(searchProvider).seatType;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '좌석 유형',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('일반실'),
                leading: Icon(
                  current == SeatType.general
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: KorailColors.korailBlue,
                ),
                onTap: () {
                  ref
                      .read(searchProvider.notifier)
                      .setSeatType(SeatType.general);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('특실'),
                leading: Icon(
                  current == SeatType.special
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: KorailColors.korailBlue,
                ),
                onTap: () {
                  ref
                      .read(searchProvider.notifier)
                      .setSeatType(SeatType.special);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  bool _canSearch(SearchState searchState) {
    return searchState.depStation.isNotEmpty &&
        searchState.arrStation.isNotEmpty &&
        searchState.depStation != searchState.arrStation &&
        Stations.isValid(searchState.depStation) &&
        Stations.isValid(searchState.arrStation) &&
        !searchState.isSearching;
  }

  Future<void> _searchTrains(SearchState searchState) async {
    final notifier = ref.read(searchProvider.notifier);
    notifier.setSearching(true);

    try {
      final condition = searchState.toSearchCondition();
      final repo = TrainRepository();
      final trains = await repo.searchTrains(
        condition.depStation,
        condition.arrStation,
        condition.date,
        condition.time,
      );

      // 오늘 날짜면 현재 시간 이전 출발 열차 필터링
      final now = DateTime.now();
      final todayStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filtered = condition.date == todayStr
          ? trains.where((t) {
              final parts = t.depTime.split(':');
              if (parts.length != 2) return true;
              final depMinutes =
                  int.parse(parts[0]) * 60 + int.parse(parts[1]);
              final nowMinutes = now.hour * 60 + now.minute;
              return depMinutes >= nowMinutes;
            }).toList()
          : trains;

      notifier.setSearchResults(filtered);

      // 열차조회 탭으로 이동
      widget.onTabChange?.call(1);
    } catch (e) {
      notifier.setSearching(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('조회 실패: $e')),
        );
      }
    }
  }
}
