import 'package:flutter/material.dart';
import '../../core/theme/korail_colors.dart';

/// 코레일톡 스타일 수평 날짜 선택 위젯
class HorizontalDatePicker extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int dayCount;

  const HorizontalDatePicker({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.dayCount = 7,
  });

  @override
  State<HorizontalDatePicker> createState() => _HorizontalDatePickerState();
}

class _HorizontalDatePickerState extends State<HorizontalDatePicker> {
  late ScrollController _scrollController;
  late DateTime _baseDate;

  static const double _itemWidth = 56.0;
  static const double _itemSpacing = 8.0;

  @override
  void initState() {
    super.initState();
    _baseDate = DateUtils.dateOnly(DateTime.now());
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(HorizontalDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final daysDiff =
        DateUtils.dateOnly(widget.selectedDate).difference(_baseDate).inDays;
    if (daysDiff < 0 || daysDiff >= widget.dayCount) return;

    final offset = daysDiff * (_itemWidth + _itemSpacing);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = (offset - 80).clamp(0.0, maxScroll);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.dayCount,
        separatorBuilder: (_, __) =>
            const SizedBox(width: _itemSpacing),
        itemBuilder: (context, index) {
          final date = _baseDate.add(Duration(days: index));
          final isSelected =
              DateUtils.dateOnly(widget.selectedDate) == DateUtils.dateOnly(date);
          final isToday = DateUtils.dateOnly(date) == _baseDate;
          final isSunday = date.weekday == DateTime.sunday;
          final isSaturday = date.weekday == DateTime.saturday;

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: Container(
              width: _itemWidth,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayLabel(date.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? KorailColors.korailBlue
                          : isSunday
                              ? Colors.red.shade200
                              : isSaturday
                                  ? Colors.blue.shade200
                                  : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? KorailColors.korailBlue
                          : Colors.white,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? KorailColors.korailBlue
                            : KorailColors.skyBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['', '월', '화', '수', '목', '금', '토', '일'];
    return labels[weekday];
  }
}
