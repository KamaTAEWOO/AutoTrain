import 'package:flutter/material.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/korail_colors.dart';

/// 상태 배지 크기
enum StatusBadgeSize { small, medium, large }

/// 상태별 색상+아이콘+텍스트 배지 위젯
class StatusBadge extends StatelessWidget {
  final MonitorStatus status;
  final StatusBadgeSize size;

  const StatusBadge({
    super.key,
    required this.status,
    this.size = StatusBadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final iconSize = _iconSize;
    final textStyle = _textStyle(context);

    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: iconSize),
          const SizedBox(width: AppTheme.spacingXs),
          Text(
            _statusLabel(status),
            style: textStyle?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  double get _iconSize {
    switch (size) {
      case StatusBadgeSize.small:
        return 14;
      case StatusBadgeSize.medium:
        return 18;
      case StatusBadgeSize.large:
        return 24;
    }
  }

  TextStyle? _textStyle(BuildContext context) {
    switch (size) {
      case StatusBadgeSize.small:
        return Theme.of(context).textTheme.labelSmall;
      case StatusBadgeSize.medium:
        return Theme.of(context).textTheme.labelLarge;
      case StatusBadgeSize.large:
        return Theme.of(context).textTheme.titleMedium;
    }
  }

  static Color _statusColor(MonitorStatus status) {
    switch (status) {
      case MonitorStatus.idle:
        return KorailColors.statusIdle;
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

  static IconData _statusIcon(MonitorStatus status) {
    switch (status) {
      case MonitorStatus.idle:
        return Icons.hourglass_empty;
      case MonitorStatus.searching:
        return Icons.search;
      case MonitorStatus.found:
        return Icons.check_circle;
      case MonitorStatus.reserving:
        return Icons.sync;
      case MonitorStatus.success:
        return Icons.done_all;
      case MonitorStatus.failure:
        return Icons.error;
    }
  }

  static String _statusLabel(MonitorStatus status) {
    switch (status) {
      case MonitorStatus.idle:
        return '대기 중';
      case MonitorStatus.searching:
        return '조회 중...';
      case MonitorStatus.found:
        return '열차 발견';
      case MonitorStatus.reserving:
        return '예약 중...';
      case MonitorStatus.success:
        return '예약 성공';
      case MonitorStatus.failure:
        return '예약 실패';
    }
  }
}
