import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/theme_selector.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';

/// Ayarlar sekmesi: tema, yazı boyutu ve bildirim tercihleri.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: <Widget>[
          // --- GÖRÜNÜM -------------------------------------------------
          const SectionHeader(title: 'Görünüm', icon: Icons.palette_outlined),
          _SettingsGroup(
            children: <Widget>[
              const ThemeSelector(),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _TextScaleTile(
                value: settings.textScale,
                onChanged: controller.setTextScale,
              ),
            ],
          ),

          // --- BİLDİRİMLER ---------------------------------------------
          const SectionHeader(title: 'Bildirimler', icon: Icons.notifications_none_rounded),
          _SettingsGroup(
            children: <Widget>[
              SwitchListTile.adaptive(
                value: settings.challengeNotifications,
                onChanged: controller.setChallengeNotifications,
                secondary: const Icon(Icons.bolt_rounded),
                title: const Text('Maç teklifi bildirimleri'),
                subtitle: const Text('Takımına maç teklifi geldiğinde haber ver'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile.adaptive(
                value: settings.matchNotifications,
                onChanged: controller.setMatchNotifications,
                secondary: const Icon(Icons.sports_soccer_rounded),
                title: const Text('Maç bildirimleri'),
                subtitle: const Text('Onay, tarih ve sonuç hatırlatmaları'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile.adaptive(
                value: settings.goalkeeperNotifications,
                onChanged: controller.setGoalkeeperNotifications,
                secondary: const Icon(Icons.sports_mma_rounded),
                title: const Text('Kaleci talepleri'),
                subtitle: const Text('Bölgende kaleci arayan takımlar'),
              ),
            ],
          ),

          // --- HAKKINDA ------------------------------------------------
          const SectionHeader(title: 'Uygulama', icon: Icons.info_outline_rounded),
          _SettingsGroup(
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text('Sürüm'),
                trailing: Text('1.0.0'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Çıkış Yap'),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Çıkış onayı. Onaylanırsa oturum kapanır ve [AuthGate] giriş ekranına döner.
  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text('Hesabından çıkmak istediğine emin misin?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authControllerProvider).signOut();
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

/// Yazı puntosu slider'ı — uygulama genelindeki text scale factor'ü değiştirir.
class _TextScaleTile extends StatelessWidget {
  const _TextScaleTile({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  String get _label => switch (value) {
        < 0.9 => 'Küçük',
        < 1.05 => 'Normal',
        < 1.25 => 'Büyük',
        _ => 'Çok Büyük',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.format_size_rounded, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Yazı Boyutu',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$_label · ${(value * 100).round()}%',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const Text('A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  value: value,
                  min: 0.8,
                  max: 1.4,
                  // 0.05'lik adımlar
                  divisions: 12,
                  label: _label,
                  onChanged: onChanged,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            ],
          ),
          // Canlı önizleme
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              'Örnek: Bornova Kartalları — Ege FC maçı Cumartesi 21:00',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kart içinde gruplanmış ayar satırları.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(child: Column(children: children)),
    );
  }
}
