part of 'package:family_money_management_app/main.dart';

/// All bottom sheets + the mutations they trigger, ported from the design's
/// renderOverlay / sheet* / save* / delete* methods.
extension _ThriveSheets on _ThriveHomeState {
  // ---------------------------------------------------------- sheet host
  Future<void> _showSheet(
    WidgetBuilder builder, {
    bool monthScoped = false,
  }) async {
    if (monthScoped && isClosed()) {
      showError('Month is closed');
      return;
    }
    update(() => swipedId = null);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x73101828),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SheetShell(child: builder(ctx)),
      ),
    );
  }

  // ============================================================= pickers
  void openMonthPicker() {
    _showSheet((ctx) => _MonthPickerSheet(state: this));
  }

  void openCloseConfirm() {
    _showSheet((ctx) => _CloseConfirmSheet(state: this));
  }

  void openAccountPicker(
    String kind,
    String id,
    String current, [
    String? catKey,
  ]) {
    _showSheet(
      monthScoped: true,
      (ctx) => _AccountPickerSheet(
        state: this,
        kind: kind,
        id: id,
        current: current,
        catKey: catKey,
      ),
    );
  }

  void openCapSheet(String cat, double? value) {
    _showSheet(
      monthScoped: true,
      (ctx) => _CapSheet(state: this, cat: cat, value: value),
    );
  }

  /// If [current] is the series' only real anchor (not generated, not an
  /// exception), promotes the next generated occurrence after the visible
  /// month to explicit, so the pristine spec keeps propagating once
  /// [current] becomes an exception (#292) or is skipped (#293).
  void _promoteNextGeneratedAnchor(String? seriesId, ExpenseItem current) {
    if (seriesId == null || current.generated || current.exception) return;
    final hasOtherAnchor = _seriesOccurrences(seriesId).any(
      (o) =>
          !o.item.generated && !o.item.exception && !identical(o.item, current),
    );
    if (hasOtherAnchor) return;
    final future =
        _seriesOccurrences(seriesId)
            .where(
              (o) =>
                  o.item.generated &&
                  _monthOrd(o.year, o.monthIdx) > _monthOrd(year, monthIdx),
            )
            .toList()
          ..sort(
            (a, b) => _monthOrd(
              a.year,
              a.monthIdx,
            ).compareTo(_monthOrd(b.year, b.monthIdx)),
          );
    if (future.isNotEmpty) future.first.item.generated = false;
  }

  void _clearSeriesStop(String? seriesId, int yr, int mIdx) {
    if (seriesId == null || seriesId.isEmpty) return;
    data[yr]?[kMonthKeys[mIdx]]?.seriesStops.removeWhere((x) => x == seriesId);
  }

  void _removeRecurringFromCurrentForward(String seriesId, String catKey) {
    final startOrd = _monthOrd(year, monthIdx);
    for (final yr in data.keys) {
      for (int mIdx = 0; mIdx < kMonthKeys.length; mIdx++) {
        if (_monthOrd(yr, mIdx) < startOrd) continue;
        final month = data[yr]?[kMonthKeys[mIdx]];
        if (month == null || month.closed) continue;
        // Per-month exceptions in later months survive an onward rewrite
        // (#292) — a "future months" edit composes with an earlier "only
        // this month" edit instead of silently erasing it.
        month.blocks[catKey]?.removeWhere(
          (it) =>
              _seriesIdFor(it) == seriesId &&
              !(it.exception && _monthOrd(yr, mIdx) > startOrd),
        );
      }
    }
  }

  // ========================================================== mutations
  void setItemAccount(String kind, String id, String accKey, String? catKey) {
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      // Income lives in income-direction blocks now (issue #137), so every
      // item is reached through its block regardless of [kind].
      if (catKey != null) {
        final arr = m.blocks[catKey] ?? <ExpenseItem>[];
        final it = arr.where((x) => x.id == id).firstOrNull;
        if (it != null) {
          final seriesId = _seriesIdFor(it);
          it
            ..account = accKey
            ..generated = false;
          if (seriesId != null && it.recurring) {
            _clearSeriesStop(seriesId, year, monthIdx);
            _removeRecurringFromCurrentForward(seriesId, catKey);
            arr.add(it);
            _syncRecurringSeries();
          }
        }
      }
    });
  }

  /// Saves an entry from the ticket editor (#286). [day] replaces the old
  /// free-text marker (#288); the derived marker string is still written so
  /// older app versions in the family keep parsing a day. [scope] applies to
  /// recurring edits (#292): `'onward'` (default) rewrites this and future
  /// months, `'month'` turns this month into a per-month exception and
  /// leaves the series untouched.
  void saveExpense(
    String mode,
    String cat,
    String? id, {
    required String payee,
    required String label,
    required double amount,
    int? day,
    required bool paid,
    required String account,
    String? until,
    required bool recurring,
    int recurEvery = 1,
    String? recurEndDate,
    String shift = 'none',
    String? cardId,
    String scope = 'onward',
  }) {
    final every = recurEvery < 1 ? 1 : recurEvery;
    final marker = day == null ? '' : ordinal(day);
    mutate(() {
      final month = data[year]![kMonthKeys[monthIdx]]!;
      final arr = month.blocks.putIfAbsent(cat, () => <ExpenseItem>[]);
      final normalizedEnd = normalizeRecurringEndDate(recurEndDate ?? until);
      if (mode == 'edit' && id != null && scope == 'month') {
        // #292 "Only this month": the item becomes a per-month exception;
        // the series (its anchor and every other month) stays as it was.
        final it = arr.where((x) => x.id == id).firstOrNull;
        if (it != null) {
          _promoteNextGeneratedAnchor(_seriesIdFor(it), it);
          it
            ..payee = payee
            ..label = label
            ..amount = amount
            ..marker = marker
            ..day = day
            ..reviewDay = false
            ..paid = paid
            ..account = account
            ..shift = shift
            ..cardId = cardId
            ..exception = true
            ..generated = false;
        }
      } else if (mode == 'edit' && id != null) {
        final it = arr.where((x) => x.id == id).firstOrNull;
        if (it != null) {
          // Issue #195: every item — recurring or not — always carries a
          // stable `seriesId` from now on, so future months' copies (or a
          // future edit) can always be linked back to this one instead of
          // silently becoming an orphaned, unlinked duplicate.
          final seriesId = _seriesIdFor(it) ?? uid();
          _clearSeriesStop(seriesId, year, monthIdx);
          // Always strip this item (and any future/generated copies sharing
          // its series) before re-adding the freshly edited one below — this
          // both applies the edit forward and, if `recurring` is now false,
          // stops future generation. Remove this item explicitly by id too,
          // since it may not yet carry `seriesId` (e.g. a legacy row being
          // edited for the first time under the new always-tagged model).
          _removeRecurringFromCurrentForward(seriesId, cat);
          arr.removeWhere((x) => identical(x, it));
          it
            ..payee = payee
            ..label = label
            ..amount = amount
            ..marker = marker
            ..day = day
            ..reviewDay = false
            ..exception = false
            ..paid = paid
            ..account = account
            ..seriesId = seriesId
            ..recurring = recurring
            ..recurEvery = every
            ..recurEndDate = normalizedEnd
            ..shift = shift
            ..until =
                normalizedEnd ??
                ((until == null || until.isEmpty) ? null : until)
            ..cardId = cardId
            ..generated = false;
          arr.add(it);
        }
      } else {
        // Issue #195: give every newly created item — recurring or not — a
        // stable `seriesId` right away, so it can never end up as an
        // unlinked/orphaned duplicate later (the root cause of the legacy
        // production-data bug).
        final seriesId = uid();
        arr.add(
          ExpenseItem(
            id: uid(),
            payee: payee,
            label: label,
            marker: marker,
            day: day,
            amount: amount,
            paid: paid,
            account: account,
            createdBy: myId,
            createdAt: _isoOfDate(DateTime.now()),
            until:
                normalizedEnd ??
                ((until == null || until.isEmpty) ? null : until),
            recurring: recurring,
            recurEvery: every,
            seriesId: seriesId,
            recurEndDate: normalizedEnd,
            shift: shift,
            cardId: cardId,
          ),
        );
      }
      _syncRecurringSeries();
    }, () => flash(mode == 'edit' ? 'Saved' : 'Added ${eur(amount)}'));
    // "Warn near block limits" (#329): the nudge overrides the plain
    // success toast when this save pushes the block to ≥90% of its cap.
    maybeWarnNearBlockLimit(cat);
  }

  /// Removes an entry with a scope (#293): `'skip'` drops just this month's
  /// occurrence and lets the series continue; `'onward'` ends the series
  /// from this month (history kept). One-offs ignore the scope. The legacy
  /// swipe shortcut maps onto `'onward'`, its historical behaviour.
  void deleteExpense(String cat, String id, {String scope = 'onward'}) {
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      final item = m.blocks[cat]?.where((x) => x.id == id).firstOrNull;
      final seriesId = item == null ? null : _seriesIdFor(item);
      if (seriesId != null && item?.recurring == true && scope == 'skip') {
        _promoteNextGeneratedAnchor(seriesId, item!);
        m.seriesSkips.removeWhere((x) => x == seriesId);
        m.seriesSkips.add(seriesId);
        m.blocks[cat]?.removeWhere((x) => x.id == id);
        _syncRecurringSeries();
      } else if (seriesId != null && item?.recurring == true) {
        m.seriesStops.removeWhere((x) => x == seriesId);
        m.seriesStops.add(seriesId);
        _removeRecurringFromCurrentForward(seriesId, cat);
      } else {
        m.blocks[cat]?.removeWhere((x) => x.id == id);
      }
      swipedId = null;
    }, () => flash(scope == 'skip' ? 'Skipped this month' : 'Deleted'));
  }

  /// Moves an entry to another block (#294). For a recurring series the move
  /// applies from the open month forward — occurrences in earlier months
  /// stay where they were ("History stays where it was"); both blocks' caps
  /// recount immediately because they're derived from the moved items.
  void moveExpenseBlock(String fromCat, String toCat, String id) {
    if (fromCat == toCat) return;
    final toTitle = catByKey(toCat)?.title ?? 'block';
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      final item = m.blocks[fromCat]?.where((x) => x.id == id).firstOrNull;
      if (item == null) return;
      final seriesId = _seriesIdFor(item);
      if (seriesId != null && item.recurring) {
        final startOrd = _monthOrd(year, monthIdx);
        for (final yr in data.keys) {
          for (int mIdx = 0; mIdx < kMonthKeys.length; mIdx++) {
            if (_monthOrd(yr, mIdx) < startOrd) continue;
            final month = data[yr]?[kMonthKeys[mIdx]];
            if (month == null || month.closed) continue;
            final src = month.blocks[fromCat];
            if (src == null) continue;
            final moving = src
                .where((it) => _seriesIdFor(it) == seriesId)
                .toList();
            if (moving.isEmpty) continue;
            src.removeWhere((it) => _seriesIdFor(it) == seriesId);
            month.blocks
                .putIfAbsent(toCat, () => <ExpenseItem>[])
                .addAll(moving);
          }
        }
        _syncRecurringSeries();
      } else {
        m.blocks[fromCat]?.removeWhere((x) => x.id == id);
        m.blocks.putIfAbsent(toCat, () => <ExpenseItem>[]).add(item);
      }
    }, () => flash('Moved to $toTitle — both caps recount from here'));
  }

  void saveCap(String cat, String raw) {
    final val = raw.isEmpty ? null : parseNum(raw);
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      if (val == null || val <= 0) {
        m.caps.remove(cat);
      } else {
        m.caps[cat] = val;
      }
    }, () => flash(val == null ? 'Limit removed' : 'Limit set'));
  }

  void saveAccount(
    String mode,
    String? key, {
    required String name,
    required String short,
    required Color color,
    String? emoji,
    String? picture,
  }) {
    final initials = (short.isNotEmpty ? short : name).trim().toUpperCase();
    final init = initials.length > 2 ? initials.substring(0, 2) : initials;
    update(() {
      if (mode == 'edit' && key != null) {
        for (final a in accounts) {
          if (a.key == key) {
            a
              ..name = name.trim()
              ..short = (short.isNotEmpty ? short : name).trim()
              ..color = color
              ..initials = init
              ..emoji = emoji
              ..picture = picture;
          }
        }
      } else {
        var newKey = (short.isNotEmpty ? short : name)
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
        if (newKey.isEmpty) newKey = 'acc${accounts.length}';
        if (accounts.any((a) => a.key == newKey)) {
          newKey = '${newKey}_${uid().substring(1, 4)}';
        }
        accounts.add(
          Account(
            key: newKey,
            name: name.trim(),
            short: (short.isNotEmpty ? short : name).trim(),
            initials: init,
            color: color,
            emoji: emoji,
            picture: picture,
          ),
        );
      }
    });
    _persist();
    flash('Saved');
  }

  void saveBlock(
    String mode,
    String? key, {
    required String title,
    required String icon,
    required Color tone,
    required bool hasUntil,
    required bool temporary,
    required String capRaw,
    String? emoji,
    String? picture,
    bool isIncome = false,
    bool isSavings = false,
  }) {
    final cap = capRaw.isNotEmpty ? parseNum(capRaw) : null;
    if (mode == 'edit' && key != null) {
      update(() {
        for (final c in cats) {
          if (c.key == key) {
            c
              ..title = title.trim()
              ..icon = icon
              ..emoji = emoji
              ..picture = picture
              ..tone = tone
              ..hasUntil = hasUntil
              ..bg = tintFor(tone)
              ..temporary = temporary
              ..isIncome = isIncome
              ..isSavings = isSavings;
            if (temporary) {
              c.ownerYear ??= year;
              c.ownerMonthIdx ??= monthIdx;
            } else {
              c.ownerYear = null;
              c.ownerMonthIdx = null;
            }
          }
        }
      });
      _persist();
      mutate(() {
        final m = data[year]![kMonthKeys[monthIdx]]!;
        if (!m.closed) {
          if (cap == null || cap <= 0) {
            m.caps.remove(key);
          } else {
            m.caps[key] = cap;
          }
        }
      }, () => flash('Block saved'));
      return;
    }

    var newKey = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (newKey.isEmpty) newKey = 'block${cats.length}';
    if (cats.any((c) => c.key == newKey)) {
      newKey = '${newKey}_${uid().substring(1, 4)}';
    }
    update(() {
      cats.add(
        Category(
          key: newKey,
          title: title.trim(),
          icon: icon,
          emoji: emoji,
          picture: picture,
          marker: 'date',
          tone: tone,
          bg: tintFor(tone),
          hasUntil: hasUntil,
          temporary: temporary,
          ownerYear: temporary ? year : null,
          ownerMonthIdx: temporary ? monthIdx : null,
          isIncome: isIncome,
          isSavings: isSavings,
        ),
      );
    });
    _persist();
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      if (temporary) {
        m.blocks.putIfAbsent(newKey, () => <ExpenseItem>[]);
      } else {
        for (final yr in data.keys) {
          for (final mk in kMonthKeys) {
            final mm = data[yr]![mk];
            if (mm != null && !mm.closed) {
              mm.blocks.putIfAbsent(newKey, () => <ExpenseItem>[]);
            }
          }
        }
      }
      if (!m.closed && cap != null && cap > 0) {
        m.caps[newKey] = cap;
      }
    }, () => flash('Block created'));
  }
}

