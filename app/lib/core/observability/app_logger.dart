import 'package:thrive_app/core/observability/log_event.dart';

abstract interface class AppLogger {
  void info({
    required String code,
    required String message,
    Map<String, Object?> metadata,
  });

  void warning({
    required String code,
    required String message,
    Map<String, Object?> metadata,
  });

  void error({
    required String code,
    required String message,
    Map<String, Object?> metadata,
  });
}

class InMemoryAppLogger implements AppLogger {
  final List<LogEvent> _events = [];

  List<LogEvent> get events => List.unmodifiable(_events);

  @override
  void error({
    required String code,
    required String message,
    Map<String, Object?> metadata = const {},
  }) {
    _events.add(
      LogEvent(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        code: code,
        message: message,
        metadata: Map<String, Object?>.unmodifiable(metadata),
      ),
    );
  }

  @override
  void info({
    required String code,
    required String message,
    Map<String, Object?> metadata = const {},
  }) {
    _events.add(
      LogEvent(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        code: code,
        message: message,
        metadata: Map<String, Object?>.unmodifiable(metadata),
      ),
    );
  }

  @override
  void warning({
    required String code,
    required String message,
    Map<String, Object?> metadata = const {},
  }) {
    _events.add(
      LogEvent(
        timestamp: DateTime.now(),
        level: LogLevel.warning,
        code: code,
        message: message,
        metadata: Map<String, Object?>.unmodifiable(metadata),
      ),
    );
  }
}
