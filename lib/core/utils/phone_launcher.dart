import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Telefon araması başlatma yardımcıları.
///
/// `tel:` şeması **çevirici uygulamayı numara girilmiş halde açar**,
/// aramayı kendisi başlatmaz. Bu yüzden `CALL_PHONE` iznine ihtiyaç yoktur:
/// aramayı kullanıcı onaylar. Doğrudan arama başlatan `ACTION_CALL` ise
/// tehlikeli izin sınıfındadır ve Play Store incelemesinde gerekçe ister —
/// bir iletişim butonu için gereksiz.
///
/// Android tarafında `AndroidManifest.xml` içindeki
/// `<queries><intent><action android:name="android.intent.action.DIAL"/>`
/// girdisi zorunludur; Android 11+ paket görünürlüğü kuralları yüzünden
/// o olmadan `canLaunchUrl` false döner.
abstract final class PhoneLauncher {
  /// Numaradan çevirici için güvenli bir `tel:` URI'si üretir.
  ///
  /// Boşluk, parantez ve tire temizlenir; baştaki `+` korunur.
  static Uri? _toTelUri(String rawNumber) {
    final String cleaned = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.replaceAll('+', '').isEmpty) return null;
    return Uri(scheme: 'tel', path: cleaned);
  }

  /// Çeviriciyi [rawNumber] ile açar.
  ///
  /// Başarısız olursa kullanıcıya nedenini söyleyen bir SnackBar gösterir
  /// (örn. tablette çevirici uygulaması bulunmaması).
  static Future<void> call(BuildContext context, String rawNumber) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Uri? uri = _toTelUri(rawNumber);

    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Geçerli bir telefon numarası yok.')),
      );
      return;
    }

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger.showSnackBar(
          SnackBar(content: Text('Arama başlatılamadı: $rawNumber')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Bu cihazda arama yapılamıyor. Numara: $rawNumber'),
        ),
      );
    }
  }
}
