import 'package:flutter/foundation.dart';

/// Uygulama genelindeki yapılandırma sabitleri.
///
/// Buradaki değerlerin hiçbiri gizli değildir; hepsi istemciye gömülmek
/// üzere tasarlanmıştır ve APK'dan çıkarılabilir. Gerçek koruma
/// Supabase'deki RLS politikalarındadır.
///
/// ASLA buraya konmayacaklar: Supabase `service_role` anahtarı,
/// Google OAuth **Client Secret**, Twilio Auth Token.
abstract final class AppConfig {
  // -------------------------------------------------------------------
  // Supabase
  // -------------------------------------------------------------------
  static const String supabaseUrl = 'https://giyazjlrwljsujgczrua.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_pC2I71cFNRVnwzPsw0Ugng_p4wQRXGR';

  // -------------------------------------------------------------------
  // Google Sign-In
  // -------------------------------------------------------------------
  /// Google Cloud Console → APIs & Services → Credentials →
  /// OAuth 2.0 Client IDs → **Web application** tipindeki kaydın ID'si.
  ///
  /// Android tipindeki client ID buraya YAZILMAZ; o yalnızca Supabase
  /// panelindeki "Authorized Client IDs" alanına eklenir.
  ///
  /// Biçim: '1234567890-abc...xyz.apps.googleusercontent.com'
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '31398999123-6uj2lgdi4usgs2vgju5o2gif3k5v6ets.apps.googleusercontent.com',
  );

  /// Google girişi yapılandırılmış mı? Değilse giriş ekranındaki
  /// Google butonu gizlenir (çalışmayan buton göstermek yerine).
  /// Google Cloud → Credentials → **iOS** tipindeki OAuth client ID'si.
  ///
  /// iOS'ta Google hesap ekranını açmak için gerekiyor (Android bunu
  /// SHA-1 ile çözüyor). Codemagic derlemesinde `--dart-define` ile gelir.
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Google girişi bu platformda yapılandırılmış mı? Değilse giriş
  /// ekranındaki Google butonu gizlenir. iOS'ta ayrıca iOS client ID'si
  /// şart: yoksa google_sign_in uygulamayı çökertir.
  static bool get isGoogleSignInConfigured =>
      googleWebClientId.isNotEmpty && (!isIos || googleIosClientId.isNotEmpty);

  // -------------------------------------------------------------------
  // Platform
  // -------------------------------------------------------------------
  static bool get isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static const String bundleId = 'com.japonkale.app';

  // -------------------------------------------------------------------
  // Firebase (yalnızca iOS)
  // -------------------------------------------------------------------
  // Android değerleri google-services.json'dan Gradle eklentisiyle geliyor.
  // iOS'ta aynı işi GoogleService-Info.plist yapardı ama o dosyanın Xcode
  // projesine eklenmesi Mac gerektiriyor; bu yüzden değerleri koddan
  // veriyoruz. Hiçbiri gizli değil (plist de uygulamaya gömülü).
  static const String firebaseIosApiKey =
      String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const String firebaseIosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String firebaseMessagingSenderId = '166383252757';
  static const String firebaseProjectId = 'japon-kale';
  static const String firebaseStorageBucket = 'japon-kale.firebasestorage.app';

  static bool get isFirebaseIosConfigured =>
      firebaseIosApiKey.isNotEmpty && firebaseIosAppId.isNotEmpty;

  // -------------------------------------------------------------------
  // Yasal sayfalar (GitHub Pages)
  // -------------------------------------------------------------------
  /// Play Console ve App Store Connect'e girilen adreslerle AYNI olmalı.
  static const String privacyPolicyUrl =
      'https://trique06.github.io/halisaha_app/gizlilik.html';

  /// Kullanım koşulları (EULA). App Store, hesap açılan ekranlarda bu
  /// metne erişilmesini istiyor.
  static const String termsUrl =
      'https://trique06.github.io/halisaha_app/kullanim-kosullari.html';

  /// Uygulamaya giremeyenler için hesap silme talebi sayfası (Play şartı).
  static const String accountDeletionUrl =
      'https://trique06.github.io/halisaha_app/hesap-silme.html';

  // -------------------------------------------------------------------
  // Telefon
  // -------------------------------------------------------------------
  /// Türkiye ülke kodu. Kullanıcı '5321112233' girer, '+905321112233' olur.
  static const String phoneCountryCode = '+90';

  /// SMS ile gelen doğrulama kodunun hane sayısı (Supabase varsayılanı 6).
  static const int otpLength = 6;
}
