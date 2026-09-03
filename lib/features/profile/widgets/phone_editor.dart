import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Telefon numarasının düzenlendiği tek ekran.
///
/// Numara artık tek kaynaktan yönetiliyor: profil. Takım iletişim numarası
/// ve kaleci numarası buradan türüyor, veritabanı trigger'ı ikisini de
/// otomatik güncelliyor. Bu yüzden numara girişi başka hiçbir formda yok.
Future<bool> showPhoneEditor(BuildContext context) async {
  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => const _PhoneEditorSheet(),
  );
  return saved ?? false;
}

class _PhoneEditorSheet extends ConsumerStatefulWidget {
  const _PhoneEditorSheet();

  @override
  ConsumerState<_PhoneEditorSheet> createState() => _PhoneEditorSheetState();
}

class _PhoneEditorSheetState extends ConsumerState<_PhoneEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(currentUserProvider)?.phone ?? '');

  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref.read(updatePhoneProvider)(_controller.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Numara kaydedilemedi: $error');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Telefon Numaran',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Bu numara takımının iletişim numarası ve kaleci profilin için '
              'de kullanılır. Buradan değiştirdiğinde hepsi güncellenir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Telefon',
                hintText: '0532 111 22 33',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (String? value) {
                final String digits =
                    (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 10) return 'Geçerli bir telefon numarası girin.';
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isBusy ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form içinde "iletişim numaran şu, değiştirmek istersen buradan" kutusu.
///
/// Numara yoksa uyarı rengine döner ve numarayı eklemeden devam edilemez;
/// çünkü hem takım hem kaleci kaydı numara olmadan oluşturulamıyor.
class ContactPhoneNotice extends ConsumerWidget {
  const ContactPhoneNotice({super.key, this.label = 'İletişim numarası'});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final UserProfile? user = ref.watch(currentUserProvider);
    final String phone = user?.phone ?? '';
    final bool missing = phone.isEmpty;

    final Color accent = missing ? theme.colorScheme.error : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(missing ? Icons.error_outline_rounded : Icons.phone_outlined,
              size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  missing ? 'Numara eklenmemiş' : phone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: missing ? accent : null,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showPhoneEditor(context),
            child: Text(missing ? 'Ekle' : 'Değiştir'),
          ),
        ],
      ),
    );
  }
}
