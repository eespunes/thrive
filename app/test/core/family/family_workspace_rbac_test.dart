import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/family/family_workspace_rbac.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
  test('copyWith allows clearing joinedAt explicitly', () {
    final original = _membership(joinedAt: DateTime.utc(2029, 1, 1));

    final updated = original.copyWith(clearJoinedAt: true);

    expect(updated.joinedAt, isNull);
  });

  test('activateMembership transitions invited member to active state', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);

    final result = rbac.activateMembership(
      membership: _membership(status: FamilyMembershipStatus.invited),
      joinedAt: DateTime.utc(2029, 1, 1),
    );

    expect(result, isA<AppSuccess<FamilyMembership>>());
    final membership = (result as AppSuccess<FamilyMembership>).value;
    expect(membership.status, FamilyMembershipStatus.active);
    expect(membership.joinedAt, DateTime.utc(2029, 1, 1));
    expect(
      logger.events.map((event) => event.code),
      contains('family_member_joined'),
    );
  });

  test('activateMembership transitions suspended member to active state', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);

    final result = rbac.activateMembership(
      membership: _membership(status: FamilyMembershipStatus.suspended),
      joinedAt: DateTime.utc(2030, 1, 1),
    );

    expect(result, isA<AppSuccess<FamilyMembership>>());
    final membership = (result as AppSuccess<FamilyMembership>).value;
    expect(membership.status, FamilyMembershipStatus.active);
    expect(membership.joinedAt, DateTime.utc(2030, 1, 1));
    expect(
      logger.events.map((event) => event.code),
      contains('family_member_joined'),
    );
  });

  test(
    'activateMembership returns family_member_removed for removed member',
    () {
      final logger = InMemoryAppLogger();
      final rbac = FamilyWorkspaceRbac(logger: logger);

      final result = rbac.activateMembership(
        membership: _membership(status: FamilyMembershipStatus.removed),
        joinedAt: DateTime.utc(2029, 1, 1),
      );

      expect(result, isA<AppFailure<FamilyMembership>>());
      final detail = (result as AppFailure<FamilyMembership>).detail;
      expect(detail.code, 'family_member_removed');
      expect(
        logger.events.map((event) => event.code),
        contains('family_member_removed'),
      );
    },
  );

  test('activateMembership is idempotent for active membership', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final original = _membership(joinedAt: DateTime.utc(2028, 6, 1));

    final result = rbac.activateMembership(
      membership: original,
      joinedAt: DateTime.utc(2030, 1, 1),
    );

    expect(result, isA<AppSuccess<FamilyMembership>>());
    final membership = (result as AppSuccess<FamilyMembership>).value;
    expect(membership.workspaceId, original.workspaceId);
    expect(membership.memberId, original.memberId);
    expect(membership.userId, original.userId);
    expect(membership.role, original.role);
    expect(membership.status, FamilyMembershipStatus.active);
    expect(membership.createdAt, original.createdAt);
    expect(membership.joinedAt, original.joinedAt);
    expect(logger.events, isEmpty);
  });

  test('authorizeAction denies admin action for member role', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);

    final result = rbac.authorizeAction(
      actor: _membership(role: FamilyRole.member),
      action: FamilyProtectedAction.manageMembers,
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'family_action_forbidden');
    expect(
      detail.userMessage,
      'You do not have permission to perform this action in the family workspace.',
    );
  });

  test('authorizeAction allows admin workspace action', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);

    final result = rbac.authorizeAction(
      actor: _membership(role: FamilyRole.admin),
      action: FamilyProtectedAction.manageWorkspaceSettings,
    );

    expect(result, isA<AppSuccess<void>>());
    expect(
      logger.events.map((event) => event.code),
      contains('family_action_authorized'),
    );
  });

  test('authorizeAction denies action for invited membership', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);

    final result = rbac.authorizeAction(
      actor: _membership(
        role: FamilyRole.admin,
        status: FamilyMembershipStatus.invited,
      ),
      action: FamilyProtectedAction.manageWorkspaceSettings,
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'family_membership_inactive');
  });

  test('authorizeAction denies action for suspended membership', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);

    final result = rbac.authorizeAction(
      actor: _membership(
        role: FamilyRole.admin,
        status: FamilyMembershipStatus.suspended,
      ),
      action: FamilyProtectedAction.manageWorkspaceSettings,
    );

    expect(result, isA<AppFailure<void>>());
    final detail = (result as AppFailure<void>).detail;
    expect(detail.code, 'family_membership_inactive');
  });

  test('transferOwnership updates roles and preserves membership records', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(memberId: 'owner-1', role: FamilyRole.owner),
      _membership(memberId: 'admin-1', role: FamilyRole.admin),
      _membership(memberId: 'member-1', role: FamilyRole.member),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'owner-1',
      targetMemberId: 'admin-1',
      memberships: memberships,
    );

    expect(result, isA<AppSuccess<List<FamilyMembership>>>());
    final updated = (result as AppSuccess<List<FamilyMembership>>).value;
    expect(updated.length, 3);
    expect(
      updated.firstWhere((membership) => membership.memberId == 'owner-1').role,
      FamilyRole.admin,
    );
    expect(
      updated.firstWhere((membership) => membership.memberId == 'admin-1').role,
      FamilyRole.owner,
    );
    expect(
      logger.events.map((event) => event.code),
      contains('family_ownership_transferred'),
    );
  });

  test('transferOwnership rejects non-owner actor', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(memberId: 'admin-1', role: FamilyRole.admin),
      _membership(memberId: 'member-1', role: FamilyRole.member),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'admin-1',
      targetMemberId: 'member-1',
      memberships: memberships,
    );

    expect(result, isA<AppFailure<List<FamilyMembership>>>());
    final detail = (result as AppFailure<List<FamilyMembership>>).detail;
    expect(detail.code, 'family_owner_required');
    final warning = logger.events.lastWhere(
      (event) => event.code == 'family_owner_required',
    );
    expect(warning.metadata['actingMemberId'], 'admin-1');
    expect(warning.metadata['targetMemberId'], 'member-1');
  });

  test('transferOwnership rejects transfer to inactive target member', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(memberId: 'owner-1', role: FamilyRole.owner),
      _membership(
        memberId: 'inactive-1',
        role: FamilyRole.admin,
        status: FamilyMembershipStatus.suspended,
      ),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'owner-1',
      targetMemberId: 'inactive-1',
      memberships: memberships,
    );

    expect(result, isA<AppFailure<List<FamilyMembership>>>());
    final detail = (result as AppFailure<List<FamilyMembership>>).detail;
    expect(detail.code, 'family_target_not_eligible');
  });

  test('transferOwnership rejects transfer to localProfile member', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(memberId: 'owner-1', role: FamilyRole.owner),
      _membership(memberId: 'local-1', role: FamilyRole.localProfile),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'owner-1',
      targetMemberId: 'local-1',
      memberships: memberships,
    );

    expect(result, isA<AppFailure<List<FamilyMembership>>>());
    final detail = (result as AppFailure<List<FamilyMembership>>).detail;
    expect(detail.code, 'family_target_not_eligible');
  });

  test('transferOwnership rejects when acting member is missing', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(memberId: 'target-1', role: FamilyRole.admin),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'missing-actor',
      targetMemberId: 'target-1',
      memberships: memberships,
    );

    expect(result, isA<AppFailure<List<FamilyMembership>>>());
    final detail = (result as AppFailure<List<FamilyMembership>>).detail;
    expect(detail.code, 'family_actor_missing');
  });

  test('transferOwnership rejects when target member is missing', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(memberId: 'owner-1', role: FamilyRole.owner),
      _membership(memberId: 'other-1', role: FamilyRole.member),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'owner-1',
      targetMemberId: 'missing-target',
      memberships: memberships,
    );

    expect(result, isA<AppFailure<List<FamilyMembership>>>());
    final detail = (result as AppFailure<List<FamilyMembership>>).detail;
    expect(detail.code, 'family_target_missing');
  });

  test('transferOwnership rejects self-transfer', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(memberId: 'owner-1', role: FamilyRole.owner),
      _membership(memberId: 'admin-1', role: FamilyRole.admin),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'owner-1',
      targetMemberId: 'owner-1',
      memberships: memberships,
    );

    expect(result, isA<AppFailure<List<FamilyMembership>>>());
    final detail = (result as AppFailure<List<FamilyMembership>>).detail;
    expect(detail.code, 'family_self_transfer_invalid');
  });

  test('transferOwnership rejects cross-workspace target member', () {
    final logger = InMemoryAppLogger();
    final rbac = FamilyWorkspaceRbac(logger: logger);
    final memberships = <FamilyMembership>[
      _membership(
        workspaceId: 'workspace-owner',
        memberId: 'owner-1',
        role: FamilyRole.owner,
      ),
      _membership(
        workspaceId: 'workspace-other',
        memberId: 'admin-1',
        role: FamilyRole.admin,
      ),
    ];

    final result = rbac.transferOwnership(
      actingMemberId: 'owner-1',
      targetMemberId: 'admin-1',
      memberships: memberships,
    );

    expect(result, isA<AppFailure<List<FamilyMembership>>>());
    final detail = (result as AppFailure<List<FamilyMembership>>).detail;
    expect(detail.code, 'family_workspace_mismatch');
  });
}

FamilyMembership _membership({
  String workspaceId = 'workspace-1',
  String memberId = 'member-1',
  String userId = 'user-1',
  FamilyRole role = FamilyRole.member,
  FamilyMembershipStatus status = FamilyMembershipStatus.active,
  DateTime? joinedAt,
}) {
  return FamilyMembership(
    workspaceId: workspaceId,
    memberId: memberId,
    userId: userId,
    role: role,
    status: status,
    createdAt: DateTime.utc(2028, 1, 1),
    joinedAt: joinedAt,
  );
}
