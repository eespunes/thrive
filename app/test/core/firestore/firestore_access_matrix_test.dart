import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/firestore/firestore_access_matrix.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('allows protected doc read when owner role is authorized', () {
    final logger = InMemoryAppLogger();
    final matrix = FirestoreSecurityAccessMatrix(logger: logger);

    final result = matrix.authorize(
      const FirestoreAccessRequest(
        workspaceId: 'workspace-1',
        role: WorkspaceRole.owner,
        resource: FirestoreResource.auditLog,
        operation: FirestoreOperation.read,
      ),
    );

    expect(result, isA<AppSuccess<void>>());
    expect(
      logger.events.map((event) => event.code),
      contains('firestore_access_allowed'),
    );
  });

  test('denies unknown role by least privilege default', () {
    final logger = InMemoryAppLogger();
    final matrix = FirestoreSecurityAccessMatrix(logger: logger);

    final result = matrix.authorize(
      const FirestoreAccessRequest(
        workspaceId: 'workspace-1',
        role: WorkspaceRole.unknown,
        resource: FirestoreResource.transactions,
        operation: FirestoreOperation.read,
      ),
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'firestore_access_denied');
  });

  test('denies member write access to workspace settings', () {
    final logger = InMemoryAppLogger();
    final matrix = FirestoreSecurityAccessMatrix(logger: logger);

    final result = matrix.authorize(
      const FirestoreAccessRequest(
        workspaceId: 'workspace-1',
        role: WorkspaceRole.member,
        resource: FirestoreResource.workspaceSettings,
        operation: FirestoreOperation.write,
      ),
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'firestore_access_denied');
  });

  test('fails fast when workspace id is missing', () {
    final logger = InMemoryAppLogger();
    final matrix = FirestoreSecurityAccessMatrix(logger: logger);

    final result = matrix.authorize(
      const FirestoreAccessRequest(
        workspaceId: ' ',
        role: WorkspaceRole.owner,
        resource: FirestoreResource.workspaceProfile,
        operation: FirestoreOperation.read,
      ),
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'firestore_workspace_invalid');
  });
}
