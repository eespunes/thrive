part of 'package:family_money_management_app/main.dart';

final ImagePicker _walletPicker = ImagePicker();

/// Wallet sheets, mirroring the design's `sheetCardWallet` and the
/// three-stage `sheetCardScan` (pick → reading → review).
extension _ThriveWalletSheets on _ThriveHomeState {
  /// Opens the scan flow at its "pick a photo" stage (design
  /// `openCardScan`). Used by the wallet sheet, Quick add, the expense
  /// sheet's "Scan new" and the Home widget's Scan tile.
  void openCardScan() {
    if (childBlocked('Discount cards aren’t available on a kid profile')) {
      return;
    }
    openEditorSheet<void>((ctx) => _CardScanSheet(state: this));
  }

  /// Camera capture or gallery import — same pipeline and review step for
  /// both (issues #225/#226). Kept for programmatic use; the sheet flow
  /// calls [importCardFromBytes] itself.
  // Drives the native image picker, so it can't run under flutter_test.
  // coverage:ignore-start
  Future<Uint8List?> pickCardPhoto(ImageSource source) async {
    try {
      final file = await _walletPicker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 88,
      );
      return file == null ? null : await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> startCardImport(ImageSource source) async {
    final bytes = await pickCardPhoto(source);
    if (bytes == null) return;
    importCardFromBytes(bytes, source: source);
  }
  // coverage:ignore-end

  /// Pure part of the import: opens the scan sheet directly at the
  /// "reading" stage with [bytes], which analyzes and moves to review.
  void importCardFromBytes(
    Uint8List bytes, {
    ImageSource source = ImageSource.gallery,
  }) {
    openEditorSheet<void>(
      (ctx) => _CardScanSheet(state: this, initialPhoto: bytes, source: source),
    );
  }
}

// ============================================================ wallet list

/// The wallet sheet (design `sheetCardWallet`): swipe-to-delete card rows,
/// "Scan a card", "Pin the wallet to my home" and the explainer footer.
class _WalletSheet extends StatefulWidget {
  const _WalletSheet({required this.state});
  final _ThriveHomeState state;

