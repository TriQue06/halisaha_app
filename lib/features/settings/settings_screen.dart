import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link_launcher.dart';
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
          const SectionHeader(
              title: 'Bildirimler', icon: Icons.notifications_none_rounded),
          _SettingsGroup(
            children: <Widget>[
              SwitchListTile.adaptive(
                value: settings.challengeNotifications,
                onChanged: controller.setChallengeNotifications,
                secondary: const Icon(Icons.bolt_rounded),
                title: const Text('Maç teklifi bildirimleri'),
                subtitle:
                    const Text('Takımına maç teklifi geldiğinde haber ver'),
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
          const SectionHeader(
              title: 'Uygulama', icon: Icons.info_outline_rounded),
          _SettingsGroup(
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text('Sürüm'),
                trailing: Text('1.0.0'),
              ),
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
                onTap: () => _confirmDeleteAccount(context, ref),
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

  /// Hesap silme onayı. Geri alınamadığı için kullanıcıdan onay kelimesini
  /// yazmasını istiyoruz — yanlışlıkla dokunma ile hesap silinmesin.
  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const _DeleteAccountDialog(),
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

/// Hesap silme onay diyaloğu.
///
/// Silme geri alınamaz, o yüzden tek dokunuşla tetiklenmiyor: kullanıcının
/// onay kelimesini yazması gerekiyor. Silme sırasında diyalog kapanmaz ve
/// butonlar kilitlenir; iş bitince [AuthGate] oturum kapandığı için
/// kullanıcıyı giriş ekranına düşürür.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  static const String _confirmWord = 'SİL';

  final TextEditingController _controller = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      !_isBusy && _controller.text.trim().toUpperCase() == _confirmWord;

  Future<void> _delete() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).deleteAccount();
      // Başarılı: oturum kapandı, AuthGate giriş ekranını gösterecek.
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = 'Hesap silinemedi. İnternet bağlantını kontrol edip '
            'tekrar dene.\n($error)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Hesabımı sil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Bu işlem geri alınamaz. Silinecekler:\n\n'
              '• Hesabın ve profil bilgilerin\n'
              '• Takımın ve maç geçmişin\n'
              '• Kaleci profilin ve aldığın puanlar\n'
              '• Bildirimlerin',
            ),
            const SizedBox(height: 16),
            Text(
              'Onaylamak için "$_confirmWord" yaz:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_isBusy,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: _confirmWord),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.loss,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _canDelete ? _delete : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
          child: _isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kalıcı Olarak Sil'),
        ),
      ],
    );
  }
}
