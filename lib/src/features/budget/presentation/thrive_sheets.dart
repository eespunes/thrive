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

  void openExpenseSheet({
    required String mode,
    required String cat,
    String? id,
  }) {
    _showSheet(
      monthScoped: true,
      (ctx) => _ExpenseSheet(state: this, mode: mode, cat: cat, id: id),
    );
  }

  void openCapSheet(String cat, double? value) {
    _showSheet(
      monthScoped: true,
      (ctx) => _CapSheet(state: this, cat: cat, value: value),
    );
  }

  void openAccountSheet({required String mode, String? key}) {
    _showSheet((ctx) => _AccountSheet(state: this, mode: mode, accKey: key));
  }

  void openBlockSheet({required String mode, String? key}) {
    _showSheet((ctx) => _BlockSheet(state: this, mode: mode, blockKey: key));
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
        month.blocks[catKey]?.removeWhere((it) => _seriesIdFor(it) == seriesId);
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

  void saveExpense(
    String mode,
    String cat,
    String? id, {
    required String payee,
    required String label,
    required double amount,
    required String marker,
    required bool paid,
    required String account,
    String? until,
    required bool recurring,
    int recurEvery = 1,
    String? recurEndDate,
    String shift = 'none',
    String? cardId,
  }) {
    final every = recurEvery < 1 ? 1 : recurEvery;
    mutate(() {
      final month = data[year]![kMonthKeys[monthIdx]]!;
      final arr = month.blocks.putIfAbsent(cat, () => <ExpenseItem>[]);
      final normalizedEnd = normalizeRecurringEndDate(recurEndDate ?? until);
      if (mode == 'edit' && id != null) {
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
            amount: amount,
            paid: paid,
            account: account,
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
  }

  void deleteExpense(String cat, String id) {
    mutate(() {
      final m = data[year]![kMonthKeys[monthIdx]]!;
      final item = m.blocks[cat]?.where((x) => x.id == id).firstOrNull;
      final seriesId = item == null ? null : _seriesIdFor(item);
      if (seriesId != null && item?.recurring == true) {
        m.seriesStops.removeWhere((x) => x == seriesId);
        m.seriesStops.add(seriesId);
        _removeRecurringFromCurrentForward(seriesId, cat);
      } else {
        m.blocks[cat]?.removeWhere((x) => x.id == id);
      }
      swipedId = null;
    }, () => flash('Deleted'));
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

  void deleteAccount(String key) {
    if (accounts.length <= 1) return;
    final acc = accByKey(key);
    askDelete(
      acc.name,
      'Items paid from this account will move to your last account.',
      () {
        final remaining = accounts.where((a) => a.key != key).toList();
        final fallback = remaining.last.key;
        mutate(() {
          accounts = remaining;
          for (final yr in data.keys) {
            for (final mk in kMonthKeys) {
              final m = data[yr]![mk];
              if (m == null || m.closed) continue;
              for (final arr in m.blocks.values) {
                for (final it in arr) {
                  if (it.account == key) it.account = fallback;
                }
              }
            }
          }
        }, () => flash('Account removed'));
      },
    );
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

  void deleteBlock(String key) {
    if (cats.length <= 1) return;
    final cat = catByKey(key);
    askDelete(
      cat?.title ?? 'this block',
      'It stays in any closed months. Open months lose this block and its items.',
      () {
        update(() => cats.removeWhere((c) => c.key == key));
        _persist();
        mutate(() {
          for (final yr in data.keys) {
            for (final mk in kMonthKeys) {
              final m = data[yr]![mk];
              if (m == null || m.closed) continue;
              m.blocks.remove(key);
              m.caps.remove(key);
            }
          }
        }, () => flash('Block removed'));
      },
    );
  }
}

// ============================================================ sheet shell
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
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

// ========================================================== expense sheet
class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({
    required this.state,
    required this.mode,
    required this.cat,
    this.id,
  });
  final _ThriveHomeState state;
  final String mode;
  final String cat;
  final String? id;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final TextEditingController _payee;
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late final TextEditingController _marker;
  String _account = 'shared';
  bool _paid = false;
  bool _recurring = true;
  int _recurEvery = 1;
  String? _endDate;
  String _shift = 'none';
  String? _cardId;

  bool get _editing => widget.mode == 'edit';

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    ExpenseItem? it;
    if (_editing) {
      it = (s.cur()?.blocks[widget.cat] ?? [])
          .where((x) => x.id == widget.id)
          .firstOrNull;
    }
    _payee = TextEditingController(text: it?.payee ?? '');
    _label = TextEditingController(text: it?.label ?? '');
    _amount = TextEditingController(text: it != null ? _numStr(it.amount) : '');
    _marker = TextEditingController(text: it?.marker ?? '');
    _account = it?.account ?? 'shared';
    _paid = it?.paid ?? false;
    _recurring = it?.recurring ?? true;
    _recurEvery = it?.recurEvery ?? 1;
    _endDate = normalizeRecurringEndDate(it?.recurEndDate ?? it?.until);
    _shift = it?.shift ?? 'none';
    _cardId = it?.cardId;
  }

  /// Discount-card picker (issue #230): none / one of the family's cards /
  /// "Scan new", which drops into the camera import flow.
  Widget _cardChips(_ThriveHomeState s) {
    Widget chip(
      Key key,
      String label,
      bool on,
      VoidCallback onTap, {
      Color? dot,
    }) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: on ? B.soft : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? B.primary : B.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 14,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dot,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? B.deep : B.text,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        chip(
          const ValueKey('exp-card-none'),
          'None',
          _cardId == null,
          () => setState(() => _cardId = null),
        ),
        for (final c in s.cards)
          chip(
            ValueKey('exp-card-${c.id}'),
            c.name,
            _cardId == c.id,
            () => setState(() => _cardId = c.id),
            dot: c.color,
          ),
        chip(const ValueKey('exp-card-scan'), 'Scan new', false, () {
          Navigator.of(context).pop();
          s.openCardScan();
        }),
      ],
    );
  }

  @override
  void dispose() {
    _payee.dispose();
    _label.dispose();
    _amount.dispose();
    _marker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cat = s.catByKey(widget.cat)!;
    final valid =
        (_payee.text.trim().isNotEmpty || _label.text.trim().isNotEmpty) &&
        parseNum(_amount.text) >= 0;

    void submit() {
      s.saveExpense(
        widget.mode,
        widget.cat,
        widget.id,
        payee: _payee.text.trim(),
        label: _label.text.trim(),
        amount: parseNum(_amount.text),
        marker: _marker.text.trim(),
        paid: _paid,
        account: _account,
        until: _endDate,
        recurring: _recurring,
        recurEvery: _recurEvery,
        recurEndDate: _endDate,
        shift: _shift,
        cardId: _cardId,
      );
      Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeadWithTick(
          context,
          '${_editing ? 'Edit ' : 'Add '}${cat.title.toLowerCase()}',
          sub: _editing ? null : 'New item',
          onConfirm: submit,
          confirmEnabled: valid,
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetField(
                  cat.isIncome ? 'From' : 'Company',
                  _sheetInput(
                    _payee,
                    hint: cat.isIncome ? 'e.g. Employer' : 'e.g. Thuiswonen',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                _sheetField(
                  'Subcategory',
                  _sheetInput(
                    _label,
                    hint: cat.isIncome ? 'e.g. Salary' : 'e.g. Rent',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _sheetField(
                        'Amount (\u20ac)',
                        _sheetInput(
                          _amount,
                          hint: '0,00',
                          number: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _sheetField(
                        cat.isIncome || cat.marker == 'day'
                            ? 'Pay day'
                            : 'Date',
                        _sheetInput(
                          _marker,
                          hint: cat.isIncome || cat.marker == 'day'
                              ? '1st'
                              : '\u2014',
                        ),
                      ),
                    ),
                  ],
                ),
                _shiftField(cat.isIncome ? 'in' : 'out'),
                _sheetField(
                  '',
                  _toggleRow(
                    'Repeat',
                    _recurring,
                    () => setState(() => _recurring = !_recurring),
                    subtitle:
                        'Saves edits from this month forward without changing history',
                    activeColor: B.primary,
                  ),
                ),
                if (_recurring) _sheetField('Repeat every', _recurEveryRow()),
                if (cat.hasUntil || _recurring)
                  _sheetField(
                    _recurring ? 'Repeat until' : 'End date',
                    _endDateField(context),
                  ),
                _sheetField(
                  cat.isIncome
                      ? 'Received into'
                      : (cat.isSavings ? 'Save from' : 'Pay from'),
                  _accChips(),
                ),
                if (!cat.isIncome) _sheetField('Discount card', _cardChips(s)),
                _sheetField(
                  'Status',
                  _toggleRow(
                    cat.isIncome
                        ? 'Received'
                        : (cat.isSavings ? 'Saved this month' : 'Paid'),
                    _paid,
                    () => setState(() => _paid = !_paid),
                  ),
                ),
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(top: 13, bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ic('cleft', size: 13, sw: 2.4, color: B.muted),
                        const SizedBox(width: 6),
                        const Text(
                          'Swipe the row left to delete',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: B.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _accChips() {
    return Row(
      children: [
        for (final a in widget.state.accounts) ...[
          if (a != widget.state.accounts.first) const SizedBox(width: 8),
          Expanded(child: _accChip(a)),
        ],
      ],
    );
  }

  Widget _accChip(Account a) {
    final sel = a.key == _account;
    return GestureDetector(
      onTap: () => setState(() => _account = a.key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? B.soft : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: sel ? B.primary : B.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: a.color,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: glyphTile(
                size: 24,
                radius: 7,
                picture: a.picture,
                emoji: a.emoji,
                emojiSize: 13,
                fallback: Text(
                  a.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              a.short,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: B.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // coverage:ignore-start
  Future<void> _pickEndDate(BuildContext context) async {
    final initial = _endDate == null ? null : DateTime.tryParse(_endDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          initial ?? DateTime(widget.state.year, widget.state.monthIdx + 1, 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _endDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}',
    );
  }
  // coverage:ignore-end

  Widget _endDateField(BuildContext context) {
    final label = _endDate == null
        ? 'Choose date'
        : '${untilLabel(_endDate)} · ${_endDate!}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('expense-end-date'),
          onTap: () => _pickEndDate(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: B.line),
            ),
            child: Row(
              children: [
                ic('cal', size: 15, sw: 2.2, color: B.soft2),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _endDate == null ? B.muted : B.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_endDate != null)
          GestureDetector(
            onTap: () => setState(() => _endDate = null),
            child: const Padding(
              padding: EdgeInsets.only(top: 8, left: 2),
              child: Text(
                'Clear end date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: B.red,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The weekend rule field (issue #199 — Money calendar): 'none' keeps the
  /// marker's exact day, 'before' moves it to the last working day before a
  /// Saturday/Sunday (typical for salary), 'after' to the first working day
  /// after. Shared by expense and income items alike since income is just an
  /// income-direction block.
  Widget _shiftField(String kind) {
    const opts = [
      ('none', 'Keep the date', 'pin'),
      ('before', 'Friday before', 'cleft'),
      ('after', 'Monday after', 'cright'),
    ];
    Widget btn((String, String, String) o) {
      final on = _shift == o.$1;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('expense-shift-${o.$1}'),
          onTap: () => setState(() => _shift = o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: on ? B.soft : Colors.white,
              border: Border.all(color: on ? B.primary : B.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ic(o.$3, size: 15, sw: 2.3, color: on ? B.deep : B.muted),
                const SizedBox(height: 5),
                Text(
                  o.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: on ? B.deep : B.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final helper = _shift == 'none'
        ? 'The calendar keeps this exact day, weekend or not.'
        : _shift == 'before'
        ? 'Typical for salary \u2014 ${kind == 'in' ? 'paid' : 'taken'} on the last working day before the weekend.'
        : 'Moves to the first working day after the weekend.';
    return _sheetField(
      'If it lands on a weekend',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final o in opts) ...[
                if (o != opts.first) const SizedBox(width: 8),
                btn(o),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Text(
            helper,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: B.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Interval picker for the custom "repeat every N months" setting
  /// (issue #191). Common presets cover the typical cases (monthly,
  /// quarterly, yearly...) while the stepper lets any interval be dialled in.
  Widget _recurEveryRow() {
    const presets = [1, 2, 3, 6, 12];
    Widget stepBtn(String icon, VoidCallback onTap) => GestureDetector(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in presets) ...[
                GestureDetector(
                  key: ValueKey('expense-recur-every-$option'),
                  onTap: () => setState(() => _recurEvery = option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _recurEvery == option ? B.soft : Colors.white,
                      border: Border.all(
                        color: _recurEvery == option ? B.primary : B.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      option == 1 ? 'Monthly' : 'Every $option months',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _recurEvery == option ? B.deep : B.soft2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            stepBtn(
              'cleft',
              () =>
                  setState(() => _recurEvery = (_recurEvery - 1).clamp(1, 60)),
            ),
            Expanded(
              child: Text(
                _recurEvery == 1 ? 'Every month' : 'Every $_recurEvery months',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: B.ink,
                ),
              ),
            ),
            stepBtn(
              'cright',
              () =>
                  setState(() => _recurEvery = (_recurEvery + 1).clamp(1, 60)),
            ),
          ],
        ),
      ],
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

// ========================================================== account sheet
class _AccountSheet extends StatefulWidget {
  const _AccountSheet({required this.state, required this.mode, this.accKey});
  final _ThriveHomeState state;
  final String mode;
  final String? accKey;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late final TextEditingController _name;
  late final TextEditingController _short;
  late Color _color;
  String? _emoji;
  String? _picture;

  bool get _editing => widget.mode == 'edit';

  @override
  void initState() {
    super.initState();
    Account? a;
    if (_editing) a = widget.state.accByKey(widget.accKey!);
    _name = TextEditingController(text: a?.name ?? '');
    _short = TextEditingController(text: a?.short ?? '');
    _color = a?.color ?? kAccPalette.first;
    _emoji = a?.emoji;
    _picture = a?.picture;
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final valid = _name.text.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(context, _editing ? 'Edit account' : 'Add account'),
          _sheetField(
            'Emoji or picture',
            _GlyphPicker(
              emoji: _emoji,
              picture: _picture,
              onChanged: ({String? emoji, String? picture}) {
                _emoji = emoji;
                _picture = picture;
              },
            ),
          ),
          _sheetField(
            'Name',
            _sheetInput(
              _name,
              hint: "e.g. Eva's account",
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField('Short label', _sheetInput(_short, hint: 'Eva')),
          _sheetField('Color', _swatches()),
          _primaryBtn(_editing ? 'Save account' : 'Add account', () {
            s.saveAccount(
              widget.mode,
              widget.accKey,
              name: _name.text.trim(),
              short: _short.text.trim(),
              color: _color,
              emoji: _emoji,
              picture: _picture,
            );
            Navigator.of(context).pop();
          }, enabled: valid),
        ],
      ),
    );
  }

  Widget _swatches() {
    return _BudgetColorPicker(
      quickColors: kAccPalette,
      selected: _color,
      onChanged: (col) => setState(() => _color = col),
    );
  }
}

// ============================================================ block sheet
class _BlockSheet extends StatefulWidget {
  const _BlockSheet({required this.state, required this.mode, this.blockKey});
  final _ThriveHomeState state;
  final String mode;
  final String? blockKey;

  @override
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
  late final TextEditingController _title;
  late final TextEditingController _cap;
  String _icon = 'folder';
  String? _emoji;
  String? _picture;
  Color _tone = kCatPalette.first;
  bool _hasUntil = false;
  bool _temporary = false;
  bool _isIncome = false;
  bool _isSavings = false;

  bool get _editing => widget.mode == 'edit';

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    Category? c;
    double? cap;
    if (_editing) {
      c = s.catByKey(widget.blockKey!);
      cap = s.cur()?.caps[c?.key];
    }
    _title = TextEditingController(text: c?.title ?? '');
    _cap = TextEditingController(text: cap != null ? _numStr(cap) : '');
    _icon = c?.icon ?? 'folder';
    _emoji = c?.emoji;
    _picture = c?.picture;
    _tone = c?.tone ?? kCatPalette.first;
    _hasUntil = c?.hasUntil ?? false;
    _temporary = c?.temporary ?? false;
    _isIncome = c?.isIncome ?? false;
    _isSavings = c?.isSavings ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _cap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final valid = _title.text.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(context, _editing ? 'Edit block' : 'New budget block'),
          _sheetField(
            'Emoji or picture',
            _GlyphPicker(
              emoji: _emoji,
              picture: _picture,
              onChanged: ({String? emoji, String? picture}) {
                _emoji = emoji;
                _picture = picture;
              },
            ),
          ),
          _sheetField(
            'Name',
            _sheetInput(
              _title,
              hint: 'e.g. Kids',
              onChanged: (_) => setState(() {}),
            ),
          ),
          _sheetField('Money direction', _directionSeg()),
          _sheetField('Color', _swatches()),
          _sheetField('Applies to', _scopeSeg()),
          if (_temporary)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 13),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: B.amberSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: B.amberLine),
              ),
              child: Text(
                'Only appears in ${kMonthsEn[s.monthIdx]} ${s.year}. Add recurring items inside the block when costs should continue into later months.',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: B.amberText,
                  height: 1.45,
                ),
              ),
            ),
          // Limits, end dates and the savings flag only apply to blocks that
          // withdraw money — income blocks just receive it (issue #137).
          if (!_isIncome) ...[
            _sheetField(
              'Monthly limit for ${kMonthsEn[s.monthIdx]} (optional)',
              _sheetInput(_cap, hint: 'No limit', number: true),
            ),
            _sheetField(
              '',
              _toggleRow(
                'Track end date',
                _hasUntil,
                () => setState(() => _hasUntil = !_hasUntil),
                subtitle: 'For loans & debts with a payoff date',
                activeColor: B.primary,
              ),
            ),
            _sheetField(
              '',
              _toggleRow(
                'Counts as savings',
                _isSavings,
                () => setState(() => _isSavings = !_isSavings),
                subtitle: 'Include this block in your savings statistics',
                activeColor: B.primary,
              ),
            ),
          ],
          _primaryBtn(_editing ? 'Save block' : 'Create block', () {
            s.saveBlock(
              widget.mode,
              widget.blockKey,
              title: _title.text.trim(),
              icon: _icon,
              emoji: _emoji,
              picture: _picture,
              tone: _tone,
              hasUntil: _isIncome ? false : _hasUntil,
              temporary: _temporary,
              capRaw: _isIncome ? '' : _cap.text.trim(),
              isIncome: _isIncome,
              isSavings: _isIncome ? false : _isSavings,
            );
            Navigator.of(context).pop();
          }, enabled: valid),
        ],
      ),
    );
  }

  Widget _swatches() {
    return _BudgetColorPicker(
      quickColors: kCatPalette,
      selected: _tone,
      onChanged: (col) => setState(() => _tone = col),
    );
  }

  Widget _directionSeg() {
    Widget btn(bool active, String icon, String label, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              decoration: BoxDecoration(
                color: active ? B.soft : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? B.primary : B.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ic(icon, size: 15, sw: 2.2, color: active ? B.deep : B.soft2),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? B.deep : B.soft2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        btn(
          !_isIncome,
          'cart',
          'Withdraws',
          () => setState(() => _isIncome = false),
        ),
        const SizedBox(width: 8),
        btn(_isIncome, 'wallet', 'Receives', () {
          setState(() {
            _isIncome = true;
            _isSavings = false;
          });
        }),
      ],
    );
  }

  Widget _scopeSeg() {
    Widget btn(bool active, String icon, String label, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              decoration: BoxDecoration(
                color: active ? B.soft : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? B.primary : B.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ic(icon, size: 15, sw: 2.2, color: active ? B.deep : B.soft2),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? B.deep : B.soft2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        btn(
          !_temporary,
          'repeat',
          'Every month',
          () => setState(() => _temporary = false),
        ),
        const SizedBox(width: 8),
        btn(
          _temporary,
          'pin',
          'This month only',
          () => setState(() => _temporary = true),
        ),
      ],
    );
  }
}

String _numStr(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}
