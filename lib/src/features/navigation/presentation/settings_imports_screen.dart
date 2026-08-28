part of 'package:family_money_management_app/main.dart';

/// Imported calendars sub-screen + feed studio (#326, `Settings v2.dc.html`):
/// rich rows (badge, "category · ICS · N events · last sync", Shown / Hidden
/// / amber Failing) with per-row quick chips, add-by-pasted-iCal-link →
/// editor, and the three-card feed editor (The link / What each event brings
/// in / How it shows in Thrive).
extension _ThriveImportsScreen on _ThriveHomeState {
  void openImportedCalendarsScreen() {
    pushSettingsPage<void>((_) => _ImportedCalendarsScreen(state: this));
  }

  /// "Synced just now" / "Synced 2h ago" / "Failing" one-liner for a feed.
  /// Sync times are session-only (they were never persisted), so a feed not
  /// yet synced this session just reads "Synced".
  String importSyncLabel(ImportedCalendar cal) {
    if (failedImportIds.contains(cal.id)) return 'Failing';
    final at = _lastSyncShownAt[cal.id];
    if (at == null) return 'Synced';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Synced just now';
    if (d.inHours < 1) return 'Synced ${d.inMinutes}m ago';
    return 'Synced ${d.inHours}h ago';
  }

  /// "↻ Sync now" for a single feed: re-fetches and surfaces the outcome.
  Future<void> syncImportNow(String id) async {
    final err = await refreshImport(id);
    if (err != null) {
      flash(err);
    } else {
      _lastSyncShownAt[id] = DateTime.now();
    }
  }

  /// Paste-an-iCal-link add flow: imports the feed (deriving a name from the
  /// link's host), then opens its editor immediately.
  Future<void> addImportFromLink(String url) async {
    final name = url
        .replaceFirst(RegExp(r'^(https?|webcal)://'), '')
        .split('/')
        .first;
    final err = await saveImport(name: name, url: url);
    if (err != null) {
      flash(err);
      return;
    }
    final cal = importedCalendars.lastOrNull;
    if (cal == null) return;
    _lastSyncShownAt[cal.id] = DateTime.now();
    await pushSettingsPage<void>(
      (_) => _ImportStudio(state: this, feedId: cal.id),
    );
  }
}

/// When each feed last synced THIS SESSION, for the rows' "Synced 2h ago"
/// label only. Deliberately separate from `_lastAutoSync` so showing a label
/// never suppresses the open/resume auto-sync.
final Map<String, DateTime> _lastSyncShownAt = {};

/// Reminder options for imported feeds, in display order.
const List<String> kImportReminderValues = [
  'none',
  'at',
  '5m',
  '15m',
  '30m',
  '1h',
  '2h',
  '1d',
  '2d',
];

class _ImportedCalendarsScreen extends StatelessWidget {
  const _ImportedCalendarsScreen({required this.state});
  final _ThriveHomeState state;

