import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/match_errors.dart';
import '../../state/auth_controller.dart';

/// Bildirim tercihleri. Değerler profilde (`notify_challenges`,
/// `notify_matches`) tutuluyor ve push fonksiyonu göndermeden önce bunlara
/// bakıyor; önceden yalnızca cihazda saklanıyor, gönderimi etkilemiyordu.
class NotificationSettings extends ConsumerStatefulWidget {
  const NotificationSettings({super.key});

  @override
  ConsumerState<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<NotificationSettings> {
  /// Kayıt sürerken anında yansıtılan değerler (iyimser güncelleme).
  bool? _challenges;
  bool? _matches;
  bool _isBusy = false;

  Future<void> _save({bool? challenges, bool? matches}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isBusy = true;
      if (challenges != null) _challenges = challenges;
      if (matches != null) _matches = matches;
    });
    try {
      await ref.read(supabaseProvider).rpc<void>('set_notification_prefs', params: <String, dynamic>{
        'p_challenges': challenges,
        'p_matches': matches,
      });
      ref.invalidate(myProfileProvider);
    } catch (error) {
      if (!mounted) return;
      // Kaydedilemedi: anahtarı eski hâline döndür.
      setState(() {
        if (challenges != null) _challenges = !challenges;
        if (matches != null) _matches = !matches;
      });
      messenger.showSnackBar(SnackBar(content: Text(turkishMatchError(error))));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? profile = ref.watch(myProfileProvider).valueOrNull;
    final bool challenges = _challenges ?? (profile?['notify_challenges'] as bool?) ?? true;
    final bool matches = _matches ?? (profile?['notify_matches'] as bool?) ?? true;
    final bool enabled = profile != null && !_isBusy;

    return Column(
      children: <Widget>[
        SwitchListTile.adaptive(
          value: challenges,
          onChanged: enabled ? (bool v) => _save(challenges: v) : null,
          secondary: const Icon(Icons.bolt_rounded),
          title: const Text('Maç teklifi bildirimleri'),
          subtitle: const Text('Takımına maç teklifi geldiğinde haber ver'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        SwitchListTile.adaptive(
          value: matches,
          onChanged: enabled ? (bool v) => _save(matches: v) : null,
          secondary: const Icon(Icons.sports_soccer_rounded),
          title: const Text('Maç bildirimleri'),
          subtitle: const Text('Kabul, onay, tarih, sonuç ve iptal haberleri'),
        ),
      ],
    );
  }
}
