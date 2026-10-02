import 'package:flutter/material.dart';

import '../../../models/models.dart';

/// Kadro formunun bir satırı. [id] mevcut oyuncuda dolu, yeni satırda null.
class _RosterRow {
  _RosterRow({this.id, String firstName = '', String lastName = ''})
      : first = TextEditingController(text: firstName),
        last = TextEditingController(text: lastName);

  final String? id;
  final TextEditingController first;
  final TextEditingController last;

  /// Satır listede yeniden sıralanınca alanların karışmaması için.
  final Key key = UniqueKey();

  void dispose() {
    first.dispose();
    last.dispose();
  }
}

/// Kadro satırlarını tutar. Başlangıçta en az [kMinRosterSize] satır var;
/// "Yeni Oyuncu Ekle" ile satır eklenir, fazlalar silinebilir.
class RosterController extends ChangeNotifier {
  RosterController([List<TeamPlayer> players = const <TeamPlayer>[]]) {
    for (final TeamPlayer p in players) {
      _rows.add(_RosterRow(id: p.id, firstName: p.firstName, lastName: p.lastName));
    }
    while (_rows.length < kMinRosterSize) {
      _rows.add(_RosterRow());
    }
  }

  static const int maxPlayers = 30;

  final List<_RosterRow> _rows = <_RosterRow>[];

  int get length => _rows.length;
  bool get canAdd => _rows.length < maxPlayers;
  bool get canRemove => _rows.length > kMinRosterSize;

  void add() {
    if (!canAdd) return;
    _rows.add(_RosterRow());
    notifyListeners();
  }

  void removeAt(int index) {
    if (!canRemove) return;
    _rows.removeAt(index).dispose();
    notifyListeners();
  }

  /// Form doğrulandıktan sonra gönderilecek liste.
  List<RosterEntry> get entries => <RosterEntry>[
        for (final _RosterRow r in _rows)
          RosterEntry(id: r.id, firstName: r.first.text, lastName: r.last.text),
      ];

  @override
  void dispose() {
    for (final _RosterRow r in _rows) {
      r.dispose();
    }
    super.dispose();
  }
}

/// Kadro satırları (ad + soyad) ve en altta "Yeni Oyuncu Ekle" butonu.
///
/// Bir [Form] içinde kullanılır; her satırın ad ve soyadı zorunlu.
class RosterEditor extends StatelessWidget {
  const RosterEditor({super.key, required this.controller});

  final RosterController controller;

  static String? _required(String? value, String label) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return '$label gerekli';
    if (v.length > 40) return 'En fazla 40 karakter';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < controller._rows.length; i++)
              Padding(
                key: controller._rows[i].key,
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 28,
                      height: 48,
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: controller._rows[i].first,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Ad', isDense: true),
                        validator: (String? v) => _required(v, 'Ad'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: controller._rows[i].last,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Soyad', isDense: true),
                        validator: (String? v) => _required(v, 'Soyad'),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 48,
                      child: controller.canRemove
                          ? IconButton(
                              tooltip: 'Oyuncuyu çıkar',
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                              color: theme.colorScheme.error,
                              onPressed: () => controller.removeAt(i),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: controller.canAdd ? controller.add : null,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Yeni Oyuncu Ekle'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            ),
            const SizedBox(height: 6),
            Text(
              'En az $kMinRosterSize oyuncu gerekli · şu an ${controller.length}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
