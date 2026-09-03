import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/izmir_districts.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Google ile giren kullanıcıların eksik profilini tamamlar.
///
/// Google ad/soyad ve avatar verir ama **doğum tarihi vermez**. Ad, soyad
/// ve doğum tarihi zorunlu; telefon isteğe bağlı (takım kurarken ve kaleci
/// profilinde zaten ayrıca isteniyor).
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  DateTime? _birthDate;
  String? _district;
  bool _isBusy = false;
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Sağlayıcıdan gelen kısmi bilgileri forma doldurur (yalnızca bir kez).
  void _prefill(Map<String, dynamic>? profile) {
    if (_prefilled || profile == null) return;
    _prefilled = true;

    _firstNameController.text = (profile['first_name'] as String?) ?? '';
    _lastNameController.text = (profile['last_name'] as String?) ?? '';

    final String? phone = profile['phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      // '+905321112233' -> '532 111 22 33' (ekranda +90 ön ek olarak duruyor)
      _phoneController.text = phone.replaceFirst(RegExp(r'^\+90'), '');
    }

    final String? birth = profile['birth_date'] as String?;
    if (birth != null) _birthDate = DateTime.tryParse(birth);

    _district = profile['district'] as String?;
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      locale: const Locale('tr', 'TR'),
      helpText: 'Doğum tarihini seç',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickDistrict() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (BuildContext context, ScrollController controller) => ListView.builder(
          controller: controller,
          itemCount: IzmirDistricts.all.length,
          itemBuilder: (BuildContext context, int index) {
            final String district = IzmirDistricts.all[index];
            return ListTile(
              title: Text(district),
              trailing: district == _district
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(district),
            );
          },
        ),
      ),
    );
    if (picked != null) setState(() => _district = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_birthDate == null) {
      setState(() => _error = 'Doğum tarihini seç.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).completeProfile(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            birthDate: _birthDate!,
            phone: _phoneController.text,
            district: _district,
          );
      // Profili yeniden çek; AuthGate tamamlanmış görüp MainShell'e geçer.
      ref.invalidate(myProfileProvider);
    } catch (error) {
      if (mounted) setState(() => _error = turkishAuthError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>?> profileAsync = ref.watch(myProfileProvider);
    final User? user = ref.watch(sessionProvider)?.user;

    profileAsync.whenData(_prefill);

    final String? avatarUrl = profileAsync.valueOrNull?['avatar_url'] as String?;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              const AuthHeader(
                title: 'Profilini tamamla',
                subtitle: 'Takım kurmak ve rakiplerle iletişim için '
                    'birkaç bilgiye daha ihtiyacımız var.',
              ),
              const SizedBox(height: 24),

              // --- Sağlayıcıdan gelen kimlik -------------------------
              if (user != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        foregroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: Icon(Icons.person_rounded,
                            color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.email ?? user.phone ?? 'Hesabın',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.read(authControllerProvider).signOut(),
                        child: const Text('Çıkış'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(labelText: 'Ad'),
                            validator: (String? v) =>
                                (v?.trim().length ?? 0) < 2 ? 'Adını gir.' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(labelText: 'Soyad'),
                            validator: (String? v) =>
                                (v?.trim().length ?? 0) < 2 ? 'Soyadını gir.' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: _pickBirthDate,
                      borderRadius: BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Doğum tarihi',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          _birthDate == null
                              ? 'Seç'
                              : DateFormat('d MMMM yyyy', 'tr_TR').format(_birthDate!),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _birthDate == null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                        LengthLimitingTextInputFormatter(14),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Telefon (isteğe bağlı)',
                        hintText: '532 111 22 33',
                        prefixText: '+90 ',
                        prefixIcon: Icon(Icons.smartphone_rounded),
                        helperText: 'Takım kurarken ayrıca istenecek. Şimdi boş bırakabilirsin.',
                      ),
                      validator: (String? value) {
                        final String digits =
                            (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.isEmpty) return null; // isteğe bağlı
                        final String core =
                            digits.startsWith('0') ? digits.substring(1) : digits;
                        if (core.length != 10) return '10 haneli numaranı gir.';
                        if (!core.startsWith('5')) {
                          return 'Cep numarası 5 ile başlamalı.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: _pickDistrict,
                      borderRadius: BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'İlçe (opsiyonel)',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        child: Text(
                          _district ?? 'Seç',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _district == null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_error != null) ...<Widget>[
                      AuthErrorBox(message: _error!),
                      const SizedBox(height: 16),
                    ],

                    FilledButton(
                      onPressed: _isBusy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Devam Et'),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
