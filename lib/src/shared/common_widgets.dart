part of 'package:family_money_management_app/main.dart';

class DashedAction extends StatelessWidget {
  const DashedAction({super.key, required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.muted, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              'New item',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.onTap,
  });

  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.greenLine : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const Icon(Icons.check_rounded, size: 12, color: AppColors.green),
              const SizedBox(width: 4),
            ],
            Text(
              active ? activeLabel : inactiveLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: active ? AppColors.green : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountMenuChip extends StatelessWidget {
  const AccountMenuChip({
    super.key,
    required this.accountKey,
    required this.onChanged,
    this.dense = false,
  });

  final String accountKey;
  final ValueChanged<String> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final account = accountForKey(accountKey);
    return PopupMenuButton<String>(
      tooltip: 'Choose account',
      initialValue: account.key,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in accountMeta)
          PopupMenuItem(
            value: option.key,
            child: Row(
              children: [
                AccountInitialsBadge(account: option, size: 28),
                const SizedBox(width: 10),
                Text(option.name, style: itemStyle),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 9,
          vertical: dense ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: account.color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: account.color.withValues(alpha: .28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account.initials,
              style: TextStyle(
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w900,
                color: account.color,
              ),
            ),
            if (!dense) ...[
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 14, color: account.color),
            ],
          ],
        ),
      ),
    );
  }
}

class AccountChoiceSegmented extends StatelessWidget {
  const AccountChoiceSegmented({
    super.key,
    required this.label,
    required this.selectedKey,
    required this.onChanged,
  });

  final String label;
  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final account in accountMeta)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: account == accountMeta.last ? 0 : 8,
                  ),
                  child: InkWell(
                    onTap: () => onChanged(account.key),
                    borderRadius: BorderRadius.circular(13),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selectedKey == account.key
                            ? account.color.withValues(alpha: .12)
                            : AppColors.panel,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: selectedKey == account.key
                              ? account.color
                              : AppColors.line,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AccountInitialsBadge(account: account, size: 24),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              account.shortName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: selectedKey == account.key
                                    ? account.color
                                    : AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class AccountInitialsBadge extends StatelessWidget {
  const AccountInitialsBadge({
    super.key,
    required this.account,
    required this.size,
  });

  final AccountMeta account;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: account.color,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      alignment: Alignment.center,
      child: Text(
        account.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class UntilChip extends StatelessWidget {
  const UntilChip({super.key, required this.label, required this.state});

  final String label;
  final UntilState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      UntilState.soon => AppColors.orangeText,
      UntilState.ended => AppColors.muted,
      UntilState.future => AppColors.indigo,
    };
    final bg = switch (state) {
      UntilState.soon => AppColors.orangeSoft,
      UntilState.ended => AppColors.track,
      UntilState.future => AppColors.indigoSoft,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ToneIcon extends StatelessWidget {
  const ToneIcon({
    super.key,
    required this.icon,
    required this.tone,
    this.background,
    this.size = 38,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color tone;
  final Color? background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? tone.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * .29),
      ),
      child: Icon(icon, color: tone, size: iconSize),
    );
  }
}

class SmallMetric extends StatelessWidget {
  const SmallMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: labelStyle),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: titleStyle.copyWith(fontSize: 17, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountRow extends StatelessWidget {
  const AccountRow({super.key, required this.account, this.onDelete});

  final AccountShare account;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: account.color,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              account.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: account.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.track,
                    valueColor: AlwaysStoppedAnimation(account.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatEuro(account.amount),
            style: moneyStyle.copyWith(fontSize: 13),
          ),
          IconButton(
            tooltip: onDelete == null
                ? 'Keep at least one account'
                : 'Delete account',
            onPressed: onDelete == null
                ? null
                : () async {
                    final confirmed = await confirmDelete(
                      context,
                      title: 'Delete account?',
                      message:
                          'Delete ${account.name}? Linked items will move to another account.',
                    );
                    if (confirmed) onDelete?.call();
                  },
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.muted,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
