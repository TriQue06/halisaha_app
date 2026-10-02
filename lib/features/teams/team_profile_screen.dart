import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/match_errors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../../state/team_providers.dart';
import 'match_detail_screen.dart';
import 'team_form_screen.dart';
import 'widgets/match_history_tile.dart';

/// Herhangi bir takımın profili: G/B/M, kadro (oyuncu başına maç/gol/asist)
/// ve skorlu maç geçmişi. Kendi takımında kadro düzenleme butonu çıkar.
class TeamProfileScreen extends ConsumerWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Team?> teamAsync = ref.watch(teamByIdProvider(teamId));
    final AsyncValue<List<TeamPlayer>> rosterAsync = ref.watch(teamRosterProvider(teamId));
    final AsyncValue<List<MatchHistoryEntry>> historyAsync =
        ref.watch(teamHistoryProvider(teamId));
    final String? me = ref.watch(currentUserIdProvider);

    final Team? team = teamAsync.valueOrNull;

    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Takım')),
        body: Center(
          child: teamAsync.isLoading
              ? const CircularProgressIndicator()
              : EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Takım bulunamadı',
                  message: teamAsync.hasError ? turkishMatchError(teamAsync.error!) : null,
                ),
        ),
      );
    }

    final bool isMine = team.captainId == me;
    final List<TeamPlayer> roster = rosterAsync.valueOrNull ?? const <TeamPlayer>[];
    final List<MatchHistoryEntry> history =
        historyAsync.valueOrNull ?? const <MatchHistoryEntry>[];

    Future<void> refresh() async {
      ref.invalidate(teamByIdProvider(teamId));
      ref.invalidate(teamRosterProvider(teamId));
      ref.invalidate(teamHistoryProvider(teamId));
      await ref.read(teamHistoryProvider(teamId).future);
    }

    return Scaffold(
      appBar: AppBar(title: Text(team.name)),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _TeamHeader(team: team, isMine: isMine),
            ),
            SectionHeader(
              title: 'Kadro',
              subtitle: '${roster.length} oyuncu',
              icon: Icons.groups_rounded,
              action: isMine
                  ? TextButton(
                      onPressed: rosterAsync.hasValue
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<bool>(
                                  builder: (_) =>
                                      TeamFormScreen.editRoster(team: team, players: roster),
                                ),
                              )
                          : null,
                      child: const Text('Düzenle'),
                    )
                  : null,
            ),
            if (rosterAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (roster.isEmpty)
              EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Kadro girilmemiş',
                message: isMine
                    ? 'Maç teklifi göndermek ve kabul etmek için en az $kMinRosterSize oyuncu ekle.'
                    : null,
                compact: true,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RosterTable(players: roster),
              ),
            SectionHeader(
              title: 'Maç Geçmişi',
              subtitle: '${history.length} tamamlanmış maç',
              icon: Icons.history_rounded,
            ),
            if (history.isEmpty)
              const EmptyState(
                icon: Icons.sports_soccer_outlined,
                title: 'Henüz tamamlanmış maç yok',
                compact: true,
              )
            else
              for (final MatchHistoryEntry entry in history)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: MatchHistoryTile(
                    entry: entry,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MatchDetailScreen(matchId: entry.id),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team, required this.isMine});

  final Team team;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.shield_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${team.played} maç · ${team.points} puan${isMine ? ' · Kaptan' : ''}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      StatBadge.win(value: team.wins),
                      const SizedBox(width: 5),
                      StatBadge.draw(value: team.draws),
                      const SizedBox(width: 5),
                      StatBadge.loss(value: team.losses),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oyuncu | Maç | Gol | Asist tablosu (gol sayısına göre sıralı).
class _RosterTable extends StatelessWidget {
  const _RosterTable({required this.players});

  final List<TeamPlayer> players;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TeamPlayer> sorted = <TeamPlayer>[...players]..sort((TeamPlayer a, TeamPlayer b) {
        final int byGoals = b.goals.compareTo(a.goals);
        return byGoals != 0 ? byGoals : b.assists.compareTo(a.assists);
      });
    final TextStyle? head = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget cell(String text, {TextStyle? style}) => SizedBox(
          width: 44,
          child: Text(text, textAlign: TextAlign.center, style: style),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('OYUNCU', style: head)),
                cell('MAÇ', style: head),
                cell('GOL', style: head),
                cell('ASİST', style: head),
              ],
            ),
            const Divider(),
            for (final TeamPlayer p in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(p.fullName, overflow: TextOverflow.ellipsis)),
                    cell('${p.appearances}'),
                    cell('${p.goals}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    cell('${p.assists}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
