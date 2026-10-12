part of 'package:family_money_management_app/main.dart';

/// Kid accounts: a login an admin restricted (`kidUids` on the family doc —
/// Flow A, an existing account turned into a kid) or a login an admin gave a
/// kid profile (Flow B). On their own device a kid only gets their own
/// world: calendar events they attend, the lists they created, and a
/// read-only meal plan. No Money tab, no discount cards, no kitchen wall and
/// no family-admin settings.
const List<String> kChildNavTabs = ['calendar', 'lists', 'weekly'];

const String kChildMealPlanReadOnly = 'The meal plan is read-only for kids';

/// The tabs a child user may open at all.
const Set<String> kChildAllowedTabs = {
  'home',
  'calendar',
  'lists',
  'weekly',
  'more',
};

extension _ThriveChildAccess on _ThriveHomeState {
  /// Whether the signed-in user is a child user in the current family.
  bool get isChildUser => amIKidProfile();

  bool _childOwns(String? createdBy) =>
      createdBy != null && _homeCurrentUserMemberIds().contains(createdBy);

  /// A child only sees events they attend (or created themselves).
  bool childSeesEvent(CalendarEvent ev) {
    final mine = _homeCurrentUserMemberIds();
    return ev.attendees.any(mine.contains) ||
        (ev.createdBy != null && mine.contains(ev.createdBy));
  }

  /// A child only sees an imported feed whose category is assigned to them.
  bool childSeesImported(ImportedCalendar cal) {
    final cat = catById(cal.category);
    if (cat == null) return false;
    final mine = _homeCurrentUserMemberIds();
    return cat.members.any(mine.contains);
  }

  /// To-do lists this user may see: all of them, or only their own for a
  /// child user.
  List<TaskList> get visibleTaskLists => isChildUser
      ? taskLists.where((l) => _childOwns(l.createdBy)).toList()
      : taskLists;

  /// Shopping lists this user may see: all of them, or only their own for a
  /// child user.
  List<ShoppingList> get visibleShoppingLists => isChildUser
      ? shoppingLists.where((l) => _childOwns(l.createdBy)).toList()
      : shoppingLists;

  /// Gate for anything a child user can't do; flashes why and returns true
  /// when the action must be blocked.
  bool childBlocked([String message = 'Not available on a kid profile']) {
    if (!isChildUser) return false;
    flash(message);
    return true;
  }
}
