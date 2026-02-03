import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/korail_colors.dart';
import '../../data/models/train.dart';

/// 코레일 스타일 열차 정보 카드 위젯
class TrainCard extends StatelessWidget {
  final Train train;
  final bool compact;
  final bool isSelected;
  final VoidCallback? onTap;

  const TrainCard({
    super.key,
    required this.train,
    this.compact = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.train, size: 16, color: KorailColors.korailBlue),
        const SizedBox(width: AppTheme.spacingSm),
        Text(
          train.trainNo,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Text(
          '${train.depStation} -> ${train.arrStation}',
          style: theme.textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          train.depTime,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: isSelected
            ? const BorderSide(color: KorailColors.korailBlue, width: 2)
            : BorderSide.none,
      ),
      color: isSelected
          ? KorailColors.korailBlue.withAlpha(10)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 열차 번호 + 종류
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
                  const Spacer(),
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle,
                        color: KorailColors.korailBlue,
                        size: 22,
                      ),
                    ),
                  if (train.formattedCharge != null)
                    Text(
                      train.formattedCharge!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: KorailColors.korailBlue,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // 구간 + 시간 타임라인
              Row(
                children: [
                  // 출발
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

                  // 화살표 + 소요시간
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        Text(
                          _calculateDuration(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KorailColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 도착
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

              const SizedBox(height: 10),

              // 좌석 상태
              Row(
                children: [
                  _buildSeatChip(
                    '일반실',
                    train.generalSeats,
                  ),
                  const SizedBox(width: 8),
                  _buildSeatChip(
                    '특실',
                    train.specialSeats,
                  ),
                ],
              ),
              // 운임 0원(ITX-마음 등)인 경우 운임 미정 안내
              if (train.adultCharge == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '운임 미정',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatChip(String label, bool? available) {
    // null = 미확인 (TAGO API), true = 있음, false = 없음
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final String text;

    if (available == null) {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      textColor = Colors.blue.shade600;
      text = '$label -';
    } else if (available) {
      bgColor = KorailColors.seatAvailable.withAlpha(20);
      borderColor = KorailColors.seatAvailable.withAlpha(80);
      textColor = KorailColors.seatAvailable;
      text = '$label O';
    } else {
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      textColor = KorailColors.gray;
      text = '$label X';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// 소요 시간 계산
  String _calculateDuration() {
    try {
      final depParts = train.depTime.split(':');
      final arrParts = train.arrTime.split(':');
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
}
