import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum BackupCadence { hourly, daily, weekly }

class BackupSnapshot {
  const BackupSnapshot({
    required this.snapshotId,
    required this.workspaceId,
    required this.createdAt,
    required this.checksum,
    required this.recordCount,
  });

  final String snapshotId;
  final String workspaceId;
  final DateTime createdAt;
  final String checksum;
  final int recordCount;
}

class RestoreRequest {
  const RestoreRequest({
    required this.workspaceId,
    required this.snapshotId,
    required this.requestedBy,
    required this.requestedAt,
  });

  final String workspaceId;
  final String snapshotId;
  final String requestedBy;
  final DateTime requestedAt;
}

class ExportRequest {
  const ExportRequest({
    required this.workspaceId,
    required this.requestedBy,
    required this.format,
    required this.requestedAt,
  });

  final String workspaceId;
  final String requestedBy;
  final String format;
  final DateTime requestedAt;
}

abstract interface class BackupGateway {
  Future<AppResult<BackupSnapshot>> createSnapshot({
    required String workspaceId,
  });
}

abstract interface class RestoreGateway {
  Future<AppResult<void>> restore(RestoreRequest request);
}

abstract interface class ExportGateway {
  Future<AppResult<String>> export(ExportRequest request);
}

class BackupRestoreExportPolicyContract {
  BackupRestoreExportPolicyContract({
    required BackupGateway backupGateway,
    required RestoreGateway restoreGateway,
    required ExportGateway exportGateway,
    required AppLogger logger,
  }) : _backupGateway = backupGateway,
       _restoreGateway = restoreGateway,
       _exportGateway = exportGateway,
       _logger = logger;

  final BackupGateway _backupGateway;
  final RestoreGateway _restoreGateway;
  final ExportGateway _exportGateway;
  final AppLogger _logger;

  AppResult<bool> isBackupDue({
    required BackupCadence cadence,
    required DateTime? lastCompletedAt,
    required DateTime now,
  }) {
    if (lastCompletedAt == null) {
      return const AppSuccess<bool>(true);
    }

    final interval = switch (cadence) {
      BackupCadence.hourly => const Duration(hours: 1),
      BackupCadence.daily => const Duration(days: 1),
      BackupCadence.weekly => const Duration(days: 7),
    };

    final due = now.isAfter(lastCompletedAt.add(interval));
    return AppSuccess<bool>(due);
  }

  Future<AppResult<BackupSnapshot>> runScheduledBackup({
    required String workspaceId,
    required BackupCadence cadence,
    required DateTime? lastCompletedAt,
    required DateTime now,
  }) async {
    if (workspaceId.trim().isEmpty) {
      return _backupFailure(
        code: 'backup_workspace_invalid',
        developerMessage: 'workspaceId cannot be empty for backup.',
        userMessage: 'Could not run backup right now.',
      );
    }

    final dueResult = isBackupDue(
      cadence: cadence,
      lastCompletedAt: lastCompletedAt,
      now: now,
    );
    if (dueResult is AppFailure<bool>) {
      return _backupFailure(
        code: dueResult.detail.code,
        developerMessage: dueResult.detail.developerMessage,
        userMessage: dueResult.detail.userMessage,
      );
    }

    final due = (dueResult as AppSuccess<bool>).value;
    if (!due) {
      return _backupFailure(
        code: 'backup_not_due',
        developerMessage: 'Backup cadence window has not elapsed yet.',
        userMessage: 'Backup will run on the next scheduled cycle.',
      );
    }

    final snapshotResult = await _backupGateway.createSnapshot(
      workspaceId: workspaceId,
    );
    if (snapshotResult is AppFailure<BackupSnapshot>) {
      _logger.warning(
        code: 'backup_job_failed',
        message: snapshotResult.detail.developerMessage,
        metadata: <String, Object?>{'workspaceId': workspaceId},
      );
      return snapshotResult;
    }

    final snapshot = (snapshotResult as AppSuccess<BackupSnapshot>).value;
    if (snapshot.checksum.trim().isEmpty || snapshot.recordCount < 0) {
      return _backupFailure(
        code: 'backup_integrity_invalid',
        developerMessage:
            'Snapshot checksum/recordCount failed integrity checks.',
        userMessage: 'Backup completed with integrity issues. Please retry.',
      );
    }

    _logger.info(
      code: 'backup_job_completed',
      message: 'Scheduled backup completed',
      metadata: <String, Object?>{
        'workspaceId': workspaceId,
        'snapshotId': snapshot.snapshotId,
        'recordCount': snapshot.recordCount,
      },
    );

    return AppSuccess<BackupSnapshot>(snapshot);
  }

