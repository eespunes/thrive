part of 'package:family_money_management_app/main.dart';

enum AppHeaderLeading { none, back, close, photo }

class AppHeaderAction {
  const AppHeaderAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.key,
    this.badge,
    this.filled = false,
    this.active = false,
  });

  final String icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Key? key;
  final int? badge;
  final bool filled;
  final bool active;
}

/// The common chrome for tabs, pushed pages, editors and onboarding.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading = AppHeaderLeading.none,
    this.onLeadingPressed,
    this.leadingKey,
    this.leadingWidget,
    this.titleKey,
    this.subtitleKey,
    this.subtitleOnPressed,
    this.statusDot,
    this.statusPill,
    this.statusPillKey,
    this.actions = const [],
    this.trailing,
    this.statusChip,
    this.textAction,
    this.textActionKey,
    this.onTextActionPressed,
    this.toolbar,
    this.hero = false,
    this.scrolled = false,
  }) : assert(actions.length <= 2),
       assert(textAction == null || actions.length < 1),
       assert(trailing == null || (actions.length < 1 && textAction == null)),
       assert(leading != AppHeaderLeading.photo || leadingWidget != null);

  final String title;
  final String? subtitle;
  final AppHeaderLeading leading;
  final VoidCallback? onLeadingPressed;
  final Key? leadingKey;
  final Widget? leadingWidget;
  final Key? titleKey;
  final Key? subtitleKey;
  final VoidCallback? subtitleOnPressed;
  final Color? statusDot;
  final String? statusPill;
  final Key? statusPillKey;
  final List<AppHeaderAction> actions;
  final Widget? trailing;
  final Widget? statusChip;
  final String? textAction;
  final Key? textActionKey;
  final VoidCallback? onTextActionPressed;
  final Widget? toolbar;
  final bool hero;
  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = hero
        ? Colors.transparent
        : (scrolled
              ? (dark ? Theme.of(context).colorScheme.surface : Colors.white)
              : B.page);
    final ink = hero
        ? Colors.white
        : (dark ? Theme.of(context).colorScheme.onSurface : B.ink);
    final subInk = hero
        ? const Color(0xe6ffffff)
        : (dark ? Theme.of(context).colorScheme.onSurfaceVariant : B.muted);
    final buttonInk = hero
        ? Colors.white
        : (dark ? Theme.of(context).colorScheme.onSurface : B.text);
    final buttonBg = hero
        ? Colors.white.withValues(alpha: .18)
        : (dark ? Theme.of(context).colorScheme.surface : Colors.white);
    final buttonLine = hero ? Colors.white.withValues(alpha: .28) : B.line;
    final visibleActions = actions.take(statusChip == null ? 2 : 1).toList();

    Widget iconButton(
      String name,
      VoidCallback? onTap,
      String tooltip, {
      Key? key,
      bool filled = false,
      bool active = false,
      int? badge,
    }) {
      return Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: filled
                  ? Colors.white
                  : active
                  ? B.soft
                  : buttonBg,
              border: Border.all(color: active ? B.primary : buttonLine),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ic(
                  name,
                  size: 18,
                  sw: 2.2,
                  color: filled
                      ? B.ink
                      : active
                      ? B.deep
                      : buttonInk,
                ),
                if (badge != null && badge > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: B.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final showLeading = leading != AppHeaderLeading.none;
    final sub = subtitle;
    return Material(
      color: background,
      child: Container(
        decoration: scrolled && !hero
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: B.line)),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (showLeading) ...[
                  if (leading == AppHeaderLeading.photo)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: InkWell(
                        key: leadingKey,
                        onTap: onLeadingPressed,
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: leadingWidget,
                        ),
                      ),
                    )
                  else
                    iconButton(
                      leading == AppHeaderLeading.back ? 'cleft' : 'x',
                      onLeadingPressed,
                      leading == AppHeaderLeading.back ? 'Back' : 'Close',
                      key: leadingKey ?? const ValueKey('app-header-leading'),
                    ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        key: titleKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                          color: ink,
                        ),
                      ),
                      if (sub != null && sub.isNotEmpty)
                        Row(
                          children: [
                            if (statusDot != null) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusDot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: InkWell(
                                onTap: subtitleOnPressed,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        sub,
                                        key:
                                            subtitleKey ??
                                            (subtitleOnPressed == null
                                                ? null
                                                : const ValueKey(
                                                    'app-header-subtitle-picker',
                                                  )),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: subtitleOnPressed == null
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                          color: subtitleOnPressed == null
                                              ? subInk
                                              : (hero
                                                    ? Colors.white
                                                    : B.primary),
                                        ),
                                      ),
                                    ),
                                    if (subtitleOnPressed != null) ...[
                                      const SizedBox(width: 3),
                                      ic(
                                        'cdown',
                                        size: 11,
                                        sw: 2.6,
                                        color: hero ? Colors.white : B.primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (statusPill != null) ...[
                              const SizedBox(width: 7),
                              Container(
                                key: statusPillKey,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: hero
                                      ? Colors.white.withValues(alpha: .22)
                                      : B.amberSoft,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  statusPill!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5,
                                    color: hero ? Colors.white : B.amberText,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                if (statusChip != null) ...[
                  const SizedBox(width: 6),
                  statusChip!,
                ],
                for (final action in visibleActions) ...[
                  const SizedBox(width: 6),
                  iconButton(
                    action.icon,
                    action.onPressed,
                    action.tooltip,
                    key: action.key,
                    badge: action.badge,
                    filled: action.filled,
                    active: action.active,
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
                if (textAction != null) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    key:
                        textActionKey ??
                        const ValueKey('app-header-text-action'),
                    onPressed: onTextActionPressed,
                    child: Text(
                      textAction!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: hero ? Colors.white : B.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (toolbar != null) ...[const SizedBox(height: 12), toolbar!],
          ],
        ),
      ),
    );
  }
}

class AppHeaderSearchItem {
  const AppHeaderSearchItem(this.title, this.subtitle, this.onPressed);

  final String title;
  final String subtitle;
  final VoidCallback onPressed;
}

Future<void> showAppHeaderSearch(
  BuildContext context, {
  required String title,
  required List<AppHeaderSearchItem> items,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => _AppHeaderSearchSheet(title: title, items: items),
);

class _AppHeaderSearchSheet extends StatefulWidget {
  const _AppHeaderSearchSheet({required this.title, required this.items});

  final String title;
  final List<AppHeaderSearchItem> items;

  @override
  State<_AppHeaderSearchSheet> createState() => _AppHeaderSearchSheetState();
}

class _AppHeaderSearchSheetState extends State<_AppHeaderSearchSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final matches = widget.items
        .where(
          (item) =>
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.subtitle.toLowerCase().contains(query),
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            AppHeader(
              title: widget.title,
              subtitle: '${matches.length} results',
              leading: AppHeaderLeading.close,
              onLeadingPressed: () => Navigator.of(context).pop(),
              toolbar: TextField(
                key: const ValueKey('app-header-search-field'),
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final item = matches[index];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.subtitle),
                    onTap: () {
                      Navigator.of(context).pop();
                      item.onPressed();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
