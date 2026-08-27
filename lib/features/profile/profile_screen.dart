import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import 'goalkeeper_profile_editor.dart';
import 'widgets/pending_match_card.dart';

/// Profilim sekmesi: kullanıcı bilgileri + "Takımım" / "Kaleci Profilim" tabları.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile user = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: 168,
                flexibleSpace: FlexibleSpaceBar(
                  background: _ProfileHeader(user: user),
                  collapseMode: CollapseMode.pin,
                ),
                bottom: const TabBar(
                  tabs: <Widget>[
                    Tab(text: 'Takımım'),
                    Tab(text: 'Kaleci Profilim'),
                  ],
                ),
              ),
            ];
          },
          body: const TabBarView(
            children: <Widget>[
              _MyTeamTab(),
              GoalkeeperProfileEditor(embedded: true),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Üst bilgi: isim, doğum tarihi / yaş, telefon
// =====================================================================
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[AppColors.darkSurfaceAlt, AppColors.darkBackground]
              : <Color>[AppColors.primaryGreen, AppColors.deepGreen],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundImage: (user.avatarUrl?.isNotEmpty ?? false)
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: const Icon(Icons.person_rounded, size: 34, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _HeaderInfoRow(
                  icon: Icons.cake_outlined,
                  text: '${DateFormat('d MMMM yyyy', 'tr_TR').format(user.birthDate)}'
                      ' · ${user.age} yaşında',
                ),
                const SizedBox(height: 2),
                _HeaderInfoRow(icon: Icons.phone_outlined, text: user.phone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoRow extends StatelessWidget {
  const _HeaderInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// "Takımım" sekmesi: takım kartı + bekleyen maçlar + maç geçmişi
// =====================================================================
class _MyTeamTab extends ConsumerWidget {
  const _MyTeamTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Team> myTeams = ref.watch(myTeamsProvider);
    final List<PendingMatch> pending = ref.watch(pendingMatchesProvider);
    final List<MatchHistoryEntry> history = ref.watch(matchHistoryProvider);

    if (myTeams.isEmpty) {
      return const EmptyState(
        icon: Icons.shield_outlined,
        title: 'Henüz bir takımın yok',
        message: 'Sahalar sekmesinden bir halı saha seçip takımını oluşturabilirsin.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: <Widget>[
        // --- Takım özeti ---------------------------------------------
        for (final Team team in myTeams)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _TeamSummaryCard(team: team),
          ),

        // --- BEKLEYEN MAÇLAR (4 aşamalı onay akışı) -------------------
        SectionHeader(
          title: 'Bekleyen Maçlar',
          subtitle: pending.isEmpty
              ? 'Şu an bekleyen maçın yok'
              : '${pending.length} maç onay bekliyor',
          icon: Icons.pending_actions_rounded,
        ),
        if (pending.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Bekleyen maç yok',
            message: 'Saha detayından rakip takımlara meydan okuyabilirsin.',
            compact: true,
          )
        else
          for (final PendingMatch match in pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: PendingMatchCard(match: match),
            ),

        // --- MAÇ GEÇMİŞİ (en yeniden eskiye) -------------------------
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
              child: _MatchHistoryTile(entry: entry),
            ),
      ],
    );
  }
}

/// Takımın G/B/M özeti.
class _TeamSummaryCard extends StatelessWidget {
  const _TeamSummaryCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
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
                    '${team.played} maç · ${team.points} puan · Kaptan',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
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
    );
  }
}

/// Maç geçmişi satırı — sonuç rozeti (G/B/M) ile.
class _MatchHistoryTile extends StatelessWidget {
  const _MatchHistoryTile({required this.entry});

  final MatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final (Color color, String label) = switch (entry.outcome) {
      TeamOutcome.win => (AppColors.win, 'Galibiyet'),
      TeamOutcome.draw => (AppColors.draw, 'Beraberlik'),
      TeamOutcome.loss => (AppColors.loss, 'Mağlubiyet'),
    };

    return Card(
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
                    entry.pitchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
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
    );
  }
}
