import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

enum FamilyMembershipStatus { invited, active, suspended, removed }

enum FamilyRole { owner, admin, member, localProfile }

enum FamilyProtectedAction {
  manageMembers,
  manageWorkspaceSettings,
  transferOwnership,
  addTransaction,
  viewWorkspace,
}

class FamilyMembership {
  const FamilyMembership({
    required this.workspaceId,
    required this.memberId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.joinedAt,
  });

  final String workspaceId;
  final String memberId;
  final String userId;
  final FamilyRole role;
  final FamilyMembershipStatus status;
  final DateTime createdAt;
  final DateTime? joinedAt;

  bool get isActive => status == FamilyMembershipStatus.active;

  FamilyMembership copyWith({
    String? workspaceId,
    String? memberId,
    String? userId,
    FamilyRole? role,
    FamilyMembershipStatus? status,
    DateTime? createdAt,
    Object? joinedAt = _joinedAtUnchanged,
  }) {
    return FamilyMembership(
      workspaceId: workspaceId ?? this.workspaceId,
      memberId: memberId ?? this.memberId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      joinedAt: identical(joinedAt, _joinedAtUnchanged)
          ? this.joinedAt
          : joinedAt as DateTime?,
    );
  }
}

class FamilyWorkspaceRbac {
  FamilyWorkspaceRbac({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  AppResult<FamilyMembership> activateMembership({
    required FamilyMembership membership,
    required DateTime joinedAt,
  }) {
    if (membership.status == FamilyMembershipStatus.removed) {
      return AppFailure<FamilyMembership>(
        FailureDetail(
          code: 'family_member_removed',
          developerMessage:
              'Cannot activate membership because member was removed.',
          userMessage:
              'This invitation is no longer valid. Ask an admin for a new invite.',
          recoverable: false,
        ),
      );
    }

    if (membership.status == FamilyMembershipStatus.active) {
      return AppSuccess<FamilyMembership>(membership);
    }

    final activatedMembership = membership.copyWith(
      status: FamilyMembershipStatus.active,
      joinedAt: joinedAt,
    );

    _logger.info(
      code: 'family_member_joined',
      message: 'Family member joined workspace',
      metadata: <String, Object?>{
        'workspaceId': membership.workspaceId,
        'memberId': membership.memberId,
        'userId': membership.userId,
        'role': membership.role.name,
      },
    );

    return AppSuccess<FamilyMembership>(activatedMembership);
  }

  AppResult<void> authorizeAction({
    required FamilyMembership actor,
    required FamilyProtectedAction action,
  }) {
    if (!actor.isActive) {
      final failure = FailureDetail(
        code: 'family_membership_inactive',
        developerMessage:
            'Authorization denied because membership is not active.',
        userMessage:
            'Your family access is inactive right now. Contact your family admin.',
        recoverable: true,
      );
      _logger.warning(
        code: failure.code,
        message: failure.developerMessage,
        metadata: <String, Object?>{
          'workspaceId': actor.workspaceId,
          'memberId': actor.memberId,
          'status': actor.status.name,
          'action': action.name,
        },
      );
      return AppFailure<void>(failure);
    }

    final allowedActions = _roleMatrix[actor.role] ?? <FamilyProtectedAction>{};
    if (!allowedActions.contains(action)) {
      final failure = FailureDetail(
        code: 'family_action_forbidden',
        developerMessage:
            'Authorization denied for role ${actor.role.name} on action ${action.name}.',
        userMessage:
            'You do not have permission to perform this action in the family workspace.',
        recoverable: true,
      );
      _logger.warning(
        code: failure.code,
        message: failure.developerMessage,
        metadata: <String, Object?>{
          'workspaceId': actor.workspaceId,
          'memberId': actor.memberId,
          'role': actor.role.name,
          'action': action.name,
        },
      );
      return AppFailure<void>(failure);
    }

    _logger.info(
      code: 'family_action_authorized',
      message: 'Family action authorized',
      metadata: <String, Object?>{
        'workspaceId': actor.workspaceId,
        'memberId': actor.memberId,
        'role': actor.role.name,
        'action': action.name,
      },
    );
    return const AppSuccess<void>(null);
  }

  AppResult<List<FamilyMembership>> transferOwnership({
    required String actingMemberId,
    required String targetMemberId,
    required List<FamilyMembership> memberships,
  }) {
    final actor = memberships.where(
      (entry) => entry.memberId == actingMemberId,
    );
    if (actor.isEmpty) {
      return _ownershipFailure(
        code: 'family_actor_missing',
        developerMessage:
            'Ownership transfer denied because acting member was not found.',
        userMessage:
            'Could not transfer ownership. Please refresh and try again.',
      );
    }

    final actingMember = actor.first;
    if (actingMember.role != FamilyRole.owner || !actingMember.isActive) {
      return _ownershipFailure(
        code: 'family_owner_required',
        developerMessage:
            'Ownership transfer denied because acting member is not an active owner.',
        userMessage: 'Only the current family owner can transfer ownership.',
      );
    }

    if (actingMemberId == targetMemberId) {
      return _ownershipFailure(
        code: 'family_self_transfer_invalid',
        developerMessage:
            'Ownership transfer denied because owner cannot transfer to self.',
        userMessage: 'You are already the family owner.',
      );
    }

    final target = memberships.where(
      (entry) => entry.memberId == targetMemberId,
    );
    if (target.isEmpty) {
      return _ownershipFailure(
        code: 'family_target_missing',
        developerMessage:
            'Ownership transfer denied because target member was not found.',
        userMessage:
            'Could not transfer ownership. Please refresh and try again.',
      );
    }

    final targetMember = target.first;
    if (!targetMember.isActive ||
        targetMember.role == FamilyRole.localProfile) {
      return _ownershipFailure(
        code: 'family_target_not_eligible',
        developerMessage:
            'Ownership transfer denied because target is not an active eligible role.',
        userMessage:
            'Ownership can only be transferred to an active adult member.',
      );
    }

    final updatedMemberships = memberships
        .map((membership) {
          if (membership.memberId == actingMemberId) {
            return membership.copyWith(role: FamilyRole.admin);
          }
          if (membership.memberId == targetMemberId) {
            return membership.copyWith(role: FamilyRole.owner);
          }
          return membership;
        })
        .toList(growable: false);

    _logger.info(
      code: 'family_ownership_transferred',
      message: 'Family workspace ownership transferred',
      metadata: <String, Object?>{
        'workspaceId': actingMember.workspaceId,
        'previousOwnerMemberId': actingMemberId,
        'newOwnerMemberId': targetMemberId,
      },
    );
    return AppSuccess<List<FamilyMembership>>(updatedMemberships);
  }

  AppFailure<List<FamilyMembership>> _ownershipFailure({
    required String code,
    required String developerMessage,
    required String userMessage,
  }) {
    _logger.warning(code: code, message: developerMessage);
    return AppFailure<List<FamilyMembership>>(
      FailureDetail(
        code: code,
        developerMessage: developerMessage,
        userMessage: userMessage,
        recoverable: true,
      ),
    );
  }
}

const Object _joinedAtUnchanged = Object();

const Map<FamilyRole, Set<FamilyProtectedAction>> _roleMatrix =
    <FamilyRole, Set<FamilyProtectedAction>>{
      FamilyRole.owner: <FamilyProtectedAction>{
        FamilyProtectedAction.manageMembers,
        FamilyProtectedAction.manageWorkspaceSettings,
        FamilyProtectedAction.transferOwnership,
        FamilyProtectedAction.addTransaction,
        FamilyProtectedAction.viewWorkspace,
      },
      FamilyRole.admin: <FamilyProtectedAction>{
        FamilyProtectedAction.manageMembers,
        FamilyProtectedAction.manageWorkspaceSettings,
        FamilyProtectedAction.addTransaction,
        FamilyProtectedAction.viewWorkspace,
      },
      FamilyRole.member: <FamilyProtectedAction>{
        FamilyProtectedAction.addTransaction,
        FamilyProtectedAction.viewWorkspace,
      },
      FamilyRole.localProfile: <FamilyProtectedAction>{
        FamilyProtectedAction.viewWorkspace,
      },
    };