// ============================================================ sheet shell
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxH = media.size.height * 0.92;
    // Lift the sheet's content above the Android system navigation bar (3-button
    // or gesture): `padding.bottom` is the nav-bar inset with the keyboard
    // discounted, so it collapses to 0 when the keyboard is up (which the host
    // already handles via `viewInsets.bottom`) — no double gap.
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(18, 8, 18, 24 + media.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            margin: const EdgeInsets.fromLTRB(0, 8, 0, 14),
            decoration: BoxDecoration(
              color: const Color(0xffe2e6ee),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

Widget _sheetHead(BuildContext ctx, String title, [String? sub]) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: B.muted,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: B.faint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: ic('x', size: 17, sw: 2.4, color: B.soft2)),
          ),
        ),
      ],
    ),
  );
}

/// Sheet header variant with a confirm (tick) button next to the close
/// (cross) button, used for sheets whose primary action should stay
/// pinned at the top instead of scrolling with the content.
Widget _sheetHeadWithTick(
  BuildContext ctx,
  String title, {
  String? sub,
  required VoidCallback onConfirm,
  bool confirmEnabled = true,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: B.muted,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          key: const ValueKey('sheet-confirm'),
          onTap: confirmEnabled ? onConfirm : null,
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: confirmEnabled ? B.primary : const Color(0xffcbd3dc),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: ic('check', size: 17, sw: 2.6, color: Colors.white),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: B.faint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: ic('x', size: 17, sw: 2.4, color: B.soft2)),
          ),
        ),
      ],
    ),
  );
}

