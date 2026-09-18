import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web sayfasını (gizlilik politikası vb.) cihazın tarayıcısında açar.
///
/// Açılamazsa adresi SnackBar'da gösterir; kullanıcı en azından
/// elle kopyalayabilsin.
Future<void> openExternalLink(BuildContext context, String url) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  bool opened = false;
  try {
    opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text('Sayfa açılamadı: $url')));
  }
}
