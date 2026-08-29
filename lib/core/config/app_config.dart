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
  static bool get isGoogleSignInConfigured => googleWebClientId.isNotEmpty;

  // -------------------------------------------------------------------
  // Telefon
  // -------------------------------------------------------------------
  /// Türkiye ülke kodu. Kullanıcı '5321112233' girer, '+905321112233' olur.
  static const String phoneCountryCode = '+90';

  /// SMS ile gelen doğrulama kodunun hane sayısı (Supabase varsayılanı 6).
  static const int otpLength = 6;
}
