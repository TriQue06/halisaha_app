import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/theme_selector.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../moderation/blocked_users_screen.dart';
import 'delete_account_dialog.dart';
import 'notification_settings.dart';

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
          const SectionHeader(
              title: 'Bildirimler', icon: Icons.notifications_none_rounded),
          // Tercihler sunucuda tutuluyor; push fonksiyonu gönderirken bakıyor.
          const _SettingsGroup(children: <Widget>[NotificationSettings()]),

          // --- HAKKINDA ------------------------------------------------
          const SectionHeader(
              title: 'Uygulama', icon: Icons.info_outline_rounded),
          _SettingsGroup(
            children: <Widget>[
              const _VersionTile(),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Gizlilik Politikası'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () =>
                    openExternalLink(context, AppConfig.privacyPolicyUrl),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Kullanım Koşulları'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => openExternalLink(context, AppConfig.termsUrl),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded),
                title: const Text('Destek ve geri bildirim'),
                subtitle: const Text(AppConfig.supportEmail),
                trailing: const Icon(Icons.mail_outline_rounded, size: 18),
                onTap: () => openExternalLink(
                  context,
                  'mailto:${AppConfig.supportEmail}?subject=Japon%20Kale%20destek',
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Çıkış Yap'),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),

          // --- HESAP ---------------------------------------------------
          // Google Play, hesap açan uygulamalarda uygulama içi hesap silme
          // yolunu zorunlu tutuyor.
          const SectionHeader(
            title: 'Hesap',
            icon: Icons.manage_accounts_outlined,
          ),
          _SettingsGroup(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: const Text('Engellenen kullanıcılar'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BlockedUsersScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.loss,
                ),
                title: const Text(
                  'Hesabımı Sil',
                  style: TextStyle(color: AppColors.loss),
                ),
                subtitle: const Text(
                  'Hesabın ve tüm verin kalıcı olarak silinir',
                ),
                onTap: () => showDeleteAccountDialog(context),
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
              Icon(Icons.format_size_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Yazı Boyutu',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
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
              const Text('A',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
              const Text('A',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
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

/// Uygulama sürümü: paket bilgisinden okunur (elle yazılan sürüm
/// mağazadakiyle uyuşmuyordu).
class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snap) {
        final PackageInfo? info = snap.data;
        return ListTile(
          leading: const Icon(Icons.verified_outlined),
          title: const Text('Sürüm'),
          trailing: Text(info == null ? '' : '${info.version} (${info.buildNumber})'),
        );
      },
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
