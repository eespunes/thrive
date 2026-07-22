part of 'package:family_money_management_app/main.dart';

/// Feather-style icon set ported verbatim from the Thrive design (`IC` map).
/// Each entry is a list of primitives: ['path', d] | ['circle', cx,cy,r]
/// | ['rect', x,y,w,h,rx].
const Map<String, List<List<Object>>> _kIcons = {
  'wallet': [
    ['path', 'M21 12V7H5a2 2 0 0 1 0-4h14v4'],
    ['path', 'M3 5v14a2 2 0 0 0 2 2h16v-5'],
    ['path', 'M18 12a2 2 0 0 0 0 4h4v-4Z'],
  ],
  'grid': [
    ['rect', 3, 3, 7, 7, 1.6],
    ['rect', 14, 3, 7, 7, 1.6],
    ['rect', 14, 14, 7, 7, 1.6],
    ['rect', 3, 14, 7, 7, 1.6],
  ],
  'chart': [
    ['path', 'M3 3v18h18'],
    ['path', 'm19 9-5 5-4-4-3 3'],
  ],
  'gear': [
    ['circle', 12, 12, 3],
    [
      'path',
      'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z',
    ],
  ],
  'home': [
    ['path', 'm3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'],
    ['path', 'M9 22V12h6v10'],
  ],
  'repeat': [
    ['path', 'm17 2 4 4-4 4'],
    ['path', 'M3 11v-1a4 4 0 0 1 4-4h14'],
    ['path', 'm7 22-4-4 4-4'],
    ['path', 'M21 13v1a4 4 0 0 1-4 4H3'],
  ],
  'card': [
    ['rect', 2, 5, 20, 14, 2],
    ['path', 'M2 10h20'],
  ],
  'trend': [
    ['path', 'M16 7h6v6'],
    ['path', 'm22 7-8.5 8.5-5-5L2 17'],
  ],
  'users': [
    ['path', 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2'],
    ['circle', 9, 7, 4],
    ['path', 'M22 21v-2a4 4 0 0 0-3-3.87'],
    ['path', 'M16 3.13a4 4 0 0 1 0 7.75'],
  ],
  'cart': [
    ['circle', 8, 21, 1.6],
    ['circle', 19, 21, 1.6],
    ['path', 'M2 3h2l2.4 12.4a2 2 0 0 0 2 1.6h9a2 2 0 0 0 2-1.6L21 7H5'],
  ],
  'heart': [
    [
      'path',
      'M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z',
    ],
  ],
  'receipt': [
    ['path', 'M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1Z'],
    ['path', 'M8 7h8'],
    ['path', 'M8 11h6'],
  ],
  'folder': [
    [
      'path',
      'M4 5a2 2 0 0 1 2-2h3l2 3h7a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2z',
    ],
  ],
  'check': [
    ['path', 'm20 6-11 11-5-5'],
  ],
  'plus': [
    ['path', 'M5 12h14'],
    ['path', 'M12 5v14'],
  ],
  'x': [
    ['path', 'M18 6 6 18'],
    ['path', 'm6 6 12 12'],
  ],
  'cleft': [
    ['path', 'm15 18-6-6 6-6'],
  ],
  'cright': [
    ['path', 'm9 18 6-6-6-6'],
  ],
  'cdown': [
    ['path', 'm6 9 6 6 6-6'],
  ],
  'back': [
    ['path', 'm12 19-7-7 7-7'],
    ['path', 'M19 12H5'],
  ],
  'clock': [
    ['circle', 12, 12, 10],
    ['path', 'M12 7v5l3 2'],
  ],
  'trash': [
    ['path', 'M3 6h18'],
    ['path', 'M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6'],
    ['path', 'M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'],
    ['path', 'M10 11v6'],
    ['path', 'M14 11v6'],
  ],
  'edit': [
    ['path', 'M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7'],
    ['path', 'M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z'],
  ],
  'del': [
    ['path', 'M21 4H8l-7 8 7 8h13a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2Z'],
    ['path', 'm18 9-6 6'],
    ['path', 'm12 9 6 6'],
  ],
  'signal': [
    ['path', 'M2 20h.01'],
    ['path', 'M7 20v-4'],
    ['path', 'M12 20v-8'],
    ['path', 'M17 20V8'],
  ],
  'wifi': [
    ['path', 'M5 13a10 10 0 0 1 14 0'],
    ['path', 'M8.5 16.5a5 5 0 0 1 7 0'],
    ['path', 'M2 8.82a15 15 0 0 1 20 0'],
    ['path', 'M12 20h.01'],
  ],
  'battery': [
    ['rect', 2, 7, 18, 10, 2],
    ['path', 'M22 11v2'],
  ],
  'shield': [
    ['path', 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z'],
    ['path', 'm9 12 2 2 4-4'],
  ],
  'copy': [
    ['rect', 9, 9, 13, 13, 2],
    ['path', 'M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1'],
  ],
  'gauge': [
    ['path', 'M12 14 8 10'],
    ['path', 'M12 22a10 10 0 1 1 10-10'],
    ['circle', 12, 14, 1.4],
  ],
  'cal': [
    ['rect', 3, 4, 18, 18, 2],
    ['path', 'M16 2v4'],
    ['path', 'M8 2v4'],
    ['path', 'M3 10h18'],
  ],
  'sliders': [
    ['path', 'M4 21v-7'],
    ['path', 'M4 10V3'],
    ['path', 'M12 21v-9'],
    ['path', 'M12 8V3'],
    ['path', 'M20 21v-5'],
    ['path', 'M20 12V3'],
    ['path', 'M1 14h6'],
    ['path', 'M9 8h6'],
    ['path', 'M17 16h6'],
  ],
  'tag': [
    [
      'path',
      'M12.59 2.59A2 2 0 0 0 11.17 2H4a2 2 0 0 0-2 2v7.17a2 2 0 0 0 .59 1.42l8.83 8.83a2 2 0 0 0 2.83 0l7.17-7.17a2 2 0 0 0 0-2.83Z',
    ],
    ['path', 'M7 7h.01'],
  ],
  'wallet3': [
    [
      'path',
      'M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5',
    ],
    ['path', 'M18 12h.01'],
  ],
  'lock': [
    ['rect', 3, 11, 18, 11, 2],
    ['path', 'M7 11V7a5 5 0 0 1 10 0v4'],
  ],
  'unlock': [
    ['rect', 3, 11, 18, 11, 2],
    ['path', 'M7 11V7a5 5 0 0 1 9.9-1'],
  ],
  'cup': [
    ['path', 'm18 15-6-6-6 6'],
  ],
  'down': [
    ['path', 'M12 5v14'],
    ['path', 'm19 12-7 7-7-7'],
  ],
  'pin': [
    ['path', 'M12 17v5'],
    ['path', 'M5 3h14l-1.5 9h-11L5 3Z'],
    ['path', 'M9 12v5'],
    ['path', 'M15 12v5'],
  ],
  'list': [
    ['path', 'M8 6h13'],
    ['path', 'M8 12h13'],
    ['path', 'M8 18h13'],
    ['path', 'M3 6h.01'],
    ['path', 'M3 12h.01'],
    ['path', 'M3 18h.01'],
  ],
  'menu': [
    ['path', 'M4 6h16'],
    ['path', 'M4 12h16'],
    ['path', 'M4 18h16'],
  ],
  'moon': [
    ['path', 'M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z'],
  ],
  'tasklist': [
    [
      'path',
      'M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2',
    ],
    ['rect', 9, 3, 6, 4, 1],
    ['path', 'm9 14 2 2 4-4'],
  ],
  'download': [
    ['path', 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'],
    ['path', 'M7 10l5 5 5-5'],
    ['path', 'M12 15V3'],
  ],
  'mappin': [
    ['path', 'M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z'],
    ['circle', 12, 10, 3],
  ],
  'bell': [
    ['path', 'M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9'],
    ['path', 'M13.73 21a2 2 0 0 1-3.46 0'],
  ],
  'note': [
    ['path', 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z'],
    ['path', 'M14 2v6h6'],
    ['path', 'M9 13h6'],
    ['path', 'M9 17h6'],
  ],
  'eye': [
    ['path', 'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z'],
    ['circle', 12, 12, 3],
  ],
  'eyeoff': [
    [
      'path',
      'M9.9 4.24A10.4 10.4 0 0 1 12 4c6.5 0 10 7 10 7a17 17 0 0 1-2.9 3.95',
    ],
    ['path', 'M6.6 6.6C3.4 8.6 2 11 2 11s3.5 7 10 7a10 10 0 0 0 3.6-.66'],
    ['path', 'M9.5 9.5a3 3 0 0 0 4.24 4.24'],
    ['path', 'M2 2l20 20'],
  ],
  'briefcase': [
    ['rect', 2, 7, 20, 14, 2],
    ['path', 'M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16'],
  ],
  'book': [
    ['path', 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20'],
    ['path', 'M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2Z'],
  ],
  'whistle': [
    ['circle', 8, 16, 5],
    ['path', 'M10.5 12.5 16 7h5v4l-5.5 5.5'],
    ['path', 'M16 7V4h4'],
  ],
  'flag': [
    ['path', 'M4 22V4'],
    ['path', 'M4 4h14l-2.5 4L18 12H4'],
  ],
  'sun': [
    ['circle', 12, 12, 4],
    ['path', 'M12 2v2'],
    ['path', 'M12 20v2'],
    ['path', 'm4.93 4.93 1.41 1.41'],
    ['path', 'm17.66 17.66 1.41 1.41'],
    ['path', 'M2 12h2'],
    ['path', 'M20 12h2'],
    ['path', 'm6.34 17.66-1.41 1.41'],
    ['path', 'm19.07 4.93-1.41 1.41'],
  ],
  'star': [
    [
      'path',
      'm12 2 3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01Z',
    ],
  ],
};

String _fmt(Object n) {
  if (n is int) return n.toString();
  if (n is double) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }
  return n.toString();
}

/// Builds an icon widget identical to the design's `ic(name,size,sw,color)`.
Widget ic(String name, {double size = 18, double sw = 2, Color? color}) {
  final spec = _kIcons[name] ?? const [];
  final stroke = (color ?? B.ink);
  final hex =
      '#${stroke.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  final buffer = StringBuffer()
    ..write(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
      'viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="$sw" '
      'stroke-linecap="round" stroke-linejoin="round">',
    );
  for (final s in spec) {
    final type = s[0] as String;
    if (type == 'circle') {
      buffer.write(
        '<circle cx="${_fmt(s[1])}" cy="${_fmt(s[2])}" r="${_fmt(s[3])}"/>',
      );
    } else if (type == 'rect') {
      final rx = s.length > 5 ? _fmt(s[5]) : '0';
      buffer.write(
        '<rect x="${_fmt(s[1])}" y="${_fmt(s[2])}" width="${_fmt(s[3])}" '
        'height="${_fmt(s[4])}" rx="$rx"/>',
      );
    } else {
      buffer.write('<path d="${s[1]}"/>');
    }
  }
  buffer.write('</svg>');
  return SvgPicture.string(buffer.toString(), width: size, height: size);
}

/// The Thrive logo mark (the small leaf-burst inside the gradient tile).
Widget logoMark({double size = 18, Color color = Colors.white}) {
  final hex =
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  const paths = [
    'M12 2v6',
    'M12 22v-4',
    'M4.5 9.5 8 12',
    'M19.5 9.5 16 12',
    'M6 18l3-3',
    'M18 18l-3-3',
  ];
  final buffer = StringBuffer()
    ..write(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
      'viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" '
      'stroke-linecap="round" stroke-linejoin="round">',
    );
  for (final d in paths) {
    buffer.write('<path d="$d"/>');
  }
  buffer.write('<circle cx="12" cy="13" r="3"/></svg>');
  return SvgPicture.string(buffer.toString(), width: size, height: size);
}
