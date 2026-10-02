import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/match_errors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/team_repository.dart';
import '../../models/models.dart';
import '../../state/team_providers.dart';

/// Maç sonu ekranı.
///
/// * [withScore] true: teklifi gönderen kaptan skoru ve kendi oyuncularının
///   gol/asistini girer (maç tamamlanır).
/// * [withScore] false: maç bittikten sonra kaptan yalnızca kendi
///   oyuncularının gol/asistini girer ya da düzeltir.
class MatchResultScreen extends ConsumerStatefulWidget {
  const MatchResultScreen({
    super.key,
    required this.matchId,
    required this.myTeamId,
    required this.withScore,
  });

  final String matchId;
  final String myTeamId;
  final bool withScore;

  @override
  ConsumerState<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends ConsumerState<MatchResultScreen> {
  int _myScore = 0;
  int _opponentScore = 0;
  final Map<String, PlayerMatchStats> _stats = <String, PlayerMatchStats>{};
  bool _loaded = false;
  bool _isBusy = false;

  void _load(MatchDetail detail) {
    if (_loaded) return;
    _loaded = true;
    final MatchSide mine = _mySide(detail);
    for (final LineupPlayer p in mine.lineup) {
      if (p.playerId.isEmpty) continue;
      _stats[p.playerId] = PlayerMatchStats(goals: p.goals, assists: p.assists);
    }
  }

  MatchSide _mySide(MatchDetail d) =>
      d.challenger.teamId == widget.myTeamId ? d.challenger : d.opponent;
  MatchSide _otherSide(MatchDetail d) =>
      d.challenger.teamId == widget.myTeamId ? d.opponent : d.challenger;

  int get _goalSum => _stats.values.fold(0, (int s, PlayerMatchStats p) => s + p.goals);
  int get _assistSum => _stats.values.fold(0, (int s, PlayerMatchStats p) => s + p.assists);

  /// Gol/asist toplamı takımın skorunu geçemez (kendi kalesine gol olabilir,
  /// bu yüzden eşit olması şart değil).
  String? _validation(int? teamScore) {
    if (teamScore == null) return null;
    if (_goalSum > teamScore) {
      return 'Gol toplamı ($_goalSum) takımın skorunu ($teamScore) geçemez.';
    }
    if (_assistSum > teamScore) {
      return 'Asist toplamı ($_assistSum) takımın skorunu ($teamScore) geçemez.';
    }
    return null;
  }

  Future<void> _submit() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final TeamActions actions = ref.read(teamActionsProvider);
    setState(() => _isBusy = true);
    try {
      if (widget.withScore) {
        await actions.reportScore(
          matchId: widget.matchId,
          myScore: _myScore,
          opponentScore: _opponentScore,
          stats: _stats,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch ((_myScore - _opponentScore).sign) {
              1 => 'Galibiyet kaydedildi. Tebrikler!',
              0 => 'Beraberlik kaydedildi.',
              _ => 'Mağlubiyet kaydedildi.',
            }),
          ),
        );
      } else {
        await actions.savePlayerStats(widget.matchId, _stats);
        messenger.showSnackBar(const SnackBar(content: Text('Gol ve asistler kaydedildi.')));
      }
      navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _isBusy = false);
      messenger.showSnackBar(SnackBar(content: Text(turkishMatchError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<MatchDetail?> async = ref.watch(matchDetailProvider(widget.matchId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.withScore ? 'Sonucu Gir' : 'Gol ve Asistler')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Maç yüklenemedi',
            message: turkishMatchError(e),
          ),
        ),
        data: (MatchDetail? detail) {
          if (detail == null) {
            return const Center(
              child: EmptyState(icon: Icons.search_off_rounded, title: 'Maç bulunamadı'),
            );
          }
          _load(detail);
          final MatchSide mine = _mySide(detail);
          final MatchSide other = _otherSide(detail);
          final int? teamScore = widget.withScore ? _myScore : mine.score;
          final String? error = _validation(teamScore);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              if (widget.withScore) ...<Widget>[
                Text(
                  'Skor',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _ScoreColumn(
                            label: mine.teamName,
                            value: _myScore,
                            onChanged: (int v) => setState(() => _myScore = v),
                          ),
                        ),
                        Text(
                          '-',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Expanded(
                          child: _ScoreColumn(
                            label: other.teamName,
                            value: _opponentScore,
                            onChanged: (int v) => setState(() => _opponentScore = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else if (mine.score != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Skor: ${mine.teamName} ${mine.score} - ${other.score} ${other.teamName}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(
                'Gol ve asistler (isteğe bağlı)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Yalnızca kendi oyuncularını girersin; rakip kaptan kendi '
                'oyuncularını girer.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              if (mine.lineup.isEmpty)
                const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Maç kadrosu seçilmemiş',
                  message: 'Gol ve asist girmek için maçtan önce kadro seçilmeliydi.',
                  compact: true,
                )
              else
                for (final LineupPlayer p in mine.lineup)
                  if (p.playerId.isNotEmpty)
                    _PlayerStatsRow(
                      name: p.name,
                      stats: _stats[p.playerId] ?? const PlayerMatchStats(),
                      onChanged: (PlayerMatchStats s) =>
                          setState(() => _stats[p.playerId] = s),
                    ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(error, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isBusy || error != null ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.withScore ? 'Sonucu Kaydet' : 'Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        NumberStepper(value: value, max: 99, onChanged: onChanged, large: true),
      ],
    );
  }
}

class _PlayerStatsRow extends StatelessWidget {
  const _PlayerStatsRow({required this.name, required this.stats, required this.onChanged});

  final String name;
  final PlayerMatchStats stats;
  final ValueChanged<PlayerMatchStats> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.sports_soccer_rounded, size: 16, color: theme.colorScheme.primary),
          NumberStepper(
            value: stats.goals,
            max: 50,
            onChanged: (int v) => onChanged(stats.copyWith(goals: v)),
          ),
          const SizedBox(width: 6),
          Icon(Icons.assistant_direction_outlined,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          NumberStepper(
            value: stats.assists,
            max: 50,
            onChanged: (int v) => onChanged(stats.copyWith(assists: v)),
          ),
        ],
      ),
    );
  }
}

/// − değer + düğmeleri.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 99,
    this.large = false,
  });

  final int value;
  final int max;
  final bool large;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_rounded),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: large ? 40 : 22,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: (large ? theme.textTheme.headlineMedium : theme.textTheme.titleMedium)
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_rounded),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
