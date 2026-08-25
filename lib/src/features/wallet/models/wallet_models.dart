part of 'package:family_money_management_app/main.dart';

/// Fallback swatches offered when no dominant colour could be sampled from
/// the card photo (issue #225 — "palette fallback otherwise").
const List<Color> kCardPalette = [
  Color(0xff0E9A8D),
  Color(0xff1684B4),
  Color(0xff7c3aed),
  Color(0xffd97706),
  Color(0xffe11d48),
  Color(0xff54A96A),
  Color(0xff334155),
  Color(0xff0f766e),
];

/// A family loyalty/discount card (epic #222). Lives on the family
/// [Workspace] (`cards[]`) and syncs with it — except [photo], which stays
/// on-device (issue #234: card images never leave local storage).
class DiscountCard {
  DiscountCard({
    required this.id,
    required this.name,
    required this.number,
    this.codeType = 'barcode',
    required this.color,
    this.photo,
    this.note = '',
    this.ownerId,
    this.timesUsed = 0,
    this.lastUsedMillis,
    this.createdAtMillis,
  });

  String id;

  /// Shop name — always user-entered, never guessed (issue #225).
  String name;

  /// Card number, stored digits-only (issue #227).
  String number;

  /// `'barcode'` (1D, rendered as Code 128/EAN-13) or `'qr'`.
  String codeType;

  /// Card face colour — sampled from the photo when it has a dominant hue,
  /// otherwise picked from [kCardPalette].
  Color color;

  /// Base64 photo of the physical card. Local-only: excluded from the
  /// cloud-synced payload (see [toJson]'s `includePhoto`).
  String? photo;

  String note;

  /// Family-member id of whose card this is (optional).
  String? ownerId;

  int timesUsed;
  int? lastUsedMillis;
  int? createdAtMillis;

  /// `•••• 1234` mask for wallet rows (issue #228).
  String get maskedNumber {
    final d = number;
    if (d.isEmpty) return '';
    final tail = d.length <= 4 ? d : d.substring(d.length - 4);
    return '•••• $tail';
  }

  void logUse(int nowMillis) {
    timesUsed += 1;
    lastUsedMillis = nowMillis;
  }

  Map<String, dynamic> toJson({bool includePhoto = true}) => {
    'id': id,
    'name': name,
    'number': number,
    'codeType': codeType,
    'color': color.toARGB32(),
    if (includePhoto && photo != null) 'photo': photo,
    if (note.isNotEmpty) 'note': note,
    if (ownerId != null && ownerId!.isNotEmpty) 'ownerId': ownerId,
    if (timesUsed != 0) 'timesUsed': timesUsed,
    if (lastUsedMillis != null) 'lastUsed': lastUsedMillis,
    if (createdAtMillis != null) 'createdAt': createdAtMillis,
  };

  factory DiscountCard.fromJson(Map<String, dynamic> j) => DiscountCard(
    id: (j['id'] ?? _genUid()).toString(),
    name: (j['name'] ?? '').toString(),
    number: digitsOnly((j['number'] ?? '').toString()),
    codeType: j['codeType'] == 'qr' ? 'qr' : 'barcode',
    color: Color(
      (j['color'] as num?)?.toInt() ?? kCardPalette.first.toARGB32(),
    ),
    photo: j['photo']?.toString(),
    note: (j['note'] ?? '').toString(),
    ownerId: j['ownerId']?.toString(),
    timesUsed: ((j['timesUsed'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
    lastUsedMillis: (j['lastUsed'] as num?)?.toInt(),
    createdAtMillis: (j['createdAt'] as num?)?.toInt(),
  );
}

/// Keeps only the digits of [s] — card numbers are stored digits-only.
String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// Merges the local-only card photos of [local] into [incoming] by card id.
/// The cloud payload never carries photos (issue #234), so every snapshot
/// apply would otherwise wipe the photos this device already has.
List<DiscountCard> mergeCardPhotos(
  List<DiscountCard> incoming,
  List<DiscountCard> local,
) {
  final photos = <String, String>{
    for (final c in local)
      if (c.photo != null) c.id: c.photo!,
  };
  for (final c in incoming) {
    c.photo ??= photos[c.id];
  }
  return incoming;
}
