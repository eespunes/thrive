import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

final appLoggerProvider = Provider<AppLogger>(
  (ref) => throw StateError(
    'appLoggerProvider must be overridden at app bootstrap.',
  ),
  name: 'appLoggerProvider',
);