  @override
  State<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<_WalletSheet> {
  _ThriveHomeState get s => widget.state;
  String? _swiped;

  Widget _row(DiscountCard c) {
    final photo = c.photo;
    final inner = GestureDetector(
      key: ValueKey('wallet-card-${c.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        s.openCardFace(c.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        color: context.tc.surface,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 32,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1f0f172a)),
              ),
              child: photo != null
                  ? Image.memory(
                      base64Decode(photo),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : Center(
                      child: ic(
                        c.codeType == 'qr' ? 'grid' : 'signal',
                        size: 15,
                        sw: 2.2,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: context.tc.ink,
                    ),
                  ),
                  Text(
                    '${c.maskedNumber} · '
                    '${cardLastUsedLabel(c.lastUsedMillis, DateTime.now())}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tc.soft2,
                    ),
                  ),
                ],
              ),
            ),
            ic('cright', size: 17, sw: 2.2, color: context.tc.muted),
          ],
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.tc.line),
      ),
      child: _SwipeRow(
        key: ValueKey('wallet-swipe-${c.id}'),
        open: _swiped == c.id,
        onOpenChanged: (open) => setState(() => _swiped = open ? c.id : null),
        onDelete: () {
          Navigator.of(context).pop();
          s.confirmDeleteCard(c);
        },
        borderRadius: 14,
        child: inner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: s._rev,
      builder: (context, _, _) {
        final list = s.cards;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHead(
              context,
              'Discount cards',
              list.isEmpty
                  ? 'Nothing scanned yet'
                  : '${list.length} card${list.length == 1 ? '' : 's'} · '
                        'shared with the family',
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          children: [
                            ic(
                              'card',
                              size: 32,
                              sw: 1.8,
                              color: context.tc.muted,
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'No cards yet',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: context.tc.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 30),
                              child: Text(
                                'Snap a loyalty card once — everyone in the '
                                'family can use it at the till.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.tc.muted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [for (final c in list) _row(c)],
                        ),
                      ),
                    KeyedSubtree(
                      key: const ValueKey('wallet-scan'),
                      child: _primaryBtn('Scan a card', () {
                        Navigator.of(context).pop();
                        s.openCardScan();
                      }),
                    ),
                    GestureDetector(
                      key: const ValueKey('wallet-pin'),
                      onTap: () {
                        Navigator.of(context).pop();
                        s.pinWalletWidget();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 9),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: context.tc.surface,
                          border: Border.all(color: context.tc.line),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ic(
                              'home',
                              size: 15,
                              sw: 2.2,
                              color: context.tc.deep,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Pin the wallet to my home',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.tc.deep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(10, 11, 10, 0),
                      child: Text(
                        'Photograph the barcode side. Thrive reads the number '
                        'and picks up the card colour, then you can attach a '
                        'card to anything you pay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.tc.muted,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================== scanning

/// The scan flow (design `sheetCardScan`): pick → reading → review.
class _CardScanSheet extends StatefulWidget {
  const _CardScanSheet({
    required this.state,
    this.initialPhoto,
    this.source = ImageSource.camera,
  });
  final _ThriveHomeState state;
  final Uint8List? initialPhoto;
  final ImageSource source;

  @override
  State<_CardScanSheet> createState() => _CardScanSheetState();
}

class _CardScanSheetState extends State<_CardScanSheet> {
  _ThriveHomeState get s => widget.state;

  String _stage = 'pick'; // pick | reading | review
  Uint8List? _photo;
  CardScanResult _scan = const CardScanResult();
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _code = TextEditingController();
  late final TextEditingController _note = TextEditingController();
  String _type = 'barcode';
  late Color _color = kCardPalette.first;
  // Family cards default to unassigned — an owner is opt-in via the picker.
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    final photo = widget.initialPhoto;
    if (photo != null) _read(photo);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  /// "Reading the card": show the scan animation while the pure pipeline
  /// runs, then land on review with what it could read.
  void _read(Uint8List bytes) {
    setState(() {
      _stage = 'reading';
      _photo = bytes;
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final scan = analyzeCardImage(bytes);
      setState(() {
        _stage = 'review';
        _scan = scan;
        _code.text = digitsOnly(scan.number ?? '');
        _type = scan.codeType;
        _color = scan.color ?? kCardPalette.first;
      });
    });
  }

  // Drives the native image picker.
  // coverage:ignore-start
  Future<void> _pick(ImageSource source) async {
    final bytes = await s.pickCardPhoto(source);
    if (bytes != null && mounted) _read(bytes);
  }
  // coverage:ignore-end

  void _save() {
    s.saveCard(
      DiscountCard(
        id: uid(),
        name: _name.text.trim(),
        number: digitsOnly(_code.text),
        codeType: _type,
        color: _color,
        // The photo is scan-time input only (number/colour sampling) — it is
        // never persisted, not even locally.
        photo: null,
        note: _note.text.trim(),
        ownerId: _ownerId,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final id = s.cards.last.id;
    Navigator.of(context).pop();
    // The design opens the freshly saved card's face right away.
    s.openCardFace(id);
  }

  Widget _cameraTile() => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      color: context.tc.soft,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Center(
      child: ic('camera', size: 30, sw: 2, color: context.tc.primary),
    ),
  );

  Widget _wideBtn(
    Key key,
    String label, {
    required VoidCallback onTap,
    bool filled = false,
    bool link = false,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: link ? 44 : 52),
        alignment: Alignment.center,
        decoration: link
            ? null
            : BoxDecoration(
                color: filled ? context.tc.primary : context.tc.surface,
                border: filled
                    ? null
                    : Border.all(color: context.tc.line, width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: link ? 13 : 14.5,
            fontWeight: FontWeight.w800,
            color: filled
                ? Colors.white
                : link
                ? context.tc.deep
                : context.tc.ink,
          ),
        ),
      ),
    );
  }

  List<Widget> _pickStage() => [
    Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Column(
        children: [
          _cameraTile(),
          const SizedBox(height: 14),
          Text(
            'Take a photo of the card',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.tc.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Barcode side up. We read the number and match the colour.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.tc.soft2,
            ),
          ),
          const SizedBox(height: 14),
          _wideBtn(
            const ValueKey('wallet-scan-camera'),
            'Take photo',
            filled: true,
            onTap: () => unawaited(_pick(ImageSource.camera)),
          ),
          const SizedBox(height: 8),
          _wideBtn(
            const ValueKey('wallet-scan-gallery'),
            'Choose from photos',
            onTap: () => unawaited(_pick(ImageSource.gallery)),
          ),
          const SizedBox(height: 8),
          _wideBtn(
            const ValueKey('wallet-scan-manual'),
            'Type the number instead',
            link: true,
            onTap: () => setState(() {
              _stage = 'review';
              _photo = null;
              _scan = const CardScanResult();
            }),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _readingStage() => [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          _cameraTile(),
          const SizedBox(height: 12),
          Text(
            'Finding the barcode…',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.tc.deep,
            ),
          ),
        ],
      ),
    ),
  ];

  Widget _status(Key key, String label, bool ok) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? context.tc.soft : context.tc.amberSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ok) ...[
            ic('check', size: 12, sw: 2.6, color: context.tc.deep),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ok ? context.tc.deep : context.tc.amberText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final on = contrastOn(_color);
    final code = digitsOnly(_code.text);
    final name = _name.text.trim();
    return Container(
      key: const ValueKey('card-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _color,
            blurRadius: 26,
            spreadRadius: -16,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name.isEmpty ? 'Shop name' : name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
              color: on,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.tc.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                CustomPaint(
                  size: _type == 'qr'
                      ? const Size(64, 64)
                      : const Size(double.infinity, 44),
                  painter: _EdCodePainter(qr: _type == 'qr'),
                ),
                const SizedBox(height: 6),
                Text(
                  code.isEmpty ? '— — — —' : code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: context.tc.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _reviewStage() {
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    final hasCode = digitsOnly(_code.text).isNotEmpty;
    final hasName = _name.text.trim().isNotEmpty;
    final scanned = _photo != null;
    return [
      _preview(),
      if (scanned)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _status(
              const ValueKey('badge-number'),
              hasCode
                  ? (_type == 'qr' ? 'QR code read' : 'Barcode read')
                  : 'Type the number',
              hasCode,
            ),
            _status(
              const ValueKey('badge-color'),
              _scan.colorSampled ? 'Colour matched' : 'Pick a colour',
              _scan.colorSampled,
            ),
            _status(
              const ValueKey('badge-name'),
              hasName ? 'Shop name added' : 'Add the shop name',
              hasName,
            ),
          ],
        ),
      edGroup([
        edBareInput(
          key: const ValueKey('card-name'),
          controller: _name,
          hint: 'Shop name — e.g. Supermarket around the corner',
          onChanged: (_) => setState(() {}),
        ),
        edBareInput(
          key: const ValueKey('card-number'),
          controller: _code,
          hint: 'Card number',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        edBareInput(
          key: const ValueKey('card-note'),
          controller: _note,
          hint: 'Note (optional) — e.g. 5% off garden plants',
        ),
      ]),
      EdSegmented<String>(
        keyPrefix: 'card-type',
        options: const [('barcode', 'Barcode'), ('qr', 'QR code')],
        value: _type,
        onChanged: (v) => setState(() => _type = v),
      ),
      EdSection(
        label: 'Whose card is it?',
        child: edChipWrap([
          edChip(
            key: const ValueKey('card-owner-all'),
            label: 'Everyone',
            selected: _ownerId == null,
            onTap: () => setState(() => _ownerId = null),
          ),
          for (final m in members)
            edChip(
              key: ValueKey('card-owner-${m.id}'),
              label: m.name,
              tone: m.color,
              selected: _ownerId == m.id,
              // Tapping the selected member again goes back to everyone.
              onTap: () =>
                  setState(() => _ownerId = _ownerId == m.id ? null : m.id),
            ),
        ]),
      ),
      edColourSection(
        _color,
        (c) => setState(() => _color = c),
        label: 'Card colour',
      ),
      if (scanned)
        _wideBtn(
          const ValueKey('card-retake'),
          'Retake the photo',
          link: true,
          onTap: () => setState(() {
            _stage = 'pick';
            _photo = null;
            _code.clear();
          }),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final review = _stage == 'review';
    final title = switch (_stage) {
      'reading' => 'Reading the card',
      'review' => 'Check the details',
      _ => 'Scan a card',
    };
    String? reason;
    if (_name.text.trim().isEmpty) {
      reason = 'Add the shop name';
    } else if (digitsOnly(_code.text).isEmpty) {
      reason = 'Type the card number';
    }
    final owner = _ownerId == null
        ? null
        : (s.curFamily()?.members ?? const <FamilyMember>[])
              .where((m) => m.id == _ownerId)
              .firstOrNull
              ?.name;
    return EditorSheet(
      title: title,
      subtitle: review && _photo != null
          ? 'We filled in what we could read'
          : null,
      showFooter: review,
      confirmKey: const ValueKey('card-save'),
      confirmLabel: 'Save card',
      blockedReason: reason,
      onConfirm: _save,
      summary:
          '${_type == 'qr' ? 'QR code' : 'Barcode'} · '
          '${owner == null ? 'shared with everyone' : "$owner's card"}',
      children: switch (_stage) {
        'reading' => _readingStage(),
        'review' => _reviewStage(),
        _ => _pickStage(),
      },
    );
  }
}

/// A stylised barcode (stripes) or QR (checker) for the card preview.
class _EdCodePainter extends CustomPainter {
  const _EdCodePainter({required this.qr});
  final bool qr;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = ThriveColors.current.ink;
    if (qr) {
      const cell = 5.0;
      for (var y = 0.0; y < size.height; y += cell) {
        for (var x = 0.0; x < size.width; x += cell) {
          if (((x ~/ cell) + (y ~/ cell)).isEven) {
            canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), p);
          }
        }
      }
      return;
    }
    // Repeating 11px pattern from the design: bars at 0-2, 3-4, 7-10.
    for (var x = 0.0; x < size.width; x += 11) {
      for (final (a, b) in const [(0, 2), (3, 4), (7, 10)]) {
        final w = (b - a).toDouble();
        canvas.drawRect(Rect.fromLTWH(x + a, 0, w, size.height), p);
      }
    }
  }

  @override
  bool shouldRepaint(_EdCodePainter old) => old.qr != qr;
}
