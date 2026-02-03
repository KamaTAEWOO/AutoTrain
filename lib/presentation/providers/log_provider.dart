import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/log_entry.dart';

/// 최대 로그 보관 건수
const int maxLogEntries = 500;

/// 로그 StateNotifier
class LogNotifier extends StateNotifier<List<LogEntry>> {
  LogNotifier() : super([]);

  /// 새 로그 항목을 추가한다.
  void addLog({
    required String action,
    required String result,
    required String detail,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      action: action,
      result: result,
      detail: detail,
    );

    // 최신 로그가 앞에 오도록 역순으로 추가
    final newLogs = [entry, ...state];

    // 최대 건수 초과 시 오래된 항목 제거
    if (newLogs.length > maxLogEntries) {
      state = newLogs.sublist(0, maxLogEntries);
    } else {
      state = newLogs;
    }
  }

  /// 전체 로그 초기화
  void clear() {
    state = [];
  }
}

/// 로그 Provider
final logProvider =
    StateNotifierProvider<LogNotifier, List<LogEntry>>((ref) {
  return LogNotifier();
});
