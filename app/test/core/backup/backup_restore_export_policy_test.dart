import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/backup/backup_restore_export_policy.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('runs scheduled backup when cadence is due', () async {
    final contract = BackupRestoreExportPolicyContract(
      backupGateway: _BackupGatewayStub(),
      restoreGateway: _RestoreGatewayStub(),
      exportGateway: _ExportGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.runScheduledBackup(
      workspaceId: 'w-1',
      cadence: BackupCadence.daily,
      lastCompletedAt: DateTime.utc(2030, 1, 1),
      now: DateTime.utc(2030, 1, 3),
    );

    expect(result, isA<AppSuccess<BackupSnapshot>>());
    expect((result as AppSuccess<BackupSnapshot>).value.snapshotId, 'snap-1');
  });

  test('fails backup when cadence is not due', () async {
    final contract = BackupRestoreExportPolicyContract(
      backupGateway: _BackupGatewayStub(),
      restoreGateway: _RestoreGatewayStub(),
      exportGateway: _ExportGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.runScheduledBackup(
      workspaceId: 'w-1',
      cadence: BackupCadence.daily,
      lastCompletedAt: DateTime.utc(2030, 1, 2, 12),
      now: DateTime.utc(2030, 1, 3, 0),
    );

    expect(result, isA<AppFailure<BackupSnapshot>>());
    expect(
      (result as AppFailure<BackupSnapshot>).detail.code,
      'backup_not_due',
    );
  });

  test('restore drill fails for stale snapshot', () async {
    final contract = BackupRestoreExportPolicyContract(
      backupGateway: _BackupGatewayStub(),
      restoreGateway: _RestoreGatewayStub(),
      exportGateway: _ExportGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.executeRestoreDrill(
      request: RestoreRequest(
        workspaceId: 'w-1',
        snapshotId: 'snap-old',
        requestedBy: 'owner-1',
        requestedAt: DateTime.utc(2030, 1, 1),
      ),
      snapshot: BackupSnapshot(
        snapshotId: 'snap-old',
        workspaceId: 'w-1',
        createdAt: DateTime.utc(2028, 1, 1),
        checksum: 'abc123',
        recordCount: 10,
      ),
      now: DateTime.utc(2030, 1, 1),
    );

    expect(result, isA<AppFailure<void>>());
    expect((result as AppFailure<void>).detail.code, 'restore_snapshot_stale');
  });

  test('export enforces access controls', () async {
    final contract = BackupRestoreExportPolicyContract(
      backupGateway: _BackupGatewayStub(),
      restoreGateway: _RestoreGatewayStub(),
      exportGateway: _ExportGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.exportUserData(
      request: ExportRequest(
        workspaceId: 'w-1',
        requestedBy: 'member-2',
        format: 'json',
        requestedAt: DateTime.utc(2030, 1, 1),
      ),
      hasAccess: false,
      withinRateLimit: true,
    );

    expect(result, isA<AppFailure<String>>());
    expect((result as AppFailure<String>).detail.code, 'export_access_denied');
  });

  test('export succeeds for authorized request', () async {
    final contract = BackupRestoreExportPolicyContract(
      backupGateway: _BackupGatewayStub(),
      restoreGateway: _RestoreGatewayStub(),
      exportGateway: _ExportGatewayStub(),
      logger: InMemoryAppLogger(),
    );

    final result = await contract.exportUserData(
      request: ExportRequest(
        workspaceId: 'w-1',
        requestedBy: 'owner-1',
        format: 'json',
        requestedAt: DateTime.utc(2030, 1, 1),
      ),
      hasAccess: true,
      withinRateLimit: true,
    );

    expect(result, isA<AppSuccess<String>>());
    expect((result as AppSuccess<String>).value, 'export-1');
  });
}

class _BackupGatewayStub implements BackupGateway {
  @override
  Future<AppResult<BackupSnapshot>> createSnapshot({
    required String workspaceId,
  }) async {
    return AppSuccess<BackupSnapshot>(
      BackupSnapshot(
        snapshotId: 'snap-1',
        workspaceId: workspaceId,
        createdAt: DateTime.utc(2030, 1, 1),
        checksum: 'checksum-1',
        recordCount: 120,
      ),
    );
  }
}

class _RestoreGatewayStub implements RestoreGateway {
  @override
  Future<AppResult<void>> restore(RestoreRequest request) async =>
      const AppSuccess<void>(null);
}

class _ExportGatewayStub implements ExportGateway {
  @override
  Future<AppResult<String>> export(ExportRequest request) async =>
      const AppSuccess<String>('export-1');
}
