import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/match_errors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/moderation_repository.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../../state/team_providers.dart';
import '../moderation/report_action_sheet.dart';
import 'lineup_picker_screen.dart';
import 'match_result_screen.dart';

/// Maç detayı: skor ve iki takımın hangi kadroyla çıktığı (gol/asistlerle).
class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<MatchDetail?> async = ref.watch(matchDetailProvider(matchId));
    final String? me = ref.watch(currentUserIdProvider);

    // Maçın tarafıysak rakip kaptanı (ör. yanlış girilen skor için)
    // raporlayabilir ya da engelleyebiliriz.
    final MatchDetail? loaded = async.valueOrNull;
    final MatchSide? mySide = loaded?.sideOf(me);
    final MatchSide? rival = mySide == null
        ? null
        : (loaded!.challenger.teamId == mySide.teamId ? loaded.opponent : loaded.challenger);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Detayı'),
        actions: <Widget>[
          if (rival != null)
            ModerationMenuButton(
              userId: rival.captainId,
              displayName: rival.teamName,
              reportContext: ReportContext.match,
              matchId: loaded!.id,
              iconSize: 24,
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Maç yüklenemedi',
            message: turkishMatchError(e),
          ),
        ),
        data: (MatchDetail? d) {
          if (d == null) {
            return const Center(
              child: EmptyState(icon: Icons.search_off_rounded, title: 'Maç bulunamadı'),
            );
          }
          final MatchSide? mine = d.sideOf(me);
          final bool canEditStats = mine != null && mine.lineup.isNotEmpty && d.areStatsEditable;
          // Maça kadro seçmeden çıkan takım, gol/asist girebilmek için
          // kadroyu sonradan (7 gün içinde) seçebilir.
          final bool canPickLineup =
              mine != null && mine.lineup.isEmpty && d.areStatsEditable && d.teamSize != null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              // --- Skor tabelası ------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: _TeamName(d.challenger.teamName)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              d.challenger.score == null
                                  ? 'vs'
                                  : '${d.challenger.score} - ${d.opponent.score}',
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Expanded(child: _TeamName(d.opponent.teamName)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        <String>[
                          d.pitchName,
                          if (d.matchDate != null)
                            DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(d.matchDate!),
                          if (d.teamSize != null) '${d.teamSize}v${d.teamSize}',
                        ].join(' · '),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              if (canEditStats) ...<Widget>[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MatchResultScreen(
                        matchId: d.id,
                        myTeamId: mine.teamId,
                        withScore: false,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Gol ve asistleri düzenle'),
                ),
              ],
              if (canPickLineup) ...<Widget>[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LineupPickerScreen(
                        matchId: d.id,
                        myTeamId: mine.teamId,
                        teamSize: d.teamSize!,
                        opponentName: (d.challenger.teamId == mine.teamId
                                ? d.opponent
                                : d.challenger)
                            .teamName,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Maç kadrosunu seç'),
                ),
              ],
              const SizedBox(height: 8),
              _LineupSection(side: d.challenger),
              _LineupSection(side: d.opponent),
            ],
          );
        },
      ),
    );
  }
}

class _TeamName extends StatelessWidget {
  const _TeamName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _LineupSection extends StatelessWidget {
  const _LineupSection({required this.side});

  final MatchSide side;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: side.teamName,
          subtitle: side.lineup.isEmpty ? 'Kadro girilmemiş' : '${side.lineup.length} oyuncu',
          icon: Icons.groups_rounded,
        ),
        for (final LineupPlayer p in side.lineup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 26,
                  child: Text(
                    '${p.slot}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                if (p.goals > 0) _StatChip(icon: Icons.sports_soccer_rounded, value: p.goals),
                if (p.assists > 0)
                  _StatChip(icon: Icons.assistant_direction_outlined, value: p.assists),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 3),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