Widget _sheetField(String label, Widget child) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
                color: B.muted,
              ),
            ),
          ),
        child,
      ],
    ),
  );
}

Widget _sheetInput(
  TextEditingController ctrl, {
  Key? key,
  String hint = '',
  bool number = false,
  bool obscure = false,
  ValueChanged<String>? onChanged,
  FocusNode? focusNode,
  TextInputAction? textInputAction,
  ValueChanged<String>? onSubmitted,
  int maxLines = 1,
  TextCapitalization? capitalization,
}) {
  return TextField(
    key: key,
    controller: ctrl,
    focusNode: focusNode,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    textInputAction: textInputAction,
    obscureText: obscure,
    maxLines: maxLines,
    // Free-text fields open the OS keyboard capitalized at the start of a
    // sentence; identifiers (email, username, URL) opt out via
    // [capitalization]; numbers and passwords never capitalize.
    textCapitalization:
        capitalization ??
        (number || obscure
            ? TextCapitalization.none
            : TextCapitalization.sentences),
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: B.ink,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: B.muted,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: B.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: B.primary),
      ),
    ),
  );
}

Widget _primaryBtn(String label, VoidCallback? onTap, {bool enabled = true}) {
  return GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: enabled ? B.primary : const Color(0xffcbd3dc),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    ),
  );
}

