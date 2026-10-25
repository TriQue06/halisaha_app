import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';
import '../../shell/main_shell.dart';

/// Ana sayfanın en üstündeki "Yapılacaklar": kullanıcının yanıt vermesi
/// gereken maç adımları. Yapılacak bir şey yoksa hiç görünmez.
class TodoSection extends ConsumerWidget {
  const TodoSection({super.key});

  /// Maçın, kullanıcıdan beklediği adım (yoksa null).
  static (IconData, String, Color)? actionFor(PendingMatch m) {
    final String rival = m.opponentTeamName;
    switch (m.stage) {
      case PendingMatchStage.invitationReceived:
        return (Icons.mark_email_unread_rounded, '$rival maç teklifi gönderdi', AppColors.info);
      case PendingMatchStage.readinessPending:
        return m.myTeamReady
            ? null
            : (Icons.how_to_reg_rounded, '$rival maçı için "Maça Hazırım" de', AppColors.draw);
      case PendingMatchStage.confirmed:
        if (m.matchDate == null) {
          return m.isChallenger
              ? (Icons.event_available_rounded, '$rival maçının gün ve saatini belirle', AppColors.win)
              : null;
        }
        if (m.canPickLineup && !m.isLineupComplete) {
          return (Icons.groups_rounded, '$rival maçı için kadronu seç', AppColors.win);
        }
        return null;
      case PendingMatchStage.awaitingResult:
        return m.canReportScore
            ? (Icons.scoreboard_rounded, '$rival maçının skorunu gir', AppColors.loss)
            : null;
      case PendingMatchStage.invitationSent:
      case PendingMatchStage.expired:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PendingMatch> matches =
        ref.watch(pendingMatchesProvider).valueOrNull ?? const <PendingMatch>[];
    final List<(IconData, String, Color)> todos = <(IconData, String, Color)>[
      for (final PendingMatch m in matches)
        if (actionFor(m) case final (IconData, String, Color) a) a,
    ];
    if (todos.isEmpty) return const SizedBox.shrink();

    void openMatches() => ref.read(selectedTabProvider.notifier).state = MainTab.matches.index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Yapılacaklar',
          subtitle: '${todos.length} maç senden yanıt bekliyor',
          icon: Icons.notification_important_rounded,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < todos.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: todos[i].$3.withValues(alpha: 0.14),
                      child: Icon(todos[i].$1, size: 18, color: todos[i].$3),
                    ),
                    title: Text(todos[i].$2, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: openMatches,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
