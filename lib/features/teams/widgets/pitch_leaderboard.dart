import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../../state/team_providers.dart';
import '../team_profile_screen.dart';

/// Sahanın gol krallığı / asist krallığı (ilk 10).
class PitchLeaderboard extends ConsumerStatefulWidget {
  const PitchLeaderboard({super.key, required this.pitchId});

  final String pitchId;

  @override
  ConsumerState<PitchLeaderboard> createState() => _PitchLeaderboardState();
}

class _PitchLeaderboardState extends ConsumerState<PitchLeaderboard> {
  bool _byAssists = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<LeaderboardEntry>> async = ref.watch(
      pitchLeadersProvider((pitchId: widget.pitchId, byAssists: _byAssists)),
    );
    final List<LeaderboardEntry> rows = async.valueOrNull ?? const <LeaderboardEntry>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: false,
                label: Text('Gol Krallığı'),
                icon: Icon(Icons.sports_soccer_rounded),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Asist Krallığı'),
                icon: Icon(Icons.assistant_direction_outlined),
              ),
            ],
            selected: <bool>{_byAssists},
            onSelectionChanged: (Set<bool> s) => setState(() => _byAssists = s.first),
          ),
          const SizedBox(height: 10),
          if (async.isLoading && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            EmptyState(
              icon: Icons.emoji_events_outlined,
              title: _byAssists ? 'Henüz asist yok' : 'Henüz gol yok',
              message: 'Maç sonunda kaptanlar gol ve asistleri girdikçe liste dolacak.',
              compact: true,
            )
          else
            Card(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < rows.length; i++)
                    ListTile(
                      dense: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TeamProfileScreen(teamId: rows[i].teamId),
                        ),
                      ),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: i == 0
                            ? const Color(0xFFF5B301)
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: i == 0 ? Colors.black : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      title: Text(rows[i].name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${rows[i].teamName} · ${rows[i].appearances} maç',
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${_byAssists ? rows[i].assists : rows[i].goals}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
