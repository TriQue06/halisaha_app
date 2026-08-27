import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/izmir_districts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';

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
  late final TextEditingController _aboutController;
  late final TextEditingController _phoneController;
  late Set<String> _selectedDistricts;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    final Goalkeeper? existing = ref.read(myGoalkeeperProvider);
    final UserProfile user = ref.read(currentUserProvider);

    _aboutController = TextEditingController(text: existing?.about ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? user.phone);
    _selectedDistricts = <String>{...?existing?.districts};
    _isAvailable = existing?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDistricts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir ilçe seçmelisiniz.')),
      );
      return;
    }

    ref.read(myGoalkeeperProvider.notifier).save(
          districts: IzmirDistricts.sorted(_selectedDistricts),
          about: _aboutController.text.trim(),
          phone: _phoneController.text.trim(),
          isAvailable: _isAvailable,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaleci profiliniz kaydedildi.')),
    );
    if (!widget.embedded) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserProfile user = ref.watch(currentUserProvider);
    final Goalkeeper? existing = ref.watch(myGoalkeeperProvider);

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
                      foregroundImage: (existing?.avatarUrl?.isNotEmpty ?? false)
                          ? NetworkImage(existing!.avatarUrl!)
                          : null,
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
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fotoğraf seçimi (image_picker) burada bağlanacak.'),
                            ),
                          ),
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
                  user.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${user.age} yaşında',
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
          const _FieldLabel(label: 'İletişim Numarası'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '+90 5XX XXX XX XX',
            ),
            validator: (String? value) {
              if (value == null || value.trim().length < 10) {
                return 'Geçerli bir telefon numarası girin.';
              }
              return null;
            },
          ),
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
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(existing == null ? 'Kaleci Profilimi Oluştur' : 'Değişiklikleri Kaydet'),
          ),
          if (existing != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(myGoalkeeperProvider.notifier).delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kaleci profiliniz silindi.')),
                );
              },
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
