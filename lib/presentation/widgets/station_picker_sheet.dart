import 'package:flutter/material.dart';
import '../../core/constants/rail_type.dart';
import '../../core/constants/stations.dart';
import '../../core/theme/korail_colors.dart';
import '../../core/theme/rail_colors.dart';
import '../../core/theme/app_theme.dart';

/// 역 선택 바텀시트
class StationPickerSheet extends StatefulWidget {
  final String title;
  final String? currentStation;
  final RailType railType;

  const StationPickerSheet({
    super.key,
    required this.title,
    this.currentStation,
    this.railType = RailType.ktx,
  });

  /// 바텀시트를 열어 역을 선택한다.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? currentStation,
    RailType railType = RailType.ktx,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StationPickerSheet(
        title: title,
        currentStation: currentStation,
        railType: railType,
      ),
    );
  }

  @override
  State<StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<StationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _filteredStations;
  late Color _brandColor;

  @override
  void initState() {
    super.initState();
    _filteredStations = Stations.forType(widget.railType);
    _brandColor = RailColors.primary(widget.railType);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredStations = Stations.filter(query, type: widget.railType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            children: [
              // 핸들
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 타이틀
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // 검색 필드
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '역 이름 검색',
                    prefixIcon:
                        const Icon(Icons.search, color: KorailColors.gray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // 역 리스트
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredStations.length,
                  itemBuilder: (context, index) {
                    final station = _filteredStations[index];
                    final isSelected = station == widget.currentStation;

                    return ListTile(
                      title: Text(
                        station,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? _brandColor
                              : KorailColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: _brandColor)
                          : null,
                      onTap: () => Navigator.pop(context, station),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
