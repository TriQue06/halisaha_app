import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/app_providers.dart';

/// Profil fotoğrafı seçenekleri: galeriden seç, fotoğraf çek, kaldır.
///
/// Profil başlığındaki fotoğraftan ve kaleci profilindeki kamera
/// butonundan açılır. Yükleme bitene kadar sayfa geri tuşuyla kapanmaz;
/// hata olursa sayfanın içinde gösterilir.
Future<void> showAvatarEditor(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => const _AvatarEditorSheet(),
  );
}

class _AvatarEditorSheet extends ConsumerStatefulWidget {
  const _AvatarEditorSheet();

  @override
  ConsumerState<_AvatarEditorSheet> createState() => _AvatarEditorSheetState();
}

class _AvatarEditorSheetState extends ConsumerState<_AvatarEditorSheet> {
  bool _isBusy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final XFile? file;
    try {
      // 512 px profil fotoğrafı için fazlasıyla yeterli; telefon kamerasının
      // 4-5 MB'lık fotoğrafı ~50-100 KB'a iniyor.
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (error) {
      _fail('Fotoğraf seçilemedi. Uygulamanın galeri/kamera iznini kontrol et.\n($error)');
      return;
    }
    if (file == null) return; // kullanıcı vazgeçti

    final Uint8List bytes = await file.readAsBytes();
    await _run(() => ref.read(avatarActionsProvider).upload(bytes));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } on FormatException catch (error) {
      _fail(error.message);
    } catch (error) {
      _fail('İşlem tamamlanamadı. İnternet bağlantını kontrol edip tekrar dene.\n($error)');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasAvatar = ref.watch(currentUserProvider)?.avatarUrl != null;

    return PopScope(
      canPop: !_isBusy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Profil fotoğrafı',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (_isBusy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...<Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(hasAvatar ? 'Galeriden yeni fotoğraf seç' : 'Galeriden seç'),
                  onTap: () => _pick(ImageSource.gallery),
                ),
                // Web'de ayrı kamera seçeneği yok: tarayıcının dosya seçicisi
                // (iPhone Safari dahil) zaten "Fotoğraf çek" seçeneği sunuyor.
                if (!kIsWeb)
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Fotoğraf çek'),
                    onTap: () => _pick(ImageSource.camera),
                  ),
                if (hasAvatar)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.loss),
                    title: const Text(
                      'Fotoğrafı kaldır',
                      style: TextStyle(color: AppColors.loss),
                    ),
                    onTap: () => _run(() => ref.read(avatarActionsProvider).remove()),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.loss),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