  Widget _chip({
    required Key key,
    required String label,
    bool? on,
    required VoidCallback onTap,
  }) {
    final active = on ?? false;
    final neutral = on == null;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: neutral ? Colors.white : (active ? B.soft : Colors.white),
          border: Border.all(color: active ? B.primary : B.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          neutral ? label : '${active ? '✓' : '✕'} $label',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: neutral
                ? B.text
                : (active ? B.deep : const Color(0xff94a0b0)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) => SettingsSubScreen(
        sync: s.syncStatus,
        offline: s.netOffline,
        title: 'Imported calendars',
        subtitle: 'Read-only ICS feeds',
        intro:
            'Read-only ICS feeds. Chips control what each feed imports; '
            'tap a row to edit everything.',
        footnote:
            'Only ICS/web links — Google or Apple account sync is on the '
            'roadmap. Removing a feed removes its events.',
        addPlaceholder: 'Paste an iCal link…',
        addLabel: 'Import',
        emptyAddHint: 'Paste a link first',
        onToast: s.flash,
        onAdd: (url) => unawaited(s.addImportFromLink(url)),
        children: [
          for (final cal in s.importedCalendars)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _feedRow(context, s, cal),
            ),
        ],
      ),
    );
  }

  Widget _feedRow(
    BuildContext context,
    _ThriveHomeState s,
    ImportedCalendar cal,
  ) {
    final failing = s.failedImportIds.contains(cal.id);
    final catName = s.catById(cal.category)?.name;
    final n = cal.events.length;
    return SettingsListRow(
      rowKey: ValueKey('imports-row-${cal.id}'),
      leading: settingsBadgeTile(color: cal.color, icon: 'link'),
      label: cal.name,
      sub:
          '${catName != null ? '$catName · ' : ''}ICS · '
          '$n event${n == 1 ? '' : 's'} · ${s.importSyncLabel(cal)}',
      value: failing ? 'Failing' : (cal.visible ? 'Shown' : 'Hidden'),
      warnVal: failing,
      goodVal: !failing && cal.visible,
      onTap: () => s.pushSettingsPage<void>(
        (_) => _ImportStudio(state: s, feedId: cal.id),
      ),
      actions: [
        _chip(
          key: ValueKey('imp-chip-autosync-${cal.id}'),
          label: cal.autoSync ? 'Auto-syncs on open' : 'Auto-sync off',
          on: cal.autoSync,
          onTap: () => s.toggleImportAutoSync(cal.id),
        ),
        _chip(
          key: ValueKey('imp-chip-loc-${cal.id}'),
          label: 'Location',
          on: cal.includeLocation,
          onTap: () => s.toggleImportField(cal.id, location: true),
        ),
        _chip(
          key: ValueKey('imp-chip-desc-${cal.id}'),
          label: 'Description',
          on: cal.includeDescription,
          onTap: () => s.toggleImportField(cal.id, location: false),
        ),
        _chip(
          key: ValueKey('imp-chip-sync-${cal.id}'),
          label: '↻ Sync now',
          onTap: () => unawaited(s.syncImportNow(cal.id)),
        ),
        _chip(
          key: ValueKey('imp-chip-vis-${cal.id}'),
          label: cal.visible ? '👁 Shown' : '🚫 Hidden',
          onTap: () {
            // `cal` is mutated in place by the toggle — read it first.
            final wasVisible = cal.visible;
            s.toggleImportVisible(cal.id);
            s.flash(
              wasVisible ? 'Feed hidden from the calendar' : 'Feed shown again',
            );
          },
        ),
      ],
    );
  }
}

/// Full-screen feed editor (badge studio), three grouped cards: The link,
/// What each event brings in, How it shows in Thrive.
class _ImportStudio extends StatefulWidget {
  const _ImportStudio({required this.state, required this.feedId});
  final _ThriveHomeState state;
  final String feedId;

  @override
  State<_ImportStudio> createState() => _ImportStudioState();
}

class _ImportStudioState extends State<_ImportStudio> {
  late String _name;
  late final TextEditingController _nameCtl;
  late final TextEditingController _url;
  late Color _color;
  late bool _autoSync;
  late bool _visible;
  late bool _loc;
  late bool _desc;
  late String _reminder;
  String? _category;
  bool _saving = false;

  _ThriveHomeState get s => widget.state;

