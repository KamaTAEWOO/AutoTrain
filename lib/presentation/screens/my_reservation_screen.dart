import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/korail_colors.dart';
import '../../data/models/reservation.dart';
import '../providers/reservation_provider.dart';
import '../providers/search_provider.dart';
import '../providers/log_provider.dart';
import '../providers/monitor_provider.dart';
import '../widgets/train_card.dart';
import '../widgets/log_tile.dart';

/// 내 예약 결과 화면
class MyReservationScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onTabChange;

  const MyReservationScreen({super.key, this.onTabChange});

  @override
  ConsumerState<MyReservationScreen> createState() =>
      _MyReservationScreenState();
}

class _MyReservationScreenState extends ConsumerState<MyReservationScreen> {
  @override
  void initState() {
    super.initState();
    // 탭 진입 시 자동으로 예약 목록 조회
    Future.microtask(
      () => ref.read(reservationProvider.notifier).fetchReservations(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservationState = ref.watch(reservationProvider);
    final logs = ref.watch(logProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 예약'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(reservationProvider.notifier).fetchReservations();
            },
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(context, ref, reservationState, logs),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ReservationState reservationState,
    List logs,
  ) {
    // 자동예약 결과가 있으면 기존 상세 화면 표시
    if (reservationState.hasResult && reservationState.reservation != null) {
      if (reservationState.isCancelled) {
        return _buildCancelledResult(context, ref, reservationState, logs);
      }
      final reservation = reservationState.reservation!;
      if (reservation.isSuccess) {
        return _buildSuccessResult(
            context, ref, reservation, reservationState, logs);
      } else {
        return _buildFailureResult(context, ref, reservation, logs);
      }
    }

    // 예약 목록 표시
    return _buildReservationList(context, ref, reservationState);
  }

  // ── 예약 목록 ──

  Widget _buildReservationList(
    BuildContext context,
    WidgetRef ref,
    ReservationState reservationState,
  ) {
    final theme = Theme.of(context);

    if (reservationState.isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reservationState.listError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                reservationState.listError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: KorailColors.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(reservationProvider.notifier).fetchReservations();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (reservationState.reservations.isEmpty) {
      return _buildEmptyState(context);
    }

    // 예약 목록이 있는 경우 - 스크롤 가능 리스트
    final reservations = reservationState.reservations;
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(reservationProvider.notifier).fetchReservations();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        itemCount: reservations.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: Text(
                '${reservations.length}건의 예약',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KorailColors.textSecondary,
                ),
              ),
            );
          }
          final rsv = reservations[index - 1];
          return _buildReservationCard(context, ref, theme, rsv);
        },
      ),
    );
  }

  /// 예약 카드 (목록용)
  Widget _buildReservationCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Reservation rsv,
  ) {
    final train = rsv.train;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: KorailColors.korailBlue, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 예약번호 + 상태
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KorailColors.statusSuccess,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '예약완료',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '예약번호 ${rsv.reservationId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KorailColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 복사 버튼
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: rsv.reservationId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('예약번호가 복사되었습니다')),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16, color: KorailColors.korailBlue),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 열차 종류 + 번호
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KorailColors.korailBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    train.trainType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  train.trainNo,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: KorailColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 출발 → 도착 타임라인
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      train.depTime,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      train.depStation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KorailColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: Colors.grey.shade300),
                          ),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                      Text(
                        _calculateDuration(train.depTime, train.arrTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KorailColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      train.arrTime,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      train.arrStation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KorailColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 결제 기한 표시
            if (rsv.paymentDeadline != null &&
                rsv.paymentDeadline!.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.red.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '결제기한: ${rsv.paymentDeadline}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _confirmCancelFromList(context, ref, rsv.reservationId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KorailColors.statusFailure,
                      side: const BorderSide(color: KorailColors.statusFailure),
                    ),
                    child: const Text('예약 취소',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _launchKorailTalk(context),
                    child: const Text('결제하기',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 목록에서 예약 취소
  void _confirmCancelFromList(
      BuildContext context, WidgetRef ref, String reservationId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약 취소'),
        content: const Text('정말 예약을 취소하시겠습니까?\n취소 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('돌아가기'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final notifier = ref.read(reservationProvider.notifier);
              final success = await notifier.cancelReservation(reservationId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? '예약이 취소되었습니다' : '예약 취소에 실패했습니다',
                    ),
                  ),
                );
              }
            },
            child: const Text(
              '취소하기',
              style: TextStyle(color: KorailColors.statusFailure),
            ),
          ),
        ],
      ),
    );
  }

  /// 결과 없음
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          const Text(
            '아직 예약 내역이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            '자동 예약을 시작해보세요',
            style: TextStyle(color: KorailColors.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          ElevatedButton.icon(
            onPressed: () => widget.onTabChange?.call(0),
            icon: const Icon(Icons.home),
            label: const Text('홈으로 이동'),
          ),
        ],
      ),
    );
  }

  /// 예약 성공
  Widget _buildSuccessResult(
    BuildContext context,
    WidgetRef ref,
    dynamic reservation,
    ReservationState reservationState,
    List logs,
  ) {
    final theme = Theme.of(context);
    final searchState = ref.read(searchProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // [1] 성공 헤더 + 예약번호
          _buildSuccessHeader(theme, reservation),

          const SizedBox(height: AppTheme.spacingMd),

          // [2] 열차 상세 정보 카드
          _buildDetailCard(theme, reservation, searchState),

          const SizedBox(height: AppTheme.spacingMd),

          // [3] 결제 긴급 안내
          _buildPaymentUrgency(theme),

          const SizedBox(height: AppTheme.spacingMd),

          // [4] 결제 방법 안내
          _buildPaymentMethods(context, theme),

          const SizedBox(height: AppTheme.spacingMd),

          // [5] 액션 버튼
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: reservation.reservationId),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('예약번호가 복사되었습니다')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('예약번호 복사'),
          ),
          const SizedBox(height: AppTheme.spacingSm),

          // 예약 취소 버튼
          OutlinedButton.icon(
            onPressed: reservationState.isCancelling
                ? null
                : () => _confirmCancel(context, ref, reservation.reservationId),
            style: OutlinedButton.styleFrom(
              foregroundColor: KorailColors.statusFailure,
              side: const BorderSide(color: KorailColors.statusFailure),
            ),
            icon: reservationState.isCancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(
              reservationState.isCancelling ? '취소 중...' : '예약 취소',
            ),
          ),

          // 취소 에러 표시
          if (reservationState.cancelError != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              reservationState.cancelError!,
              style:
                  TextStyle(color: KorailColors.statusFailure, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: AppTheme.spacingSm),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(reservationProvider.notifier).reset();
              ref.read(monitorProvider.notifier).reset();
              widget.onTabChange?.call(0);
            },
            icon: const Icon(Icons.search),
            label: const Text('새로운 조회'),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // [6] 전체 로그
          _buildLogExpansion(context, logs),
        ],
      ),
    );
  }

  /// [1] 성공 헤더 카드 (배지 + 예약번호)
  Widget _buildSuccessHeader(ThemeData theme, dynamic reservation) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          border: const Border(
            left: BorderSide(
              color: KorailColors.statusSuccess,
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: KorailColors.statusSuccess,
                    size: 32,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Text(
                    '예약 성공',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: KorailColors.statusSuccess,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                '예약번호',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KorailColors.textSecondary,
                ),
              ),
              SelectableText(
                reservation.reservationId,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [2] 열차 상세 정보 카드
  Widget _buildDetailCard(
    ThemeData theme,
    dynamic reservation,
    SearchState searchState,
  ) {
    final train = reservation.train;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final date = searchState.selectedDate;
    final weekday = weekdays[date.weekday - 1];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 열차 종류 배지 + 열차번호
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KorailColors.korailBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    train.trainType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '열차 ${train.trainNo}호',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // 탑승 날짜
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: KorailColors.korailBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  '${searchState.formattedDate} ($weekday)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // 출발 → 도착 타임라인
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      train.depTime,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      train.depStation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KorailColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: Colors.grey.shade300),
                          ),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                      Text(
                        _calculateDuration(train.depTime, train.arrTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KorailColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      train.arrTime,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      train.arrStation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KorailColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: AppTheme.spacingLg),

            // 좌석유형 | 인원 | 운임
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    theme,
                    '좌석유형',
                    searchState.seatTypeLabel,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    theme,
                    '인원',
                    searchState.passengerLabel,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    theme,
                    '운임',
                    train.formattedCharge ?? '-',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// InfoGrid 개별 항목
  Widget _buildInfoItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: KorailColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// [3] 결제 긴급 안내 배너
  Widget _buildPaymentUrgency(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(
          left: BorderSide(color: Colors.red.shade400, width: 4),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timer, color: Colors.red.shade700, size: 24),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '10분 내 결제가 필요합니다!',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '미결제 시 예약이 자동 취소됩니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [4] 결제 방법 안내 카드
  Widget _buildPaymentMethods(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: KorailColors.korailBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '결제 방법 안내',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchKorailTalk(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('코레일톡 앱에서 결제하기'),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildPaymentMethodTile(
              theme,
              icon: Icons.phone_android,
              title: '코레일톡 앱',
              subtitle: '앱 실행 → 승차권 → 예약확인/결제',
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _buildPaymentMethodTile(
              theme,
              icon: Icons.language,
              title: '코레일 웹사이트',
              subtitle:
                  'www.letskorail.com → 로그인 → 마이페이지 → 예약확인/결제',
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _buildPaymentMethodTile(
              theme,
              icon: Icons.store,
              title: '역 창구',
              subtitle: '가까운 역 창구에서 예약번호로 결제',
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _buildPaymentMethodTile(
              theme,
              icon: Icons.call,
              title: 'ARS 전화 결제',
              subtitle: '1544-7788 / 1588-7788',
            ),
          ],
        ),
      ),
    );
  }

  /// 결제 방법 개별 타일
  Widget _buildPaymentMethodTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: KorailColors.korailBlue, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KorailColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 코레일톡 앱 실행 (미설치 시 스토어 안내)
  Future<void> _launchKorailTalk(BuildContext context) async {
    final korailAppUri = Uri.parse('korailtalktalk://');

    if (await canLaunchUrl(korailAppUri)) {
      await launchUrl(korailAppUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri storeUri;
      if (Platform.isIOS) {
        storeUri = Uri.parse(
          'https://apps.apple.com/kr/app/%EC%BD%94%EB%A0%88%EC%9D%BC%ED%86%A1/id588665498',
        );
      } else {
        storeUri = Uri.parse('market://details?id=com.korail.talk');
      }

      if (await canLaunchUrl(storeUri)) {
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      } else {
        final webStoreUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.korail.talk',
        );
        await launchUrl(webStoreUri, mode: LaunchMode.externalApplication);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('코레일톡 앱이 설치되어 있지 않아 스토어로 이동합니다.'),
          ),
        );
      }
    }
  }

  /// 소요 시간 계산
  String _calculateDuration(String depTime, String arrTime) {
    try {
      final depParts = depTime.split(':');
      final arrParts = arrTime.split(':');
      final depMinutes =
          int.parse(depParts[0]) * 60 + int.parse(depParts[1]);
      final arrMinutes =
          int.parse(arrParts[0]) * 60 + int.parse(arrParts[1]);
      final diff = arrMinutes - depMinutes;
      if (diff <= 0) return '';
      final hours = diff ~/ 60;
      final minutes = diff % 60;
      if (hours > 0 && minutes > 0) {
        return '${hours}h${minutes}m';
      } else if (hours > 0) {
        return '${hours}h';
      } else {
        return '${minutes}m';
      }
    } catch (_) {
      return '';
    }
  }

  /// 예약 실패
  Widget _buildFailureResult(
    BuildContext context,
    WidgetRef ref,
    dynamic reservation,
    List logs,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Container(
              decoration: BoxDecoration(
                border: const Border(
                  left: BorderSide(
                    color: KorailColors.statusFailure,
                    width: 4,
                  ),
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel,
                          color: KorailColors.statusFailure,
                          size: 32,
                        ),
                        SizedBox(width: AppTheme.spacingSm),
                        Text(
                          '예약 실패',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: KorailColors.statusFailure,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '실패 사유',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXs),
                          Text(
                            reservation.message,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    const Divider(),
                    TrainCard(train: reservation.train, compact: true),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          ElevatedButton.icon(
            onPressed: () {
              ref.read(monitorProvider.notifier).retry();
              widget.onTabChange?.call(0);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('재시도'),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(reservationProvider.notifier).reset();
              ref.read(monitorProvider.notifier).reset();
              widget.onTabChange?.call(0);
            },
            icon: const Icon(Icons.edit),
            label: const Text('조건 수정'),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          _buildLogExpansion(context, logs),
        ],
      ),
    );
  }

  /// 예약 취소 확인 다이얼로그
  void _confirmCancel(
      BuildContext context, WidgetRef ref, String reservationId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약 취소'),
        content: const Text('정말 예약을 취소하시겠습니까?\n취소 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('돌아가기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(reservationProvider.notifier)
                  .cancelReservation(reservationId);
            },
            child: const Text(
              '취소하기',
              style: TextStyle(color: KorailColors.statusFailure),
            ),
          ),
        ],
      ),
    );
  }

  /// 예약 취소 완료 화면
  Widget _buildCancelledResult(
    BuildContext context,
    WidgetRef ref,
    ReservationState reservationState,
    List logs,
  ) {
    final theme = Theme.of(context);
    final reservation = reservationState.reservation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Container(
              decoration: BoxDecoration(
                border: const Border(
                  left: BorderSide(
                    color: Colors.orange,
                    width: 4,
                  ),
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel,
                          color: Colors.orange,
                          size: 32,
                        ),
                        SizedBox(width: AppTheme.spacingSm),
                        Text(
                          '예약 취소 완료',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (reservation != null) ...[
                      const SizedBox(height: AppTheme.spacingLg),
                      Text(
                        '예약번호',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KorailColors.textSecondary,
                        ),
                      ),
                      Text(
                        reservation.reservationId,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.lineThrough,
                          color: KorailColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      '예약이 정상적으로 취소되었습니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: KorailColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (reservation != null) ...[
            const SizedBox(height: AppTheme.spacingMd),
            Opacity(
              opacity: 0.5,
              child: TrainCard(train: reservation.train, compact: true),
            ),
          ],

          const SizedBox(height: AppTheme.spacingLg),

          ElevatedButton.icon(
            onPressed: () {
              ref.read(reservationProvider.notifier).reset();
              ref.read(monitorProvider.notifier).reset();
              widget.onTabChange?.call(0);
            },
            icon: const Icon(Icons.search),
            label: const Text('새로운 조회'),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          _buildLogExpansion(context, logs),
        ],
      ),
    );
  }

  /// 전체 로그 ExpansionTile
  Widget _buildLogExpansion(BuildContext context, List logs) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.list_alt),
        title: const Text('전체 로그'),
        subtitle: Text('${logs.length}건'),
        initiallyExpanded: false,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: logs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Text(
                      '로그가 없습니다',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return LogTile(log: logs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
