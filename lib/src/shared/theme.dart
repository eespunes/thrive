part of 'package:family_money_management_app/main.dart';

BoxDecoration cardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .035),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: .055),
        blurRadius: 28,
        offset: const Offset(0, 14),
        spreadRadius: -20,
      ),
    ],
  );
}

const labelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w900,
  color: AppColors.muted,
  letterSpacing: .4,
);

const headerStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w900,
  color: AppColors.muted,
  letterSpacing: .5,
);

const titleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w900,
  color: AppColors.ink,
);

const itemStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w800,
  color: AppColors.text,
);

const moneyStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w900,
  color: AppColors.ink,
);

class AppColors {
  static const page = Color(0xffeef0f4);
  static const panel = Color(0xfff8f9fc);
  static const ink = Color(0xff0f172a);
  static const text = Color(0xff334155);
  static const softText = Color(0xff64748b);
  static const muted = Color(0xff9aa4b2);
  static const line = Color(0xffe6e9f0);
  static const faintLine = Color(0xfff3f4f8);
  static const track = Color(0xfff1f3f7);
  static const deepIndigo = Color(0xff4f46e5);
  static const indigo = Color(0xff6366f1);
  static const indigoSoft = Color(0xffeef2ff);
  static const green = Color(0xff059669);
  static const greenSoft = Color(0xffecfdf5);
  static const greenLine = Color(0xffbbf7d0);
  static const red = Color(0xffdc2626);
  static const teal = Color(0xff14b8a6);
  static const amber = Color(0xfff59e0b);
  static const amberSoft = Color(0xfffffbeb);
  static const amberLine = Color(0xfffde68a);
  static const amberText = Color(0xffb45309);
  static const orangeSoft = Color(0xfffff7ed);
  static const orangeText = Color(0xffc2410c);
}
