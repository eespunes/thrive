part of 'package:family_money_management_app/main.dart';

final ImagePicker _walletPicker = ImagePicker();

/// Card import flow (issues #225–#227): camera or gallery photo → detection
/// pipeline → review-and-correct sheet. Plus the "pay something with it"
/// picker (issue #232).
extension _ThriveWalletSheets on _ThriveHomeState {
  /// Camera capture or gallery import — same pipeline and review step for
  /// both. Detection failures fall back to manual entry, never an error.
  // Drives the native image picker, so it can't run under flutter_test.
  // coverage:ignore-start
  Future<void> startCardImport(ImageSource source) async {
    Uint8List? bytes;
    try {
      final file = await _walletPicker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 88,
      );
      bytes = file == null ? null : await file.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) return;
    importCardFromBytes(bytes, source: source);
  }
  // coverage:ignore-end

  /// Pure part of the import: analyze the photo and open the review sheet.
  void importCardFromBytes(
    Uint8List bytes, {
    ImageSource source = ImageSource.gallery,
  }) {
    final scan = analyzeCardImage(bytes);
    _showSheet(
      (ctx) => _CardReviewSheet(
        state: this,
        photoBytes: bytes,
        scan: scan,
        source: source,
      ),
    );
  }

  /// From a card opened without context: pick one of this month's unpaid
  /// items and pay it with the card — exactly the pay-from-item flow.
  void openPayWithCardSheet(String cardId) {
    final open = unpaidItemsThisMonth();
    if (open.isEmpty) {
      flash('Nothing open this month');
      return;
    }
    _showSheet(
      monthScoped: true,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHead(ctx, 'Pay something with it', 'Open items this month'),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (cat, it) in open)
                    GestureDetector(
                      key: ValueKey('paywith-${it.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        payItemWithCard(cat.key, it.id, cardId);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: B.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _itemTitle(it),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: B.ink,
                                    ),
                                  ),
                                  Text(
                                    cat.title,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: B.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              eur(it.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: B.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Review-and-correct sheet (issue #227): shows what the importer detected
/// (photo thumbnail + confidence badges) and lets the user fix anything
/// before saving. The shop name is always asked for, never guessed.
class _CardReviewSheet extends StatefulWidget {
  const _CardReviewSheet({
    required this.state,
    required this.photoBytes,
    required this.scan,
    required this.source,
  });
  final _ThriveHomeState state;
  final Uint8List photoBytes;
  final CardScanResult scan;
  final ImageSource source;

  @override
  State<_CardReviewSheet> createState() => _CardReviewSheetState();
}

class _CardReviewSheetState extends State<_CardReviewSheet> {
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _number = TextEditingController(
    text: digitsOnly(widget.scan.number ?? ''),
  );
  late final TextEditingController _note = TextEditingController();
  late String _codeType = widget.scan.codeType;
  late Color _color =
      widget.scan.color ??
      kCardPalette[widget.state.cards.length % kCardPalette.length];
  String? _ownerId;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final s = widget.state;
    s.saveCard(
      DiscountCard(
        id: uid(),
        name: _name.text.trim(),
        number: digitsOnly(_number.text),
        codeType: _codeType,
        color: _color,
        photo: base64Encode(widget.photoBytes),
        note: _note.text.trim(),
        ownerId: _ownerId,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    Navigator.of(context).pop();
  }

  Widget _badge(String label, bool good, {Key? key}) {
    final bg = good ? B.greenSoft : B.amberSoft;
    final line = good ? B.greenLine : B.amberLine;
    final fg = good ? B.greenText : B.amberText;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ic(good ? 'check' : 'clock', size: 11, sw: 2.6, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatches() {
    final sampled = widget.scan.color;
    final choices = <Color>[
      ?sampled,
      for (final c in kCardPalette)
        if (sampled == null || c.toARGB32() != sampled.toARGB32()) c,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in choices)
          GestureDetector(
            key: ValueKey('card-color-${c.toARGB32()}'),
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _color.toARGB32() == c.toARGB32()
                      ? B.ink
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: sampled != null && identical(c, sampled)
                  ? Center(
                      child: ic(
                        'camera',
                        size: 14,
                        sw: 2.2,
                        color: contrastOn(c),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _typeToggle() {
    Widget seg(String value, String label) {
      final on = _codeType == value;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('card-type-$value'),
          onTap: () => setState(() => _codeType = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? B.primary : Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: on ? B.primary : B.line),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : B.text,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg('barcode', 'Barcode'),
        const SizedBox(width: 8),
        seg('qr', 'QR code'),
      ],
    );
  }

  Widget _ownerChips() {
    final members = widget.state.curFamily()?.members ?? const <FamilyMember>[];
    Widget chip(String? id, String label) {
      final on = _ownerId == id;
      return GestureDetector(
        key: ValueKey('card-owner-${id ?? 'family'}'),
        onTap: () => setState(() => _ownerId = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: on ? B.soft : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? B.primary : B.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: on ? B.deep : B.text,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        chip(null, 'Family'),
        for (final m in members) chip(m.id, m.name),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final valid = _name.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeadWithTick(
          context,
          'Check the card',
          sub: 'Fix anything the importer got wrong',
          onConfirm: _save,
          confirmEnabled: valid,
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 84,
                      height: 56,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: B.faint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.memory(
                        widget.photoBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _badge(
                            scan.numberDetected
                                ? (scan.codeType == 'qr'
                                      ? 'QR code read'
                                      : 'Barcode read')
                                : 'Type the number',
                            scan.numberDetected,
                            key: const ValueKey('badge-number'),
                          ),
                          _badge(
                            scan.colorSampled
                                ? 'Colour matched'
                                : 'Pick a colour',
                            scan.colorSampled,
                            key: const ValueKey('badge-color'),
                          ),
                          _badge(
                            'Add the shop name',
                            false,
                            key: const ValueKey('badge-name'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _sheetField(
                  'Shop name',
                  _sheetInput(
                    _name,
                    hint: 'e.g. Albert Heijn',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                _sheetField(
                  'Card number',
                  _sheetInput(_number, hint: 'Digits only', number: true),
                ),
                _sheetField('Code type', _typeToggle()),
                _sheetField('Colour', _swatches()),
                _sheetField('Whose card is it?', _ownerChips()),
                _sheetField(
                  'Note (optional)',
                  _sheetInput(_note, hint: 'e.g. bonus card'),
                ),
                Center(
                  child: TextButton(
                    key: const ValueKey('card-retake'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(widget.state.startCardImport(widget.source));
                    },
                    child: Text(
                      widget.source == ImageSource.camera
                          ? 'Retake the photo'
                          : 'Pick another photo',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: B.primary,
                      ),
                    ),
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
