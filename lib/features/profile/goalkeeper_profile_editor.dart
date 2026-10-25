import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/izmir_districts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/match_errors.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import 'widgets/avatar_editor.dart';
import 'widgets/phone_editor.dart';

/// "Kaleci Profilim" formu.
///
/// Ana sayfadaki CTA ve Profil sekmesindeki "Kaleci Profilim" tabından açılır.
/// Düzenlenebilir alanlar: profil fotoğrafı, oynayabildiği ilçeler,
/// hakkımda metni, iletişim numarası ve müsaitlik durumu.
class GoalkeeperProfileEditor extends ConsumerStatefulWidget {
  const GoalkeeperProfileEditor({super.key, this.embedded = false});

  /// `true` ise kendi AppBar'ını çizmez (sekme içinde gömülü kullanım).
  final bool embedded;

  @override
  ConsumerState<GoalkeeperProfileEditor> createState() => _GoalkeeperProfileEditorState();
}

class _GoalkeeperProfileEditorState extends ConsumerState<GoalkeeperProfileEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _aboutController = TextEditingController();
  Set<String> _selectedDistricts = <String>{};
  bool _isAvailable = true;

  /// Form kayıtlı profille bir kez dolduruldu mu? Profil ekran açıldıktan
  /// sonra gelirse (sekme ilk açılışta) form boş kalıyordu.
  bool _filled = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final AsyncValue<Goalkeeper?> current = ref.read(myGoalkeeperProvider);
    if (current.hasValue) _fill(current.value);
  }

  void _fill(Goalkeeper? existing) {
    _filled = true;
    _aboutController.text = existing?.about ?? '';
    _selectedDistricts = <String>{...?existing?.districts};
    _isAvailable = existing?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    await ref.read(myGoalkeeperProvider.notifier).save(
          districts: IzmirDistricts.sorted(_selectedDistricts),
          about: _aboutController.text.trim(),
          isAvailable: _isAvailable,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final AsyncValue<Goalkeeper?> result = ref.read(myGoalkeeperProvider);
    if (result.hasError) {
      messenger.showSnackBar(
        SnackBar(content: Text('Kaydedilemedi. ${turkishMatchError(result.error!)}')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Kaleci profiliniz kaydedildi.')),
    );
    if (!widget.embedded) navigator.pop();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDistricts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir ilçe seçmelisiniz.')),
      );
      return;
    }

    // Numara olmadan kayıt veritabanı tarafından reddedilir; kullanıcıyı
    // hata mesajıyla değil, doğrudan numara ekranıyla karşıla.
    if ((ref.read(currentUserProvider)?.phone ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce profiline telefon numarası ekle.')),
      );
      showPhoneEditor(context);
      return;
    }

    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserProfile? user = ref.watch(currentUserProvider);
    final AsyncValue<Goalkeeper?> myGk = ref.watch(myGoalkeeperProvider);
    final Goalkeeper? existing = myGk.valueOrNull;
    if (!_filled && myGk.hasValue && !myGk.isLoading) _fill(existing);

    // İlk yükleme sürerken boş form göstermek, kullanıcıya profili yokmuş
    // gibi görünüyordu.
    if (!_filled) {
      final Widget waiting = Center(
        child: myGk.hasError
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(turkishMatchError(myGk.error!), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(myGoalkeeperProvider),
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      );
      return widget.embedded
          ? waiting
          : Scaffold(appBar: AppBar(title: const Text('Kaleci Profilim')), body: waiting);
    }

    final Widget body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          // --- Profil fotoğrafı ---------------------------------------
          Center(
            child: Column(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      foregroundImage: _avatarImage(existing, user),
                      child: Icon(
                        Icons.sports_mma_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showAvatarEditor(context),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.photo_camera_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  user?.fullName.isNotEmpty ?? false ? user!.fullName : '—',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  user?.age == null ? 'Yaş bilgisi yok' : '${user!.age} yaşında',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Oynayabileceği ilçeler ---------------------------------
          _FieldLabel(
            label: 'Oynayabileceğin İlçeler',
            trailing: Text(
              '${_selectedDistricts.length} seçili',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String district in IzmirDistricts.all)
                  FilterChip(
                    label: Text(district),
                    selected: _selectedDistricts.contains(district),
                    onSelected: (bool selected) => setState(() {
                      if (selected) {
                        _selectedDistricts.add(district);
                      } else {
                        _selectedDistricts.remove(district);
                      }
                    }),
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _selectedDistricts.contains(district)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Hakkımda ------------------------------------------------
          const _FieldLabel(label: 'Hakkımda'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _aboutController,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Tecrüben, müsait olduğun günler, oynama tarzın...',
              alignLabelWithHint: true,
            ),
            validator: (String? value) {
              if (value == null || value.trim().length < 15) {
                return 'Kendini biraz daha anlat (en az 15 karakter).';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),

          // --- Telefon -------------------------------------------------
          // Numara elle girilmiyor; profildeki numara kullanılır.
          const _FieldLabel(label: 'İletişim Numarası'),
          const SizedBox(height: 8),
          const ContactPhoneNotice(label: 'Kalecilerde görünecek numara'),
          const SizedBox(height: 12),

          // --- Müsaitlik ----------------------------------------------
          SwitchListTile.adaptive(
            value: _isAvailable,
            onChanged: (bool value) => setState(() => _isAvailable = value),
            title: const Text('Maç tekliflerine açığım'),
            subtitle: const Text('Kapatırsan listelerde "müsait" rozeti görünmez.'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(existing == null ? 'Kaleci Profilimi Oluştur' : 'Değişiklikleri Kaydet'),
          ),
          if (existing != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSaving ? null : _confirmDelete,
              child: const Text('Kaleci Profilimi Sil'),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Kaleci Profili Oluştur' : 'Kaleci Profilim'),
      ),
      body: body,
    );
  }
}

extension on _GoalkeeperProfileEditorState {
  Future<void> _confirmDelete() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Kaleci profilin silinsin mi?'),
        content: const Text('Kaleciler listesinden çıkarsın; aldığın puanlar da silinir.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref.read(myGoalkeeperProvider.notifier).delete();
    final AsyncValue<Goalkeeper?> result = ref.read(myGoalkeeperProvider);
    if (result.hasError) {
      // Silinemedi: başarı mesajı gösterme, kayıtlı profili geri getir.
      messenger.showSnackBar(
        SnackBar(content: Text('Silinemedi. ${turkishMatchError(result.error!)}')),
      );
      ref.invalidate(myGoalkeeperProvider);
      return;
    }
    _fill(null);
    messenger.showSnackBar(const SnackBar(content: Text('Kaleci profiliniz silindi.')));
  }
}

/// Kaleci profilinde fotoğraf. Kaleci kaydı fotoğrafı profilden okuyor
/// (tek kaynak `profiles.avatar_url`); kaleci kaydı henüz yoksa ya da
/// tazelenmediyse hesabınki gösterilir.
ImageProvider<Object>? _avatarImage(Goalkeeper? existing, UserProfile? user) {
  final String? url = (existing?.avatarUrl?.isNotEmpty ?? false)
      ? existing!.avatarUrl
      : ((user?.avatarUrl?.isNotEmpty ?? false) ? user!.avatarUrl : null);
  return url == null ? null : NetworkImage(url);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
