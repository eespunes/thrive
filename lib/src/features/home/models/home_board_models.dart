part of 'package:family_money_management_app/main.dart';

/// One placed widget on a member's Home board (epic #223): which widget,
/// at which size, with which per-user options. The board itself is an
/// ordered list of these, stored on the USER profile — the data the widgets
/// show stays the shared family workspace.
class BoardEntry {
  BoardEntry({
    required this.widgetId,
    this.size = 'm',
    Map<String, dynamic>? options,
  }) : options = options ?? <String, dynamic>{};

  final String widgetId;

  /// `s` (half width, two per row) | `m` (full width) | `l` (full width, tall).
  String size;

  /// Widget-specific options (issue #239): block keys, list id, quick-action
  /// ids, whose events, note text, feed visibility…
  Map<String, dynamic> options;

  Map<String, dynamic> toJson() => {
    'widgetId': widgetId,
    'size': size,
    if (options.isNotEmpty) 'options': options,
  };

  factory BoardEntry.fromJson(Map<String, dynamic> j) => BoardEntry(
    widgetId: (j['widgetId'] ?? '').toString(),
    size: const {'s', 'm', 'l'}.contains(j['size']) ? j['size'] as String : 'm',
    options: Map<String, dynamic>.from((j['options'] as Map?) ?? {}),
  );
}

/// Catalogue definition of a Home-board widget: identity, category for the
/// picker filters, the sizes it supports, and whether it may appear on a
/// kid profile's board (issue #245). These same definitions are what the
/// Android-widgets epic (#224) will consume later.
class HomeWidgetDef {
  const HomeWidgetDef({
    required this.id,
    required this.title,
    required this.sub,
    required this.icon,
    required this.category,
    required this.sizes,
    this.kidSafe = false,
  });

  final String id;
  final String title;
  final String sub;
  final String icon;

  /// `money` | `calendar` | `home`.
  final String category;
  final List<String> sizes;
  final bool kidSafe;
}

/// The full widget catalogue (issues #241–#243).
const List<HomeWidgetDef> kHomeWidgetCatalog = [
  // ------------------------------------------------------------- Money
  HomeWidgetDef(
    id: 'balance',
    title: 'Projected balance',
    sub: 'This month, at a glance',
    icon: 'wallet',
    category: 'money',
    sizes: ['m', 'l'],
  ),
  HomeWidgetDef(
    id: 'still_to_pay',
    title: 'Still to pay',
    sub: 'Open amount per account',
    icon: 'card',
    category: 'money',
    sizes: ['m'],
  ),
  HomeWidgetDef(
    id: 'next_bills',
    title: 'Next bills',
    sub: 'Upcoming, payable in place',
    icon: 'clock',
    category: 'money',
    sizes: ['m', 'l'],
  ),
  HomeWidgetDef(
    id: 'budget_blocks',
    title: 'Budget blocks',
    sub: 'Spent vs limits for chosen blocks',
    icon: 'chart',
    category: 'money',
    sizes: ['m', 'l'],
  ),
  HomeWidgetDef(
    id: 'cards_wallet',
    title: 'Discount cards',
    sub: 'The family wallet',
    icon: 'card',
    category: 'money',
    sizes: ['m'],
  ),
  HomeWidgetDef(
    id: 'income',
    title: 'Income',
    sub: 'Received vs expected',
    icon: 'download',
    category: 'money',
    sizes: ['s'],
  ),
  HomeWidgetDef(
    id: 'savings',
    title: 'Savings',
    sub: 'Put aside this month',
    icon: 'star',
    category: 'money',
    sizes: ['s'],
  ),
  HomeWidgetDef(
    id: 'month_status',
    title: 'Month status',
    sub: 'Open or closed, days left',
    icon: 'cal',
    category: 'money',
    sizes: ['s'],
  ),
  HomeWidgetDef(
    id: 'pocket_money',
    title: 'My pocket money',
    sub: 'Stars saved toward a reward',
    icon: 'star',
    category: 'money',
    sizes: ['s'],
    kidSafe: true,
  ),
  // ---------------------------------------------------------- Calendar
  HomeWidgetDef(
    id: 'today',
    title: 'Today & upcoming',
    sub: 'Your day or the whole family',
    icon: 'cal',
    category: 'calendar',
    sizes: ['m', 'l'],
    kidSafe: true,
  ),
  HomeWidgetDef(
    id: 'week_strip',
    title: 'Week strip',
    sub: 'Busy-ness per day',
    icon: 'cal',
    category: 'calendar',
    sizes: ['m'],
  ),
  HomeWidgetDef(
    id: 'family_day',
    title: 'Family day',
    sub: 'One row per member',
    icon: 'users',
    category: 'calendar',
    sizes: ['l'],
  ),
  HomeWidgetDef(
    id: 'next_up',
    title: 'Next up',
    sub: 'Countdown to your next event',
    icon: 'clock',
    category: 'calendar',
    sizes: ['s'],
  ),
  HomeWidgetDef(
    id: 'birthdays',
    title: 'Birthdays',
    sub: 'Birthdays & anniversaries',
    icon: 'cake',
    category: 'calendar',
    sizes: ['s'],
  ),
  HomeWidgetDef(
    id: 'imported_cals',
    title: 'Imported calendars',
    sub: 'Feeds with per-feed visibility',
    icon: 'download',
    category: 'calendar',
    sizes: ['m'],
  ),
  // --------------------------------------------------------- Home life
  HomeWidgetDef(
    id: 'tasks',
    title: 'Tasks due soon',
    sub: 'Tick them off from Home',
    icon: 'tasklist',
    category: 'home',
    sizes: ['m', 'l'],
  ),
  HomeWidgetDef(
    id: 'shopping',
    title: 'Shopping list',
    sub: 'Open items, quick add',
    icon: 'cart',
    category: 'home',
    sizes: ['m'],
  ),
  HomeWidgetDef(
    id: 'meals',
    title: 'Meal plan',
    sub: 'The next three days',
    icon: 'moon',
    category: 'home',
    sizes: ['m', 'l'],
    kidSafe: true,
  ),
  HomeWidgetDef(
    id: 'chores',
    title: 'Chores & stars',
    sub: 'Star progress per member',
    icon: 'star',
    category: 'home',
    sizes: ['m'],
    kidSafe: true,
  ),
  HomeWidgetDef(
    id: 'quick_actions',
    title: 'Quick actions',
    sub: 'Your four favourite buttons',
    icon: 'plus',
    category: 'home',
    sizes: ['s', 'm'],
  ),
  HomeWidgetDef(
    id: 'family_note',
    title: 'Family note',
    sub: 'One pinned note',
    icon: 'note',
    category: 'home',
    sizes: ['m'],
  ),
  HomeWidgetDef(
    id: 'divider',
    title: 'Divider',
    sub: 'A label to group your board',
    icon: 'filter',
    category: 'home',
    sizes: ['s'],
  ),
];

