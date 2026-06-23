part of 'package:family_money_management_app/main.dart';

enum UntilState { soon, future, ended }

const monthKeys = [
  'Januari',
  'Februari',
  'Maart',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Augustus',
  'September',
  'Oktober',
  'November',
  'December',
];

const monthLabels = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const savedStateKey = 'family_budget_state_v1';
const defaultAccountKey = 'shared';

const defaultAccountMeta = [
  AccountMeta(
    key: 'eva',
    name: "Eva's account",
    shortName: 'Eva',
    initials: 'EV',
    color: AppColors.indigo,
  ),
  AccountMeta(
    key: 'erik',
    name: "Erik's account",
    shortName: 'Erik',
    initials: 'ER',
    color: AppColors.teal,
  ),
  AccountMeta(
    key: 'shared',
    name: 'Shared account',
    shortName: 'Shared',
    initials: 'SH',
    color: AppColors.amber,
  ),
];

final accountMeta = <AccountMeta>[...defaultAccountMeta];

const accountPalette = [
  AppColors.indigo,
  AppColors.teal,
  AppColors.amber,
  Color(0xff2563eb),
  Color(0xff7c3aed),
  Color(0xffe11d48),
  Color(0xff059669),
  Color(0xffea580c),
];

const blockPalette = [
  Color(0xff2563eb),
  Color(0xff7c3aed),
  Color(0xffe11d48),
  Color(0xff059669),
  Color(0xffd97706),
  Color(0xffea580c),
  Color(0xff0d9488),
  Color(0xff475569),
];

const defaultCategoryMeta = [
  CategoryMeta(
    key: 'home',
    title: 'Home',
    icon: Icons.home_rounded,
    markerKey: 'day',
    tone: Color(0xff2563eb),
    background: Color(0xffeff6ff),
  ),
  CategoryMeta(
    key: 'subscriptions',
    title: 'Subscriptions',
    icon: Icons.repeat_rounded,
    markerKey: 'date',
    tone: Color(0xff7c3aed),
    background: Color(0xfff5f3ff),
  ),
  CategoryMeta(
    key: 'debt',
    title: 'Debt',
    icon: Icons.credit_card_rounded,
    markerKey: 'day',
    tone: Color(0xffe11d48),
    background: Color(0xfffff1f2),
    hasUntil: true,
  ),
  CategoryMeta(
    key: 'savings',
    title: 'Savings',
    icon: Icons.trending_up_rounded,
    markerKey: 'date',
    tone: Color(0xff059669),
    background: Color(0xffecfdf5),
  ),
  CategoryMeta(
    key: 'personal',
    title: 'Personal & Family',
    icon: Icons.groups_rounded,
    markerKey: 'date',
    tone: Color(0xffd97706),
    background: Color(0xfffffbeb),
  ),
  CategoryMeta(
    key: 'food',
    title: 'Food',
    icon: Icons.shopping_cart_rounded,
    markerKey: 'date',
    tone: Color(0xffea580c),
    background: Color(0xfffff7ed),
  ),
  CategoryMeta(
    key: 'health',
    title: 'Health',
    icon: Icons.favorite_rounded,
    markerKey: 'date',
    tone: Color(0xff0d9488),
    background: Color(0xfff0fdfa),
  ),
  CategoryMeta(
    key: 'additional',
    title: 'Additional Costs',
    icon: Icons.receipt_long_rounded,
    markerKey: 'date',
    tone: Color(0xff475569),
    background: Color(0xfff1f5f9),
  ),
];

final categoryMeta = <CategoryMeta>[...defaultCategoryMeta];
