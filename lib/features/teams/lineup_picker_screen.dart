import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/match_errors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../../state/team_providers.dart';
import 'team_form_screen.dart';

/// Maç kadrosu seçimi: maç kaç kişilikse o kadar boş yer açılır ve kaptan
/// her yere kadrosundan bir oyuncu seçer.
class LineupPickerScreen extends ConsumerStatefulWidget {
  const LineupPickerScreen({super.key, required this.match});

  final PendingMatch match;

  @override
  ConsumerState<LineupPickerScreen> createState() => _LineupPickerScreenState();
}

class _LineupPickerScreenState extends ConsumerState<LineupPickerScreen> {
  late List<String?> _slots = List<String?>.filled(widget.match.teamSize ?? 0, null);
  bool _prefilled = false;
  bool _isBusy = false;

  int get _filled => _slots.whereType<String>().length;

  /// Daha önce kaydedilen kadroyu (bir kez) yerlerine koyar.
  void _prefill(MatchDetail? detail, List<TeamPlayer> roster) {
    if (_prefilled || detail == null) return;
    _prefilled = true;
    final Set<String> active = roster.map((TeamPlayer p) => p.id).toSet();
    final List<LineupPlayer> mine = <LineupPlayer>[
      ...detail.challenger.lineup,
      ...detail.opponent.lineup,
    ].where((LineupPlayer p) => p.teamId == widget.match.myTeamId).toList();
    final List<String?> slots = List<String?>.filled(_slots.length, null);
    for (int i = 0; i < mine.length && i < slots.length; i++) {
      // Kadrodan çıkarılmış oyuncu yeniden seçilmeli.
      if (active.contains(mine[i].playerId)) slots[i] = mine[i].playerId;
    }
    _slots = slots;
  }

  Future<void> _save() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _isBusy = true);
    try {
      await ref
          .read(teamActionsProvider)
          .setLineup(widget.match.id, _slots.whereType<String>().toList());
      messenger.showSnackBar(const SnackBar(content: Text('Maç kadrosu kaydedildi.')));
      navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _isBusy = false);
      messenger.showSnackBar(SnackBar(content: Text(turkishMatchError(error))));
    }
  }

  Future<void> _editRoster(List<TeamPlayer> roster) async {
    final Team? team = (ref.read(myTeamsProvider).valueOrNull ?? const <Team>[])
        .where((Team t) => t.id == widget.match.myTeamId)
        .firstOrNull;
    if (team == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => TeamFormScreen.editRoster(team: team, players: roster),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int size = widget.match.teamSize ?? 0;
    final AsyncValue<List<TeamPlayer>> rosterAsync =
        ref.watch(teamRosterProvider(widget.match.myTeamId));
    final AsyncValue<MatchDetail?> detailAsync =
        ref.watch(matchDetailProvider(widget.match.id));

    return Scaffold(
      appBar: AppBar(title: Text('Maç Kadrosu · ${size}v$size')),
      body: rosterAsync.isLoading || detailAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : rosterAsync.hasError
              ? Center(
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Kadro yüklenemedi',
                    message: turkishMatchError(rosterAsync.error!),
                  ),
                )
              : Builder(builder: (BuildContext context) {
                  final List<TeamPlayer> roster = rosterAsync.value!;
                  _prefill(detailAsync.valueOrNull, roster);
                  final Set<String> active = roster.map((TeamPlayer p) => p.id).toSet();
                  // Kadro düzenlenip oyuncu çıkarıldıysa yerini boşalt.
                  for (int i = 0; i < _slots.length; i++) {
                    if (_slots[i] != null && !active.contains(_slots[i])) _slots[i] = null;
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: <Widget>[
                      Text(
                        '${widget.match.opponentTeamName} maçına çıkacak $size oyuncuyu seç.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kadroyu sonuç girilene kadar değiştirebilirsin.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      if (roster.length < size)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Kadronda ${roster.length} oyuncu var; bu maç için en az '
                            '$size gerekli. Önce kadrona oyuncu ekle.',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      for (int i = 0; i < size; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey<String>('slot-$i-${_slots[i]}'),
                            initialValue: _slots[i],
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: '${i + 1}. oyuncu',
                              prefixIcon: Icon(
                                _slots[i] == null
                                    ? Icons.person_outline_rounded
                                    : Icons.person_rounded,
                              ),
                            ),
                            items: <DropdownMenuItem<String>>[
                              for (final TeamPlayer p in roster)
                                // Başka yere seçilmiş oyuncu listede görünmez.
                                if (p.id == _slots[i] || !_slots.contains(p.id))
                                  DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                                  ),
                            ],
                            onChanged: _isBusy
                                ? null
                                : (String? v) => setState(() => _slots[i] = v),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _isBusy ? null : () => _editRoster(roster),
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Kadroya oyuncu ekle / düzenle'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: !_isBusy && _filled == size ? _save : null,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: _isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Kadroyu Kaydet ($_filled/$size)'),
                      ),
                    ],
                  );
                }),
    );
  }
}
