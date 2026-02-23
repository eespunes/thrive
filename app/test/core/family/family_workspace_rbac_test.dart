import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/family/family_workspace_rbac.dart';
import 'package:thrive_app/core/observability/app_logger.dart';
import 'package:thrive_app/core/result/app_result.dart';

void main() {
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
  });
}

FamilyMembership _membership({
  String workspaceId = 'workspace-1',
  String memberId = 'member-1',
  String userId = 'user-1',
  FamilyRole role = FamilyRole.member,
  FamilyMembershipStatus status = FamilyMembershipStatus.active,
}) {
  return FamilyMembership(
    workspaceId: workspaceId,
    memberId: memberId,
    userId: userId,
    role: role,
    status: status,
    createdAt: DateTime.utc(2028, 1, 1),
  );
}
