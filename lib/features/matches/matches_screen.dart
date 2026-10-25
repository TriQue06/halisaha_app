import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/match_errors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../profile/widgets/pending_match_card.dart';
import '../shell/main_shell.dart';
import '../teams/match_detail_screen.dart';
import '../teams/widgets/match_history_tile.dart';

/// "Maçlar" sekmesi: bekleyen maçlar (4 aşamalı akış) ve maç geçmişi.
///
/// Önceden Profilim'in içindeydi; uygulamanın asıl işi olduğu için alt
/// menüde kendi yeri var. Yükleniyor / hata / boş durumları ayrı:
/// bağlantı hatası "maçın yok" gibi gösterilmez.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Team>> teamsAsync = ref.watch(myTeamsProvider);
    final AsyncValue<List<PendingMatch>> pendingAsync = ref.watch(pendingMatchesProvider);
    final AsyncValue<List<MatchHistoryEntry>> historyAsync = ref.watch(matchHistoryProvider);

    Future<void> refresh() async {
      ref.invalidate(myTeamsProvider);
      ref.invalidate(pendingMatchesProvider);
      ref.invalidate(matchHistoryProvider);
      try {
        await ref.read(pendingMatchesProvider.future);
      } catch (_) {
        // Hata kartı ekranda gösteriliyor.
      }
    }

    Widget body;
    if (teamsAsync.isLoading && !teamsAsync.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (teamsAsync.hasError && !teamsAsync.hasValue) {
      body = _ErrorState(error: teamsAsync.error!, onRetry: refresh);
    } else if ((teamsAsync.valueOrNull ?? const <Team>[]).isEmpty) {
      body = Center(
        child: EmptyState(
          icon: Icons.shield_outlined,
          title: 'Henüz bir takımın yok',
          message: 'Maç yapmak için bir halı saha seçip takımını kur; sonra o '
              'sahadaki takımlara maç teklifi gönderebilirsin.',
          action: FilledButton.icon(
            onPressed: () =>
                ref.read(selectedTabProvider.notifier).state = MainTab.pitches.index,
            icon: const Icon(Icons.stadium_rounded),
            label: const Text('Sahalara göz at'),
          ),
        ),
      );
    } else {
      final List<PendingMatch> pending = pendingAsync.valueOrNull ?? const <PendingMatch>[];
      final List<MatchHistoryEntry> history =
          historyAsync.valueOrNull ?? const <MatchHistoryEntry>[];

      body = RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: <Widget>[
            // --- BEKLEYEN MAÇLAR -------------------------------------
            SectionHeader(
              title: 'Bekleyen Maçlar',
              subtitle: pendingAsync.hasError
                  ? 'Yüklenemedi'
                  : pending.isEmpty
                      ? 'Şu an bekleyen maçın yok'
                      : '${pending.length} maç',
              icon: Icons.pending_actions_rounded,
            ),
            if (pendingAsync.isLoading && !pendingAsync.hasValue)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (pendingAsync.hasError && !pendingAsync.hasValue)
              _ErrorState(error: pendingAsync.error!, onRetry: refresh, compact: true)
            else if (pending.isEmpty)
              const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Bekleyen maç yok',
                message: 'Saha detayından rakip takımlara maç teklifi gönderebilirsin.',
                compact: true,
              )
            else
              for (final PendingMatch match in pending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: PendingMatchCard(match: match),
                ),

            // --- MAÇ GEÇMİŞİ -----------------------------------------
            SectionHeader(
              title: 'Maç Geçmişi',
              subtitle: historyAsync.hasError
                  ? 'Yüklenemedi'
                  : '${history.length} tamamlanmış maç',
              icon: Icons.history_rounded,
            ),
            if (historyAsync.isLoading && !historyAsync.hasValue)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (historyAsync.hasError && !historyAsync.hasValue)
              _ErrorState(error: historyAsync.error!, onRetry: refresh, compact: true)
            else if (history.isEmpty)
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
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Maçlar')),
      body: body,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry, this.compact = false});

  final Object error;
  final Future<void> Function() onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget content = EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Maçlar yüklenemedi',
      message: turkishMatchError(error),
      compact: compact,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Tekrar dene'),
      ),
    );
    return compact ? content : Center(child: content);
  }
}
