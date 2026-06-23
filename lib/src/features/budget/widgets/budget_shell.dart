part of 'package:family_money_management_app/main.dart';

class MobileMonthHeader extends StatelessWidget {
  const MobileMonthHeader({
    super.key,
    required this.monthLabel,
    required this.year,
    required this.onPrev,
    required this.onNext,
    required this.onPrevYear,
    required this.onNextYear,
  });

  final String monthLabel;
  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPrevYear;
  final VoidCallback onNextYear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.page,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: MonthSwitcher(
                  label: monthLabel,
                  onPrev: onPrev,
                  onNext: onNext,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: YearSwitcher(
                  year: year,
                  onPrev: onPrevYear,
                  onNext: onNextYear,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppToolbar extends StatelessWidget {
  const AppToolbar({
    super.key,
    required this.monthLabel,
    required this.year,
    required this.phoneMode,
    required this.previewToggleEnabled,
    required this.onPrev,
    required this.onNext,
    required this.onPrevYear,
    required this.onNextYear,
    required this.onDashboard,
    required this.onPhone,
    required this.onLogExpense,
    required this.onCreateAccount,
    required this.onCreateBudgetBlock,
    required this.onOpenStatistics,
    required this.onOpenSettings,
  });

  final String monthLabel;
  final int year;
  final bool phoneMode;
  final bool previewToggleEnabled;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPrevYear;
  final VoidCallback onNextYear;
  final VoidCallback onDashboard;
  final VoidCallback onPhone;
  final VoidCallback onLogExpense;
  final VoidCallback onCreateAccount;
  final VoidCallback onCreateBudgetBlock;
  final VoidCallback onOpenStatistics;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .9),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final brand = Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Image.asset(
                      'assets/logos/thrive-colored.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Thrive',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Eva & Erik - Family',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: brand),
                        IconButton.filled(
                          onPressed: onLogExpense,
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'Log expense',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: MonthSwitcher(
                        label: monthLabel,
                        onPrev: onPrev,
                        onNext: onNext,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Flexible(fit: FlexFit.loose, child: brand),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    child: MonthSwitcher(
                      label: monthLabel,
                      onPrev: onPrev,
                      onNext: onNext,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 132,
                    child: YearSwitcher(
                      year: year,
                      onPrev: onPrevYear,
                      onNext: onNextYear,
                    ),
                  ),
                  const Spacer(),
                  if (previewToggleEnabled) ...[
                    PreviewToggle(
                      phoneMode: phoneMode,
                      onDashboard: onDashboard,
                      onPhone: onPhone,
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: onCreateAccount,
                    icon: const Icon(Icons.account_balance_rounded, size: 17),
                    label: const Text('Account'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onCreateBudgetBlock,
                    icon: const Icon(Icons.add_chart_rounded, size: 17),
                    label: const Text('Block'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onOpenStatistics,
                    icon: const Icon(Icons.bar_chart_rounded, size: 17),
                    label: const Text('Stats'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_rounded, size: 17),
                    label: const Text('Settings'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onLogExpense,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Log expense'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: [
          SwitcherArrowButton(
            tooltip: 'Previous month',
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SwitcherArrowButton(
            tooltip: 'Next month',
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class YearSwitcher extends StatelessWidget {
  const YearSwitcher({
    super.key,
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: [
          SwitcherArrowButton(
            tooltip: 'Previous year',
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
          ),
          Expanded(
            child: Text(
              '$year',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SwitcherArrowButton(
            tooltip: 'Next year',
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class SwitcherArrowButton extends StatelessWidget {
  const SwitcherArrowButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 32,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

class PreviewToggle extends StatelessWidget {
  const PreviewToggle({
    super.key,
    required this.phoneMode,
    required this.onDashboard,
    required this.onPhone,
  });

  final bool phoneMode;
  final VoidCallback onDashboard;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Dashboard',
            icon: Icons.desktop_windows_rounded,
            active: !phoneMode,
            onTap: onDashboard,
          ),
          _ToggleButton(
            label: 'Phone',
            icon: Icons.phone_iphone_rounded,
            active: phoneMode,
            onTap: onPhone,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? AppColors.indigo : AppColors.softText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.indigo : AppColors.softText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
