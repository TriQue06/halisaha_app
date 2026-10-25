import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'legal_sheet.dart';

/// Kullanım koşullarının kabulünü kayıt altına alır.
///
/// Kutu işaretlendiği an oturum henüz yok (giriş/kayıt öncesi); bu yüzden
/// kabul önce cihazda hatırlanıyor, oturum açılınca [syncToServer] ile
/// profile sürüm ve tarihle yazılıyor (`accept_terms`). Daha önce kabul
/// eden kullanıcıya kutu tekrar boş gösterilmiyor.
abstract final class TermsAcceptance {
  static const String _key = 'legal.accepted_terms_version';

  /// AuthGate her yeniden çizildiğinde tekrar istek atılmasın.
  static String? _syncedFor;

  static Future<void> remember(bool accepted) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (accepted) {
        await prefs.setString(_key, AppConfig.termsVersion);
      } else {
        await prefs.remove(_key);
      }
    } catch (error) {
      debugPrint('Koşul kabulü cihazda saklanamadı: $error');
    }
  }

  /// Bu cihazda güncel koşullar kabul edilmiş mi?
  static Future<bool> isAccepted() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key) == AppConfig.termsVersion;
    } catch (_) {
      return false;
    }
  }

  /// Profilde güncel sürüm kayıtlı değilse ve cihazda kabul varsa sunucuya
  /// yazar. Hata girişi engellemez; bir sonraki açılışta tekrar denenir.
  static Future<void> syncToServer(SupabaseClient client, Map<String, dynamic> profile) async {
    final String? uid = profile['id'] as String?;
    if (profile['terms_version'] == AppConfig.termsVersion || _syncedFor == uid) return;
    _syncedFor = uid;
    if (!await isAccepted()) return;
    try {
      await client.rpc<void>('accept_terms', params: <String, dynamic>{
        'p_version': AppConfig.termsVersion,
      });
    } catch (error) {
      debugPrint('Koşul kabulü sunucuya yazılamadı: $error');
    }
  }
}

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
      onChanged: enabled
          ? (bool? v) {
              TermsAcceptance.remember(v ?? false);
              onChanged(v ?? false);
            }
          : null,
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