  ImportedCalendar? get _cal =>
      s.importedCalendars.where((c) => c.id == widget.feedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    final c = _cal;
    _name = c?.name ?? '';
    _nameCtl = TextEditingController(text: _name);
    _url = TextEditingController(text: c?.url ?? '');
    _color = c?.color ?? kImportProviders['ics']!.$2;
    _autoSync = c?.autoSync ?? true;
    _visible = c?.visible ?? true;
    _loc = c?.includeLocation ?? true;
    _desc = c?.includeDescription ?? true;
    _reminder = c?.reminder ?? '1h';
    _category = c?.category;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final err = await s.updateImport(
      id: widget.feedId,
      name: _name,
      url: _url.text,
      category: _category,
      color: _color,
      visible: _visible,
      autoSync: _autoSync,
      includeLocation: _loc,
      includeDescription: _desc,
      reminder: _reminder,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      s.flash(err);
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _delete() {
    final c = _cal;
    if (c == null) return;
    final n = c.events.length;
    showCountingConfirmSheet(
      context,
      title: 'Remove "${c.name}"?',
      message:
          'It takes its $n event${n == 1 ? '' : 's'} with it — they '
          'disappear from the calendar. You can add the link again anytime.',
      confirmLabel: 'Remove feed',
      onConfirm: () {
        s.deleteImport(c.id);
        Navigator.of(context).maybePop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cal = _cal;
    final failing = cal != null && s.failedImportIds.contains(cal.id);
    final n = cal?.events.length ?? 0;
    return BadgeStudioScaffold(
      title: 'Edit imported calendar',
      subtitle: 'Update this calendar subscription',
      accent: _color,
      saveLabel: 'Save subscription',
      saveEnabled: !_saving && _url.text.trim().length > 4,
      onSave: () => unawaited(_save()),
      deleteLabel: 'Remove this calendar — its events disappear',
      onDelete: _delete,
      children: [
        // Feeds carry a colour but no emoji/photo badge (the model is
        // unchanged in this epic), so the stage is just badge + name.
        Container(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _color.withValues(alpha: .13),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                ),
                child: Center(
                  child: ic('link', size: 38, sw: 3, color: contrastOn(_color)),
                ),
              ),
              TextField(
                key: const ValueKey('imp-name'),
                controller: _nameCtl,
                onChanged: (v) => _name = v,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 8),
                  hintText: 'Name it… e.g. Kids · School',
                  hintStyle: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                    color: _color.withValues(alpha: .45),
                  ),
                ),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: _color,
                ),
              ),
            ],
          ),
        ),
        studioCard(
          title: 'The link',
          children: [
            studioTextField(
              key: const ValueKey('imp-url'),
              controller: _url,
              hint: 'https://…/calendar.ics',
              onChanged: (_) => setState(() {}),
              margin: const EdgeInsets.only(bottom: 8),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: failing ? B.amberSoft : B.greenSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      failing
                          ? '⚠ Sync failing — check the link'
                          : '$n event${n == 1 ? '' : 's'} · '
                                '${cal == null ? 'Synced' : s.importSyncLabel(cal)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: failing ? B.amberText : B.greenText,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    key: const ValueKey('imp-sync-now'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(
                      s.syncImportNow(widget.feedId).then((_) {
                        if (mounted) setState(() {});
                      }),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: B.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '↻ Sync now',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: B.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xfff0f2f6), height: 16),
            studioToggleRow(
              key: const ValueKey('imp-autosync'),
              label: 'Keep it updated automatically',
              sub: 'Re-syncs this link whenever you open the app',
              value: _autoSync,
              onChanged: () => setState(() => _autoSync = !_autoSync),
              boxed: false,
            ),
          ],
        ),
        studioCard(
          title: 'What each event brings in',
          children: [
            studioToggleRow(
              key: const ValueKey('imp-location'),
              label: 'Import location',
              sub: 'e.g. a match venue or event address',
              value: _loc,
              onChanged: () => setState(() => _loc = !_loc),
              boxed: false,
            ),
            studioToggleRow(
              key: const ValueKey('imp-description'),
              label: 'Import description',
              sub: 'e.g. a competition name or extra feed details',
              value: _desc,
              onChanged: () => setState(() => _desc = !_desc),
              boxed: false,
            ),
            const Divider(color: Color(0xfff0f2f6), height: 16),
            studioSectionLabel('Default reminder'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final r in kImportReminderValues)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: studioChip(
                        key: ValueKey('imp-reminder-$r'),
                        label: calendarReminderLabel(r),
                        selected: _reminder == r,
                        onTap: () => setState(() => _reminder = r),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        studioCard(
          title: 'How it shows in Thrive',
          children: [
            studioToggleRow(
              key: const ValueKey('imp-visible'),
              label: 'Show this calendar',
              sub: 'Display its imported events in the calendar',
              value: _visible,
              onChanged: () => setState(() => _visible = !_visible),
              boxed: false,
            ),
            studioSectionLabel('Category (optional)'),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  studioChip(
                    key: const ValueKey('imp-cat-none'),
                    label: 'None',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in s.eventCategories)
                    studioChip(
                      key: ValueKey('imp-cat-${c.id}'),
                      label: c.emoji != null ? '${c.emoji} ${c.name}' : c.name,
                      selected: _category == c.id,
                      tone: c.color,
                      onTap: () => setState(() => _category = c.id),
                    ),
                ],
              ),
            ),
            BadgeColorRow(
              colors: s.badgePaletteWith(_color),
              selected: _color,
              onPick: (c) => setState(() => _color = c),
              onToast: s.flash,
            ),
          ],
        ),
      ],
    );
  }
}
