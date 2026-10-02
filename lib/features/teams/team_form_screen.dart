import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/match_errors.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../../state/team_providers.dart';
import '../profile/widgets/phone_editor.dart';
import 'widgets/roster_editor.dart';

/// Takım kurma (ad + kadro) ya da mevcut takımın kadrosunu düzenleme.
class TeamFormScreen extends ConsumerStatefulWidget {
  /// Bu sahaya yeni takım.
  const TeamFormScreen.create({super.key, required Pitch this.pitch})
      : team = null,
        players = const <TeamPlayer>[];

  /// Var olan takımın kadrosu.
  const TeamFormScreen.editRoster({
    super.key,
    required Team this.team,
    required this.players,
  }) : pitch = null;

  final Pitch? pitch;
  final Team? team;
  final List<TeamPlayer> players;

  bool get isCreate => team == null;

  @override
  ConsumerState<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends ConsumerState<TeamFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  late final RosterController _roster = RosterController(widget.players);
  bool _isBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _roster.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final TeamActions actions = ref.read(teamActionsProvider);
    setState(() => _isBusy = true);

    try {
      if (widget.isCreate) {
        await actions.createTeam(
          pitchId: widget.pitch!.id,
          name: _name.text,
          players: _roster.entries,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('${widget.pitch!.name} sahasına takımın kaydedildi.')),
        );
      } else {
        await actions.saveRoster(widget.team!.id, _roster.entries);
        messenger.showSnackBar(const SnackBar(content: Text('Kadro kaydedildi.')));
      }
      navigator.pop(true);
    } catch (error) {
      if (mounted) setState(() => _isBusy = false);
      messenger.showSnackBar(SnackBar(content: Text(turkishMatchError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Numara olmadan takım kurulamaz (veritabanı da reddediyor).
    final bool hasPhone = (ref.watch(currentUserProvider)?.phone ?? '').isNotEmpty;
    final bool canSubmit = !_isBusy && (!widget.isCreate || hasPhone);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreate ? 'Takımını Oluştur' : 'Kadroyu Düzenle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            if (widget.isCreate) ...<Widget>[
              Text(
                widget.pitch!.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Takım Adı',
                  hintText: 'Örn. Bornova Kartalları',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Takım adı en az 3 karakter olmalı.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Numara elle girilmiyor: profildeki numara kullanılır.
              const ContactPhoneNotice(label: 'Takım iletişim numarası'),
              const SizedBox(height: 20),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.team!.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            Text(
              'Kadro',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Oyuncuların uygulamaya kayıtlı olması gerekmez; misafir '
              'oyuncuları da ekleyebilirsin. Çıkardığın oyuncunun geçmiş '
              'istatistikleri silinmez.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            RosterEditor(controller: _roster),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isCreate ? 'Takımı Kaydet' : 'Kadroyu Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
