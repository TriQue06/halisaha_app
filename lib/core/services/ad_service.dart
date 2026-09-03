import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob reklam kimlikleri ve başlatma.
///
/// **Yayına çıkmadan önce** [_androidBannerReal] değerini AdMob panelinden
/// aldığın gerçek reklam birimi kimliğiyle değiştir ve
/// `AndroidManifest.xml` içindeki `APPLICATION_ID` meta-data'sını da gerçek
/// uygulama kimliğiyle güncelle. Test kimlikleriyle gerçek reklam gelmez;
/// gerçek kimlikleri geliştirme sırasında kullanmak ise AdMob hesabının
/// kapatılmasına yol açar (geçersiz tıklama).
class AdService {
  AdService._();

  /// Google'ın resmî test banner birimleri.
  static const String _androidBannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';

  /// Gerçek birimler — AdMob'dan alınınca doldurulacak.
  static const String _androidBannerReal = '';
  static const String _iosBannerReal = '';

  /// Sürüm derlemesinde gerçek kimlik tanımlıysa onu, aksi hâlde testi kullan.
  static String get bannerUnitId {
    final String real = Platform.isIOS ? _iosBannerReal : _androidBannerReal;
    if (kReleaseMode && real.isNotEmpty) return real;
    return Platform.isIOS ? _iosBannerTest : _androidBannerTest;
  }

  /// Gerçek reklam birimi tanımlanmadıysa true — arayüz reklam yerine
  /// hiçbir şey göstermek yerine test reklamı gösterir, ama bu bayrak
  /// yayın öncesi kontrol için kullanılabilir.
  static bool get usingTestAds =>
      (Platform.isIOS ? _iosBannerReal : _androidBannerReal).isEmpty;

  static bool _initialized = false;

  /// `main()` içinde bir kez çağrılır. Hata durumunda uygulama etkilenmez.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
    } catch (error) {
      debugPrint('AdMob başlatılamadı: $error');
    }
  }
}