Widget _toggleRow(
  String label,
  bool value,
  VoidCallback onTap, {
  String? subtitle,
  Color activeColor = B.green,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? (activeColor == B.green ? B.greenSoft : B.soft)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? (activeColor == B.green ? B.greenLine : B.primary)
              : B.line,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: value
                        ? (activeColor == B.green ? B.greenText : B.deep)
                        : B.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: B.muted,
                    ),
                  ),
              ],
            ),
          ),
          _switch(value, activeColor),
        ],
      ),
    ),
  );
}

Widget _switch(bool on, Color activeColor) {
  return Container(
    width: 42,
    height: 24,
    decoration: BoxDecoration(
      color: on ? activeColor : const Color(0xffcfd6e0),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          left: on ? 20 : 2,
          top: 2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ====================================================== month picker sheet
class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.state.year;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    Widget yStepBtn(String icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: B.line),
        ),
        child: Center(child: ic(icon, size: 16, sw: 2.4, color: B.soft2)),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(context, 'Select month & year'),
          Row(
            children: [
              yStepBtn('cleft', () => setState(() => _year--)),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: B.ink,
                  ),
                ),
              ),
              yStepBtn('cright', () => setState(() => _year++)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 2.4,
            children: [
              for (int i = 0; i < 12; i++)
                _monthCell(s, i, _year, (idx) {
                  s.setYear(_year);
                  s.pickMonth(idx);
                  Navigator.of(context).pop();
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthCell(
    _ThriveHomeState s,
    int i,
    int yr,
    ValueChanged<int> onPick,
  ) {
    final selected = i == s.monthIdx && yr == s.year;
    final closed = s.isClosed(i, yr);
    return GestureDetector(
      onTap: () => onPick(i),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? B.soft : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? B.primary : B.line),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                kMonthsShort[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? B.deep : B.text,
                ),
              ),
            ),
            if (closed)
              Positioned(
                top: 6,
                right: 7,
                child: ic('lock', size: 11, sw: 2.4, color: B.muted),
              ),
          ],
        ),
      ),
    );
  }
}