HomeWidgetDef? homeWidgetDef(String id) =>
    kHomeWidgetCatalog.where((d) => d.id == id).firstOrNull;

/// The board every member starts with (issue #235): Balance · Today ·
/// Tasks · Shopping. An untouched Home must look finished.
List<BoardEntry> defaultHomeBoard() => [
  BoardEntry(widgetId: 'balance'),
  BoardEntry(widgetId: 'today'),
  // "Only mine" matches the pre-board Home, which listed the user's own
  // open tasks.
  BoardEntry(widgetId: 'tasks', options: {'onlyMine': true}),
  BoardEntry(widgetId: 'shopping'),
];

/// Parses a persisted board, dropping entries whose widget no longer exists
/// in the catalogue and clamping sizes to what each widget supports.
/// Returns null when [raw] is not a list (never-edited profiles keep the
/// default board, distinct from a deliberately emptied `[]`).
List<BoardEntry>? parseHomeBoard(dynamic raw) {
  if (raw is! List) return null;
  final out = <BoardEntry>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final entry = BoardEntry.fromJson(Map<String, dynamic>.from(e));
    final def = homeWidgetDef(entry.widgetId);
    if (def == null) continue;
    if (!def.sizes.contains(entry.size)) entry.size = def.sizes.first;
    out.add(entry);
  }
  return out;
}

/// The quick actions offered by the `quick_actions` widget (issue #243) —
/// the user picks four of these ids in the widget's options.
const List<(String, String, String)> kHomeQuickActions = [
  ('add_expense', 'Add expense', 'plus'),
  ('add_event', 'New event', 'cal'),
  ('add_task', 'New task', 'tasklist'),
  ('add_shop', 'Shopping item', 'cart'),
  ('open_wallet', 'Wallet', 'card'),
  ('open_weekly', 'Weekly plan', 'moon'),
  ('open_stats', 'Statistics', 'chart'),
  ('open_flow', 'Money calendar', 'wallet'),
];

const List<String> kDefaultQuickActions = [
  'add_expense',
  'add_event',
  'add_task',
  'add_shop',
];
