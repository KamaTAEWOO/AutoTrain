/// 로그 항목 모델
class LogEntry {
  final DateTime timestamp;
  final String action;
  final String result;
  final String detail;

  const LogEntry({
    required this.timestamp,
    required this.action,
    required this.result,
    required this.detail,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: json['action'] as String,
      result: json['result'] as String,
      detail: json['detail'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'result': result,
      'detail': detail,
    };
  }

  @override
  String toString() {
    return 'LogEntry($timestamp, $action, $result)';
  }
}
