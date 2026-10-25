import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';

/// Hesap silme onayını açar. Ayarlar'ın yanı sıra askıya alınmış hesap ve
/// eksik profil ekranlarından da açılabilir: App Store 5.1.1(v), silme
/// yolunun her kullanıcıya açık olmasını istiyor.
Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => const _DeleteAccountDialog(),
  );
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
            'tekrar dene; sorun sürerse ${AppConfig.supportEmail} adresine yaz.';
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
