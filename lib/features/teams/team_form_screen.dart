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
      : team = null;

  /// Var olan takımın kadrosu. Tam adlar (soyad dahil) yalnızca kaptana
  /// açık olduğu için ekran kadroyu kendisi yükler.
  const TeamFormScreen.editRoster({
    super.key,
    required Team this.team,
  }) : pitch = null;

  final Pitch? pitch;
  final Team? team;

  bool get isCreate => team == null;

  @override
  ConsumerState<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends ConsumerState<TeamFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  RosterController _roster = RosterController();
  bool _isBusy = false;

  /// Düzenlemede kadro sunucudan gelene kadar form gösterilmez.
  bool _isLoading = false;
  String? _loadError;

  /// Kayıtlı olmayan kişilerin adları başkalarına görünüyor; kaptandan
  /// bunun için onay aldığını teyit etmesi isteniyor (App Store 5.1).
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isCreate) _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final List<RosterMember> members =
          await ref.read(teamRepositoryProvider).fetchRosterFull(widget.team!.id);
      if (!mounted) return;
      _roster.dispose();
      setState(() {
        _roster = RosterController(members);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = turkishMatchError(error);
      });
    }
  }

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
    final bool canSubmit = !_isBusy && _consent && (!widget.isCreate || hasPhone);

    if (_isLoading || _loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kadroyu Düzenle')),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _loadRoster, child: const Text('Tekrar dene')),
                    ],
                  ),
                ),
        ),
      );
    }

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
              'Oyuncuların uygulamaya kayıtlı olması gerekmez; takma ad da '
              'kullanabilirsin. Diğer kullanıcılar oyuncuları "Ahmet Y." '
              'biçiminde görür; soyadın tamamını yalnızca sen görürsün. '
              'Çıkardığın oyuncunun geçmiş istatistikleri silinmez.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            RosterEditor(controller: _roster),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _consent,
              onChanged: _isBusy ? null : (bool? v) => setState(() => _consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Kadroya eklediğim kişilerin adlarının ve maç istatistiklerinin '
                'uygulamada görünmesi için onaylarını aldım. Biri isterse onu '
                'kadrodan çıkaracağım.',
              ),
            ),
            const SizedBox(height: 12),
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
