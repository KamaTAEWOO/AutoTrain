import 'package:flutter/material.dart';
import '../../core/theme/korail_colors.dart';
import 'station_picker_sheet.dart';

/// 코레일톡 스타일 역 선택 위젯 (큰 박스 + 바텀시트)
class StationSelector extends StatelessWidget {
  final String? departure;
  final String? arrival;
  final ValueChanged<String> onDepartureChanged;
  final ValueChanged<String> onArrivalChanged;
  final VoidCallback onSwap;

  const StationSelector({
    super.key,
    this.departure,
    this.arrival,
    required this.onDepartureChanged,
    required this.onArrivalChanged,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 출발역
        Expanded(
          child: _StationBox(
            label: '출발',
            station: departure,
            onTap: () async {
              final result = await StationPickerSheet.show(
                context,
                title: '출발역 선택',
                currentStation: departure,
              );
              if (result != null) {
                onDepartureChanged(result);
              }
            },
          ),
        ),

        // 교환 버튼
        GestureDetector(
          onTap: onSwap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
            child: const Icon(
              Icons.swap_horiz,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

        // 도착역
        Expanded(
          child: _StationBox(
            label: '도착',
            station: arrival,
            onTap: () async {
              final result = await StationPickerSheet.show(
                context,
                title: '도착역 선택',
                currentStation: arrival,
              );
              if (result != null) {
                onArrivalChanged(result);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// 역 선택 박스 (흰색 카드)
class _StationBox extends StatelessWidget {
  final String label;
  final String? station;
  final VoidCallback onTap;

  const _StationBox({
    required this.label,
    this.station,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: KorailColors.korailBlue.withAlpha(180),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              station?.isNotEmpty == true ? station! : '선택',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: station?.isNotEmpty == true
                    ? KorailColors.textPrimary
                    : KorailColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
