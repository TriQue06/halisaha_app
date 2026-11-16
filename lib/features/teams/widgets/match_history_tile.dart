import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

/// Maç geçmişi satırı: sonuç rozeti (G/B/M), rakip, skor ve tarih.
class MatchHistoryTile extends StatelessWidget {
  const MatchHistoryTile({super.key, required this.entry, this.onTap});

  final MatchHistoryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final (Color color, String label) = switch (entry.outcome) {
      TeamOutcome.win => (AppColors.win, 'Galibiyet'),
      TeamOutcome.draw => (AppColors.draw, 'Beraberlik'),
      TeamOutcome.loss => (AppColors.loss, 'Mağlubiyet'),
    };
    final String? score = entry.scoreLabel;

    // Onay bekleyen / itiraz edilen sonuç için küçük etiket.
    final (Color, String)? badge = switch (entry.resultStatus) {
      ResultStatus.confirmed => null,
      ResultStatus.disputed => (AppColors.loss, 'İtirazlı · sayılmadı'),
      ResultStatus.pending => entry.awaitingMyConfirmation
          ? (AppColors.info, 'Onayın bekleniyor')
          : (AppColors.draw, 'Onay bekliyor'),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  entry.outcome.shortLabel,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'vs ${entry.opponentName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        entry.pitchName,
                        if (entry.teamSize != null) '${entry.teamSize}v${entry.teamSize}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (badge != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badge.$1.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge.$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: badge.$1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    score ?? label,
                    style: TextStyle(
                      fontSize: score == null ? 11.5 : 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM yyyy', 'tr_TR').format(entry.playedAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