// ===================================================== close confirm sheet
class _CloseConfirmSheet extends StatelessWidget {
  const _CloseConfirmSheet({required this.state});
  final _ThriveHomeState state;

  @override
  Widget build(BuildContext context) {
    final c = state.compute(state.monthIdx);
    Widget stat(String label, String val, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: B.faint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: B.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(
          context,
          'Close this month?',
          '${kMonthsEn[state.monthIdx]} ${state.year}',
        ),
        const Text(
          'Closing locks every item, toggle and limit for this month — nothing can be added, edited or deleted until you reopen it. A snapshot of the current blocks is kept, so deleting or editing a block later won\u2019t affect this closed month.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: B.soft2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            stat('Balance', eur(c.balance), c.balance >= 0 ? B.green : B.red),
            const SizedBox(width: 9),
            stat(
              'Still to pay',
              eur(c.stillToPay),
              c.stillToPay > 0 ? B.amberText : B.greenText,
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            state.closeMonth();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: B.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ic('lock', size: 16, sw: 2.4, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Close month',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================== account picker sheet
class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.state,
    required this.kind,
    required this.id,
    required this.current,
    this.catKey,
  });
  final _ThriveHomeState state;
  final String kind;
  final String id;
  final String current;
  final String? catKey;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(
            context,
            'Choose account',
            kind == 'income' ? 'Received into' : 'Paid from',
          ),
          for (final a in state.accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  state.setItemAccount(kind, id, a.key, catKey);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: a.key == current ? B.soft : Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: a.key == current ? B.primary : B.line,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: a.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: glyphTile(
                          size: 34,
                          radius: 10,
                          picture: a.picture,
                          emoji: a.emoji,
                          emojiSize: 18,
                          fallback: Text(
                            a.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          a.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: B.ink,
                          ),
                        ),
                      ),
                      if (a.key == current)
                        ic('check', size: 18, sw: 2.6, color: B.primary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================== cap sheet
class _CapSheet extends StatefulWidget {
  const _CapSheet({required this.state, required this.cat, this.value});
  final _ThriveHomeState state;
  final String cat;
  final double? value;

  @override
  State<_CapSheet> createState() => _CapSheetState();
}

class _CapSheetState extends State<_CapSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value != null ? _numStr(widget.value!) : '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cat = s.catByKey(widget.cat)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHead(
          context,
          'Monthly limit',
          '${cat.title} \u00b7 ${kMonthsEn[s.monthIdx]}',
        ),
        const Text(
          'Set a spending cap for this block this month. Leave empty to remove the limit. The Overview bar turns amber near the cap and red when exceeded.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: B.soft2,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        _sheetField(
          'Limit (\u20ac)',
          _sheetInput(
            _ctrl,
            hint: '0,00',
            number: true,
            onChanged: (_) => setState(() {}),
          ),
        ),
        _primaryBtn(_ctrl.text.isEmpty ? 'Remove limit' : 'Save limit', () {
          s.saveCap(widget.cat, _ctrl.text.trim());
          Navigator.of(context).pop();
        }),
        if (widget.value != null)
          GestureDetector(
            onTap: () {
              s.saveCap(widget.cat, '');
              Navigator.of(context).pop();
            },
            child: const Padding(
              padding: EdgeInsets.only(top: 13, bottom: 2),
              child: Text(
                'Remove limit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: B.red,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =========================================================== glyph picker
/// Picks the visual for an account or budget block (issue #131): any emoji
/// (curated quick-picks plus a free-form field for the rest) or an uploaded
/// picture. Reports the choice through [onChanged]; the two are mutually
/// exclusive — choosing one clears the other.
class _GlyphPicker extends StatefulWidget {
  const _GlyphPicker({
    required this.emoji,
    required this.picture,
    required this.onChanged,
  });

  final String? emoji;
  final String? picture;
  final void Function({String? emoji, String? picture}) onChanged;

  @override
  State<_GlyphPicker> createState() => _GlyphPickerState();
}

class _GlyphPickerState extends State<_GlyphPicker> {
  String? _emoji;
  String? _picture;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _emoji = widget.emoji;
    _picture = widget.picture;
  }

  // coverage:ignore-start
  Future<void> _pickEmoji() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SizedBox(
          height: 340,
          child: ep.EmojiPicker(
            onEmojiSelected: (ep.Category? category, ep.Emoji emoji) {
              _selectEmoji(emoji.emoji);
              Navigator.of(sheetCtx).pop();
            },
            config: const ep.Config(
              height: 340,
              emojiViewConfig: ep.EmojiViewConfig(
                emojiSizeMax: 28,
                backgroundColor: Colors.white,
              ),
              categoryViewConfig: ep.CategoryViewConfig(
                backgroundColor: Colors.white,
                indicatorColor: B.primary,
                iconColorSelected: B.primary,
                backspaceColor: B.primary,
              ),
              bottomActionBarConfig: ep.BottomActionBarConfig(enabled: false),
            ),
          ),
        ),
      ),
    );
  }
  // coverage:ignore-end

  void _selectEmoji(String raw) {
    final e = raw.trim();
    setState(() {
      _emoji = e.isEmpty ? null : e;
      if (e.isNotEmpty) _picture = null;
    });
    widget.onChanged(emoji: _emoji, picture: _picture);
  }

  // coverage:ignore-start
  Future<void> _pickPicture() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _picture = base64Encode(bytes);
        _emoji = null;
      });
      widget.onChanged(emoji: null, picture: _picture);
    } catch (_) {
      /* ignore an unreadable image */
    }
  }
  // coverage:ignore-end

  void _clear() {
    setState(() {
      _emoji = null;
      _picture = null;
    });
    widget.onChanged(emoji: null, picture: null);
  }

  @override
  Widget build(BuildContext context) {
    final hasGlyph =
        (_emoji?.isNotEmpty ?? false) || (_picture?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              key: const ValueKey('glyph-pick-emoji'),
              onTap: _pickEmoji,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: B.faint,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: glyphTile(
                  size: 56,
                  radius: 15,
                  picture: _picture,
                  emoji: _emoji,
                  emojiSize: 30,
                  fallback: Center(
                    child: ic('plus', size: 20, sw: 2.2, color: B.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: const ValueKey('glyph-upload'),
                    onTap: _pickPicture,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: B.soft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ic('edit', size: 15, sw: 2.2, color: B.deep),
                          const SizedBox(width: 7),
                          const Text(
                            'Upload picture',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: B.deep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasGlyph)
                    GestureDetector(
                      key: const ValueKey('glyph-clear'),
                      onTap: _clear,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 7, left: 2),
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: B.red,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _numStr(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}