  Future<AppResult<void>> executeRestoreDrill({
    required RestoreRequest request,
    required BackupSnapshot snapshot,
    required DateTime now,
  }) async {
    if (request.workspaceId.trim().isEmpty ||
        request.requestedBy.trim().isEmpty) {
      return _restoreFailure(
        code: 'restore_request_invalid',
        developerMessage:
            'Restore request must include workspace and requester.',
        userMessage: 'Could not run restore validation right now.',
      );
    }

    final snapshotAgeDays = now.difference(snapshot.createdAt).inDays;
    if (snapshotAgeDays > 180) {
      return _restoreFailure(
        code: 'restore_snapshot_stale',
        developerMessage: 'Snapshot is too old for restore drill validation.',
        userMessage: 'Selected backup is too old. Choose a newer backup.',
      );
    }

    if (snapshot.checksum.trim().isEmpty) {
      return _restoreFailure(
        code: 'restore_snapshot_integrity_invalid',
        developerMessage: 'Snapshot checksum is missing.',
        userMessage: 'Selected backup failed integrity validation.',
      );
    }

    final restoreResult = await _restoreGateway.restore(request);
    if (restoreResult is AppFailure<void>) {
      _logger.warning(
        code: 'restore_drill_failed',
        message: restoreResult.detail.developerMessage,
        metadata: <String, Object?>{
          'workspaceId': request.workspaceId,
          'snapshotId': request.snapshotId,
        },
      );
      return restoreResult;
    }

    _logger.info(
      code: 'restore_drill_passed',
      message: 'Restore drill validated successfully',
      metadata: <String, Object?>{
        'workspaceId': request.workspaceId,
        'snapshotId': request.snapshotId,
      },
    );
    return const AppSuccess<void>(null);
  }

  Future<AppResult<String>> exportUserData({
    required ExportRequest request,
    required bool hasAccess,
    required bool withinRateLimit,
  }) async {
    if (!hasAccess) {
      return _exportFailure(
        code: 'export_access_denied',
        developerMessage: 'Requester is not allowed to export workspace data.',
        userMessage: 'You are not allowed to export this data.',
      );
    }

    if (!withinRateLimit) {
      return _exportFailure(
        code: 'export_rate_limited',
        developerMessage: 'Export request rate limit exceeded.',
        userMessage: 'Too many export requests. Please retry later.',
      );
    }

    if (request.workspaceId.trim().isEmpty ||
        request.requestedBy.trim().isEmpty) {
      return _exportFailure(
        code: 'export_request_invalid',
        developerMessage:
            'Export request must include workspace and requester.',
        userMessage: 'Could not prepare export right now.',
      );
    }

    final result = await _exportGateway.export(request);
    if (result is AppFailure<String>) {
      _logger.warning(
        code: 'export_generation_failed',
        message: result.detail.developerMessage,
        metadata: <String, Object?>{
          'workspaceId': request.workspaceId,
          'format': request.format,
        },
      );
      return result;
    }

    final exportId = (result as AppSuccess<String>).value;
    _logger.info(
      code: 'export_generated',
      message: 'User export generated with access controls',
      metadata: <String, Object?>{
        'workspaceId': request.workspaceId,
        'requestedBy': request.requestedBy,
        'format': request.format,
        'exportId': exportId,
      },
    );
    return AppSuccess<String>(exportId);
  }

  AppFailure<BackupSnapshot> _backupFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<BackupSnapshot>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }

  AppFailure<void> _restoreFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<void>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }

  AppFailure<String> _exportFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<String>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}
