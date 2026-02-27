import 'package:flutter/material.dart';

import '../game/game_state.dart';

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({
    super.key,
    required this.stats,
    required this.onOpenSettings,
  });

  final PlayerStats stats;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final double hpRatio = stats.mhp == 0 ? 0 : stats.hp / stats.mhp;
    final double hpProgress = hpRatio < 0
        ? 0
        : (hpRatio > 1 ? 1 : hpRatio);
    final Color hpColor = _hpColor(hpRatio);
    final ThemeData theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'HP ${stats.hp}/${stats.mhp}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: hpColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: hpProgress,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MP:${stats.mp}/${stats.mmp}   AC:${stats.ac}   EV:${stats.ev}   XL:${stats.xl}   Gold:${stats.gold}   [${stats.place}:${stats.depth}]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Color _hpColor(double ratio) {
    if (ratio < 0.25) {
      return Colors.red.shade400;
    }
    if (ratio <= 0.5) {
      return Colors.yellow.shade400;
    }
    return Colors.green.shade400;
  }
}
