part of 'package:family_money_management_app/main.dart';

final ImagePicker _walletPicker = ImagePicker();

/// Wallet sheets, mirroring the design's `sheetCardWallet` and the
/// three-stage `sheetCardScan` (pick → reading → review).
extension _ThriveWalletSheets on _ThriveHomeState {
  /// Opens the scan flow at its "pick a photo" stage (design
  /// `openCardScan`). Used by the wallet sheet, Quick add, the expense
  /// sheet's "Scan new" and the Home widget's Scan tile.
  void openCardScan() {
    _showSheet((ctx) => _CardScanSheet(state: this));
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
    _showSheet(
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
        color: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: B.ink,
                    ),
                  ),
                  Text(
                    '${c.maskedNumber} · '
                    '${cardLastUsedLabel(c.lastUsedMillis, DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: B.soft2,
                    ),
                  ),
                ],
              ),
            ),
            ic('cright', size: 17, sw: 2.2, color: B.muted),
          ],
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: B.line),
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
                            ic('card', size: 32, sw: 1.8, color: B.muted),
                            const SizedBox(height: 9),
                            const Text(
                              'No cards yet',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: B.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 30),
                              child: Text(
                                'Snap a loyalty card once — everyone in the '
                                'family can use it at the till.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: B.muted,
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
                          color: Colors.white,
                          border: Border.all(color: B.line),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ic('home', size: 15, sw: 2.2, color: B.deep),
                            const SizedBox(width: 7),
                            const Text(
                              'Pin the wallet to my home',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: B.deep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 11, 10, 0),
                      child: Text(
                        'Photograph the barcode side. Thrive reads the number '
                        'and picks up the card colour, then you can attach a '
                        'card to anything you pay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: B.muted,
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
  late String? _ownerId = s.myId;

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
        photo: _photo != null ? base64Encode(_photo!) : null,
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

  Widget _pickStage() {
    Widget btn(
      Key key,
      String label,
      String icon,
      bool filled,
      VoidCallback onTap,
    ) {
      return Expanded(
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: filled ? B.primary : Colors.white,
              border: Border.all(color: filled ? B.primary : B.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ic(
                  icon,
                  size: 16,
                  sw: 2.2,
                  color: filled ? Colors.white : B.deep,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: filled ? Colors.white : B.deep,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xfff8fafc), Color(0xffeef2f7)],
            ),
            border: Border.all(color: const Color(0xffcfd8e3), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: B.soft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: ic('camera', size: 26, sw: 2, color: B.primary),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Take a photo of the card',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: B.ink,
                ),
              ),
              const SizedBox(height: 5),
              const SizedBox(
                width: 256,
                child: Text(
                  'Thrive reads the barcode number and picks up the card '
                  'colour, so it looks like the real card in your wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: B.soft2,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            btn(
              const ValueKey('wallet-scan-camera'),
              'Take photo',
              'camera',
              true,
              () => unawaited(_pick(ImageSource.camera)),
            ),
            const SizedBox(width: 9),
            btn(
              const ValueKey('wallet-scan-gallery'),
              'From photos',
              'folder',
              false,
              () => unawaited(_pick(ImageSource.gallery)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _readingStage() {
    final photo = _photo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 182,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: B.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo != null)
                Image.memory(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .6),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xff3ee0c4),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ic('camera', size: 16, sw: 2.3, color: B.primary),
            const SizedBox(width: 8),
            const Text(
              'Finding the barcode…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: B.deep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _badge(Key key, String icon, String label, Color bg, Color fg) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ic(icon, size: 13, sw: 2.4, color: fg),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewStage() {
    final photo = _photo;
    final cols = <Color>[
      _color,
      for (final c in kCardPalette)
        if (c.toARGB32() != _color.toARGB32()) c,
    ];
    final members = s.curFamily()?.members ?? const <FamilyMember>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 106,
              height: 74,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x1f0f172a)),
              ),
              child: photo != null
                  ? Image.memory(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _badge(
                    const ValueKey('badge-number'),
                    _scan.numberDetected ? 'check' : 'clock',
                    _scan.numberDetected
                        ? (_scan.codeType == 'qr'
                              ? 'QR code read'
                              : 'Barcode read')
                        : 'Type the number',
                    _scan.numberDetected ? B.greenSoft : B.faint,
                    _scan.numberDetected ? B.greenText : B.soft2,
                  ),
                  const SizedBox(height: 6),
                  _badge(
                    const ValueKey('badge-color'),
                    'gauge',
                    _scan.colorSampled ? 'Colour matched' : 'Pick a colour',
                    B.soft,
                    B.deep,
                  ),
                  const SizedBox(height: 6),
                  _badge(
                    const ValueKey('badge-name'),
                    'note',
                    'Add the shop name',
                    B.amberSoft,
                    B.amberText,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _sheetField(
          'Shop name',
          _sheetInput(
            _name,
            hint: 'e.g. Supermarket around the corner',
            onChanged: (_) => setState(() {}),
          ),
        ),
        _sheetField(
          'Card number',
          _sheetInput(_code, hint: '13 digits', number: true),
        ),
        _sheetField(
          'Code type',
          Row(
            children: [
              for (final (v, label) in const [
                ('barcode', 'Barcode'),
                ('qr', 'QR code'),
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    key: ValueKey('card-type-$v'),
                    onTap: () => setState(() => _type = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == v ? B.primary : Colors.white,
                        border: Border.all(
                          color: _type == v ? B.primary : B.line,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _type == v ? Colors.white : B.text,
                        ),
                      ),
                    ),
                  ),
                ),
                if (v == 'barcode') const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        _sheetField(
          'Card colour',
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final col in cols)
                GestureDetector(
                  key: ValueKey('card-color-${col.toARGB32()}'),
                  onTap: () => setState(() => _color = col),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: _color.toARGB32() == col.toARGB32()
                            ? B.ink
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _sheetField(
          'Note (optional)',
          _sheetInput(_note, hint: 'e.g. 5% off garden plants'),
        ),
        _sheetField(
          'Whose card is it',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in members)
                GestureDetector(
                  key: ValueKey('card-owner-${m.id}'),
                  onTap: () => setState(() => _ownerId = m.id),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 5, 11, 5),
                    decoration: BoxDecoration(
                      color: _ownerId == m.id ? B.soft : Colors.white,
                      border: Border.all(
                        color: _ownerId == m.id ? B.primary : B.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        s.avatarNode(
                          photo: m.photo,
                          emoji: m.emoji,
                          initials: m.initials,
                          color: m.color,
                          size: 22,
                          radius: 11,
                          fs: 10,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _ownerId == m.id ? B.deep : B.soft2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        KeyedSubtree(
          key: const ValueKey('card-save'),
          child: _primaryBtn(
            'Save card',
            _save,
            enabled: _name.text.trim().isNotEmpty,
          ),
        ),
        Center(
          child: GestureDetector(
            key: const ValueKey('card-retake'),
            onTap: () => setState(() {
              _stage = 'pick';
              _photo = null;
              _code.clear();
            }),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(0, 13, 0, 2),
              child: Text(
                'Retake the photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: B.soft2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, sub) = switch (_stage) {
      'reading' => ('Reading the card', 'One second…'),
      'review' => ('Check the details', 'We filled in what we could read'),
      _ => ('Scan a discount card', 'Point at the barcode side'),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, title, sub),
        Flexible(
          child: SingleChildScrollView(
            child: switch (_stage) {
              'reading' => _readingStage(),
              'review' => _reviewStage(),
              _ => _pickStage(),
            },
          ),
        ),
      ],
    );
  }
}
