import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/log_entry.dart';

/// 로그 항목 타일 위젯
class LogTile extends StatelessWidget {
  final LogEntry log;

  const LogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      child: Row(
        children: [
          // 왼쪽 색상 바
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: _actionColor(log.action),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),

          // 시간
          SizedBox(
            width: 72,
            child: Text(
              _formatTime(log.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),

          // 결과 아이콘
          _buildResultIcon(log.result),
          const SizedBox(width: AppTheme.spacingSm),

          // 상세 내용
          Expanded(
            child: Text(
              log.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// 시간 포맷 (HH:mm:ss)
  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// 액션별 색상
  Color _actionColor(String action) {
    switch (action) {
      case 'search':
        return Colors.blue.shade400;
      case 'reserve':
        return Colors.orange.shade400;
      case 'login':
        return Colors.grey.shade400;
      case 'error':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  /// 결과 아이콘
  Widget _buildResultIcon(String result) {
    switch (result) {
      case 'success':
        return Icon(Icons.check, size: 12, color: Colors.green.shade600);
      case 'failure':
        return Icon(Icons.close, size: 12, color: Colors.red.shade600);
      case 'no_seats':
        return Icon(Icons.remove, size: 12, color: Colors.grey.shade500);
      default:
        return Icon(Icons.info_outline, size: 12, color: Colors.blue.shade400);
    }
  }
}
