import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/korail_colors.dart';
import '../../data/models/train.dart';
import '../providers/search_provider.dart';
import '../providers/monitor_provider.dart';
import '../providers/log_provider.dart';
import '../widgets/train_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/log_tile.dart';
import '../widgets/train_loading_indicator.dart';

/// 열차 조회 결과 리스트 화면
///
/// 열차를 선택하고 자동 예약을 시작/중지하는 메인 화면.
class TrainListScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onTabChange;

  const TrainListScreen({super.key, this.onTabChange});

  @override
  ConsumerState<TrainListScreen> createState() => _TrainListScreenState();
}

class _TrainListScreenState extends ConsumerState<TrainListScreen> {
  String _selectedFilter = '전체';

  static const List<String> _filters = [
    '전체',
    'KTX',
    'KTX-산천',
    'KTX-청룡',
    'KTX-이음',
  ];

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final monitorState = ref.watch(monitorProvider);
    final logs = ref.watch(logProvider);
    final trains = searchState.searchResults;
    final filteredTrains = _applyFilter(trains);
    final theme = Theme.of(context);

    // 탭 전환 콜백 등록
    final monitorNotifier = ref.read(monitorProvider.notifier);
    monitorNotifier.onTabChange = widget.onTabChange;

    // 모니터 에러 메시지 SnackBar 표시
    ref.listen<MonitorState>(monitorProvider, (prev, next) {
      // 에러 메시지가 새로 설정된 경우
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: KorailColors.statusFailure,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      // 상태가 failure로 변경된 경우 (에러 메시지 없이 실패한 경우 포함)
      if (next.status == MonitorStatus.failure &&
          prev?.status != MonitorStatus.failure &&
          next.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('자동 예약 중 오류가 발생했습니다'),
            backgroundColor: KorailColors.statusFailure,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });

    final showBottomBar = searchState.selectedTrains.isNotEmpty ||
        monitorState.status != MonitorStatus.idle;

    return Scaffold(
      appBar: AppBar(
        title: trains.isNotEmpty
            ? Text(
                '${searchState.depStation} → ${searchState.arrStation}',
                style: const TextStyle(fontSize: 16),
              )
            : const Text('열차 조회'),
        bottom: trains.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    searchState.formattedDate,
                    style: TextStyle(
                      color: KorailColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: trains.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                // 필터 칩
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                      vertical: 8,
                    ),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = filter == _selectedFilter;
                      return ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedFilter = filter);
                        },
                        selectedColor: KorailColors.korailBlue,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : KorailColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? KorailColors.korailBlue
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 스크롤 가능한 메인 영역
                Expanded(
                  child: filteredTrains.isEmpty
                      ? Center(
                          child: Text(
                            '$_selectedFilter 열차가 없습니다',
                            style: TextStyle(
                              color: KorailColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            // 열차 리스트 헤더
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppTheme.spacingMd,
                                AppTheme.spacingSm,
                                AppTheme.spacingMd,
                                AppTheme.spacingXs,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${filteredTrains.length}건',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: KorailColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (searchState.selectedTrains.isNotEmpty)
                                    Text(
                                      '${searchState.selectedTrains.length}개 열차 선택',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: KorailColors.korailBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // 열차 카드 리스트
                            ...filteredTrains.map((train) {
                              final isSelected = searchState.selectedTrains
                                  .any((t) => t.trainNo == train.trainNo);
                              final isMonitoring =
                                  monitorState.status != MonitorStatus.idle;

                              return TrainCard(
                                train: train,
                                isSelected: isSelected,
                                onTap: isMonitoring
                                    ? null
                                    : () {
                                        ref
                                            .read(searchProvider.notifier)
                                            .toggleTrain(train);
                                      },
                              );
                            }),

                            // 조회 주기 설정 (열차 선택 후, 모니터링 전)
                            if (searchState.selectedTrains.isNotEmpty &&
                                monitorState.status == MonitorStatus.idle)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingMd,
                                ),
                                child: _buildControlPanel(
                                  context,
                                  searchState,
                                  monitorState,
                                  theme,
                                ),
                              ),

                            // 상태 + 통계 + 로그 (모니터링 중)
                            if (monitorState.status != MonitorStatus.idle)
                              Padding(
                                padding:
                                    const EdgeInsets.all(AppTheme.spacingMd),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildStatusStats(
                                        context, monitorState, theme),
                                    const SizedBox(height: AppTheme.spacingMd),
                                    _buildLogSection(context, logs, theme),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),

                // 하단 고정 자동예약 바
                if (showBottomBar)
                  _buildBottomActionBar(searchState, monitorState, theme),
              ],
            ),
    );
  }

