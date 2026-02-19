enum LogLevel { info, warning, error }

class LogEvent {
  const LogEvent({
    required this.timestamp,
    required this.level,
    required this.code,
    required this.message,
    required this.metadata,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String code;
  final String message;
  final Map<String, Object?> metadata;
}
