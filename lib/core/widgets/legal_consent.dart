import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'legal_sheet.dart';

/// "Kullanım koşullarını ve gizlilik politikasını kabul ediyorum" onayı.
///
/// Hesabın açıldığı her ekranda (e-posta ile kayıt ve sosyal giriş
/// butonları) gösteriliyor: App Store incelemesi, hesap oluşturulan
/// ekranlardan bu metinlere ulaşılmasını istiyor.
///
/// Bağlantılar metni uygulama içinde açar; kullanıcı giriş akışından
/// çıkmaz.
class LegalConsent extends StatelessWidget {
  const LegalConsent({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? base = theme.textTheme.bodySmall;
    final TextStyle? link = base?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    // Bağlantılar WidgetSpan içinde: TapGestureRecognizer'ın aksine
    // dispose gerektirmiyor ve dokunma alanı metin kadar oluyor.
    WidgetSpan linkSpan(String text, String title, String url) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => showLegalSheet(context, title: title, url: url),
          child: Text(text, style: link),
        ),
      );
    }

    return CheckboxListTile(
      value: value,
      onChanged: enabled ? (bool? v) => onChanged(v ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text.rich(
        TextSpan(
          style: base,
          children: <InlineSpan>[
            linkSpan('Kullanım Koşulları', 'Kullanım Koşulları', AppConfig.termsUrl),
            const TextSpan(text: ' ve '),
            linkSpan(
              'Gizlilik Politikası',
              'Gizlilik Politikası',
              AppConfig.privacyPolicyUrl,
            ),
            const TextSpan(text: '\'nı okudum, kabul ediyorum. 18 yaşından büyüğüm.'),
          ],
        ),
      ),
    );
  }
}
