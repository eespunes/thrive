import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum WorkspaceRole { owner, admin, member, localProfile, unknown }

enum FirestoreResource {
  workspaceProfile,
  workspaceSettings,
  memberProfiles,
  transactions,
  auditLog,
}

enum FirestoreOperation { read, write, delete }

class FirestoreAccessRequest {
  const FirestoreAccessRequest({
    required this.workspaceId,
    required this.role,
    required this.resource,
    required this.operation,
  });

  final String workspaceId;
  final WorkspaceRole role;
  final FirestoreResource resource;
  final FirestoreOperation operation;
}

class FirestoreSecurityAccessMatrix {
  FirestoreSecurityAccessMatrix({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<void> authorize(FirestoreAccessRequest request) {
    if (request.workspaceId.trim().isEmpty) {
      return _deny(
        request: request,
        code: 'firestore_workspace_invalid',
        developerMessage: 'workspaceId cannot be empty for Firestore access.',
        userMessage: 'Could not validate access for this workspace.',
      );
    }

    final allowedOperations =
        _rules[request.role]?[request.resource] ?? const <FirestoreOperation>{};
    if (!allowedOperations.contains(request.operation)) {
      return _deny(
        request: request,
        code: 'firestore_access_denied',
        developerMessage:
            'Access denied for role ${request.role.name} on ${request.resource.name}:${request.operation.name}.',
        userMessage: 'You do not have permission to perform this action.',
      );
    }

    _logger.info(
      code: 'firestore_access_allowed',
      message: 'Firestore access authorized by role/resource matrix',
      metadata: <String, Object?>{
        'workspaceId': request.workspaceId,
        'role': request.role.name,
        'resource': request.resource.name,
        'operation': request.operation.name,
      },
    );

    return const AppSuccess<void>(null);
  }

  AppFailure<void> _deny({
    required FirestoreAccessRequest request,
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(
      code: code,
      message: developerMessage,
      metadata: <String, Object?>{
        'workspaceId': request.workspaceId,
        'role': request.role.name,
        'resource': request.resource.name,
        'operation': request.operation.name,
      },
    );

    return AppFailure<void>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}

const Map<WorkspaceRole, Map<FirestoreResource, Set<FirestoreOperation>>>
_rules = <WorkspaceRole, Map<FirestoreResource, Set<FirestoreOperation>>>{
  WorkspaceRole.owner: <FirestoreResource, Set<FirestoreOperation>>{
    FirestoreResource.workspaceProfile: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
    },
    FirestoreResource.workspaceSettings: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
    },
    FirestoreResource.memberProfiles: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
      FirestoreOperation.delete,
    },
    FirestoreResource.transactions: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
      FirestoreOperation.delete,
    },
    FirestoreResource.auditLog: <FirestoreOperation>{FirestoreOperation.read},
  },
  WorkspaceRole.admin: <FirestoreResource, Set<FirestoreOperation>>{
    FirestoreResource.workspaceProfile: <FirestoreOperation>{
      FirestoreOperation.read,
    },
    FirestoreResource.workspaceSettings: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
    },
    FirestoreResource.memberProfiles: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
    },
    FirestoreResource.transactions: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
      FirestoreOperation.delete,
    },
    FirestoreResource.auditLog: <FirestoreOperation>{FirestoreOperation.read},
  },
  WorkspaceRole.member: <FirestoreResource, Set<FirestoreOperation>>{
    FirestoreResource.workspaceProfile: <FirestoreOperation>{
      FirestoreOperation.read,
    },
    FirestoreResource.memberProfiles: <FirestoreOperation>{
      FirestoreOperation.read,
    },
    FirestoreResource.transactions: <FirestoreOperation>{
      FirestoreOperation.read,
      FirestoreOperation.write,
    },
  },
  WorkspaceRole.localProfile: <FirestoreResource, Set<FirestoreOperation>>{
    FirestoreResource.workspaceProfile: <FirestoreOperation>{
      FirestoreOperation.read,
    },
    FirestoreResource.transactions: <FirestoreOperation>{
      FirestoreOperation.read,
    },
  },
  WorkspaceRole.unknown: <FirestoreResource, Set<FirestoreOperation>>{},
};