  // ── 빈 상태 ──

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.train_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          const Text(
            '조회된 열차가 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            '홈 화면에서 열차를 조회해주세요',
            style: TextStyle(color: KorailColors.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          ElevatedButton.icon(
            onPressed: () => widget.onTabChange?.call(0),
            icon: const Icon(Icons.search),
            label: const Text('열차 조회하기'),
          ),
        ],
      ),
    );
  }

  // ── 자동 예약 컨트롤 패널 ──

  Widget _buildControlPanel(
    BuildContext context,
    SearchState searchState,
    MonitorState monitorState,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 자동 예약 토글
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '자동 예약',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: searchState.autoReserve,
                  onChanged: monitorState.status == MonitorStatus.idle
                      ? (v) =>
                          ref.read(searchProvider.notifier).setAutoReserve(v)
                      : null,
                  activeThumbColor: KorailColors.korailBlue,
                ),
              ],
            ),

            const Divider(),

            // 조회 주기 슬라이더
            Row(
              children: [
                Text(
                  '조회 주기',
                  style: theme.textTheme.bodyMedium,
                ),
                Expanded(
                  child: Slider(
                    value: searchState.refreshInterval.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 5,
                    label: '${searchState.refreshInterval}초',
                    activeColor: KorailColors.korailBlue,
                    onChanged: monitorState.status == MonitorStatus.idle
                        ? (v) => ref
                            .read(searchProvider.notifier)
                            .setRefreshInterval(v.toInt())
                        : null,
                  ),
                ),
                Text(
                  '${searchState.refreshInterval}초',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 상태 + 통계 ──

  Widget _buildStatusStats(
    BuildContext context,
    MonitorState monitorState,
    ThemeData theme,
  ) {
    final lastTime = monitorState.lastSearchTime;
    final lastTimeStr = lastTime != null
        ? '${lastTime.hour.toString().padLeft(2, '0')}:'
            '${lastTime.minute.toString().padLeft(2, '0')}:'
            '${lastTime.second.toString().padLeft(2, '0')}'
        : '--:--:--';

    final isAnimating = monitorState.status == MonitorStatus.searching ||
        monitorState.status == MonitorStatus.reserving;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: BorderSide(
          color: _getStatusBorderColor(monitorState.status),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                StatusBadge(status: monitorState.status),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${monitorState.searchCount}회',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      lastTimeStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KorailColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isAnimating) ...[
              const SizedBox(height: 8),
              TrainLoadingIndicator(
                width: double.infinity,
                height: 36,
                color: _getStatusBorderColor(monitorState.status),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 실시간 로그 ──

  Widget _buildLogSection(
    BuildContext context,
    List logs,
    ThemeData theme,
  ) {
    final displayLogs = logs.length > 100 ? logs.sublist(0, 100) : logs;

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              '실시간 로그',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Text('${logs.length}건'),
          ),
          const Divider(height: 1),
          if (displayLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Text(
                '아직 로그가 없습니다',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: KorailColors.textSecondary,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayLogs.length.clamp(0, 50),
              itemBuilder: (context, index) {
                return LogTile(log: displayLogs[index]);
              },
            ),
        ],
      ),
    );
  }

  // ── 하단 고정 자동예약 바 ──

  Widget _buildBottomActionBar(
    SearchState searchState,
    MonitorState monitorState,
    ThemeData theme,
  ) {
    final status = monitorState.status;
    final isMonitoring = status == MonitorStatus.searching ||
        status == MonitorStatus.found ||
        status == MonitorStatus.reserving;
    final isFinished =
        status == MonitorStatus.success || status == MonitorStatus.failure;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 모니터링 중 상태 표시
              if (isMonitoring) ...[
                TrainLoadingIndicator(
                  width: double.infinity,
                  height: 28,
                  color: KorailColors.statusSearching,
                ),
                const SizedBox(height: 4),
                Text(
                  '${monitorState.targetTrainNos.join(", ")} 좌석 확인 중... (${monitorState.searchCount}회)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KorailColors.statusSearching,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              // 선택 열차 정보 (idle 상태일 때)
              if (!isMonitoring &&
                  !isFinished &&
                  searchState.selectedTrains.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.train,
                        size: 16, color: KorailColors.korailBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        searchState.selectedTrains
                            .map((t) => '${t.trainNo} ${t.depTime}→${t.arrTime}')
                            .join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // 액션 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _buildBottomButton(
                    searchState, monitorState, isMonitoring, isFinished),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(
    SearchState searchState,
    MonitorState monitorState,
    bool isMonitoring,
    bool isFinished,
  ) {
    if (isMonitoring) {
      return OutlinedButton.icon(
        onPressed: () {
          ref.read(monitorProvider.notifier).stopMonitoring();
        },
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('자동 예약 중지',
            style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: KorailColors.statusFailure,
          side: const BorderSide(color: KorailColors.statusFailure),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
        ),
      );
    }

    if (isFinished) {
      return ElevatedButton.icon(
        onPressed: () {
          ref.read(monitorProvider.notifier).retry();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('다시 시작',
            style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    return ElevatedButton.icon(
      onPressed:
          searchState.canAutoReserve ? () => _startAutoReserve() : null,
      icon: const Icon(Icons.autorenew),
      label: const Text('자동 예약 시작',
          style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // ── 자동 예약 시작 ──

  void _startAutoReserve() {
    final searchState = ref.read(searchProvider);
    final condition = searchState.toSearchCondition();

    final monitorNotifier = ref.read(monitorProvider.notifier);
    monitorNotifier.onTabChange = widget.onTabChange;
    monitorNotifier.startMonitoring(
      condition,
      targetTrains: searchState.selectedTrains,
    );
  }

  // ── 유틸 ──

  List<Train> _applyFilter(List<Train> trains) {
    if (_selectedFilter == '전체') return trains;
    return trains.where((t) => t.trainType == _selectedFilter).toList();
  }

  Color _getStatusBorderColor(MonitorStatus status) {
    switch (status) {
      case MonitorStatus.idle:
        return Colors.grey.shade300;
      case MonitorStatus.searching:
        return KorailColors.statusSearching;
      case MonitorStatus.found:
        return KorailColors.statusFound;
      case MonitorStatus.reserving:
        return KorailColors.statusReserving;
      case MonitorStatus.success:
        return KorailColors.statusSuccess;
      case MonitorStatus.failure:
        return KorailColors.statusFailure;
    }
  }
}
