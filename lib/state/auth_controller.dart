import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/services/push_service.dart';

/// Supabase istemcisi.
final Provider<SupabaseClient> supabaseProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);

/// Oturum durumu akışı. Giriş/çıkış olduğunda tüm dinleyiciler tetiklenir.
final StreamProvider<AuthState> authStateProvider =
    StreamProvider<AuthState>((Ref ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// Mevcut oturum (yoksa null). `authStateProvider`'ı izlediği için
/// giriş/çıkışta kendiliğinden yeniden hesaplanır.
final Provider<Session?> sessionProvider = Provider<Session?>((Ref ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentSession;
});

/// Giriş yapmış kullanıcının profil satırı.
///
/// `null` dönerse profil henüz oluşmamıştır (trigger gecikmesi);
/// alanları eksikse "Profilini Tamamla" ekranı gösterilir.
final FutureProvider<Map<String, dynamic>?> myProfileProvider =
    FutureProvider<Map<String, dynamic>?>((Ref ref) async {
  final Session? session = ref.watch(sessionProvider);
  if (session == null) return null;

  final SupabaseClient client = ref.watch(supabaseProvider);
  return client
      .from('profiles')
      .select()
      .eq('id', session.user.id)
      .maybeSingle();
});

/// Profil, takım kurmaya ve kaleci profiline yetecek kadar dolu mu?
///
/// Google ve telefon girişinde ad/soyad/doğum tarihi/telefon eksik gelir;
/// bu yüzden istemci tarafında da aynı kontrolü yapıyoruz
/// (veritabanındaki `is_profile_complete()` ile aynı kurallar).
bool isProfileComplete(Map<String, dynamic>? profile) {
  if (profile == null) return false;
  bool filled(String key) => (profile[key] as String?)?.trim().isNotEmpty ?? false;
  // Telefon burada aranmaz: takım kurarken ve kaleci profilinde ayrıca
  // isteniyor. Veritabanındaki is_profile_complete() ile aynı kurallar.
  return filled('first_name') && filled('last_name') && profile['birth_date'] != null;
}

/// Kimlik doğrulama işlemleri.
///
/// Üç yöntem: e-posta+şifre, telefon (SMS OTP) ve Google.
/// Hepsi aynı `auth.users` tablosuna yazar; `handle_new_user` trigger'ı
/// elindeki metadata ile profili oluşturur.
class AuthController {
  AuthController(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  // -------------------------------------------------------------------
  // E-POSTA + ŞİFRE
  // -------------------------------------------------------------------

  /// Kayıt. Ad, soyad, doğum tarihi ve telefon metadata olarak gönderilir;
  /// trigger bunları doğrudan `profiles` tablosuna yazar.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'birth_date': _isoDate(birthDate),
      },
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Şifre sıfırlama kodu gönderir.
  ///
  /// Bağlantı yerine kod kullanıyoruz: bağlantı tarayıcıda açılır ve
  /// uygulamaya geri dönmek için derin bağlantı (deep link) kurulumu
  /// gerekir. Kod ile akış tamamen uygulama içinde kapanıyor.
  Future<void> sendPasswordReset(String email) {
    return _auth.resetPasswordForEmail(email.trim());
  }

  /// Sıfırlama kodunu doğrular; başarılıysa geçici bir oturum açılır.
  Future<AuthResponse> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim(),
      token: token.trim(),
    );
  }

  /// Kod doğrulandıktan sonra yeni şifreyi kaydeder.
  Future<void> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  // -------------------------------------------------------------------
  // E-POSTA DOĞRULAMA KODU (6 hane)
  // -------------------------------------------------------------------

  /// Kayıt sırasında gönderilen kodu doğrular ve oturumu açar.
  ///
  /// `signUp` çağrısından sonra Supabase "Confirm signup" şablonundaki
  /// {{ .Token }} kodunu e-postayla gönderir. Bu kod doğrulanınca hesap
  /// onaylanır ve kullanıcı doğrudan giriş yapmış olur.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: token.trim(),
    );
  }

  /// Yeni kod gönderir. Yeni kod üretildiği anda önceki kod geçersiz olur.
  Future<void> resendEmailOtp(String email) {
    return _auth.resend(type: OtpType.signup, email: email.trim());
  }

  // -------------------------------------------------------------------
  // GOOGLE
  // -------------------------------------------------------------------

  /// Google ile giriş.
  ///
  /// Native akış: google_sign_in ile idToken alınır, Supabase'e
  /// `signInWithIdToken` ile verilir. Tarayıcı yönlendirmesi yoktur.
  ///
  /// Kullanıcı iptal ederse `null` döner (hata değil).
  Future<AuthResponse?> signInWithGoogle() async {
    if (!AppConfig.isGoogleSignInConfigured) {
      throw const AuthException(
        'Google girişi yapılandırılmamış: AppConfig.googleWebClientId boş.',
      );
    }

    final GoogleSignIn googleSignIn = GoogleSignIn(
      // serverClientId = Web client ID. Supabase idToken'ı bununla doğrular.
      serverClientId: AppConfig.googleWebClientId,
      scopes: <String>['email', 'profile'],
    );

    // Önceki oturumu temizle ki hesap seçme ekranı her seferinde çıksın.
    await googleSignIn.signOut();

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) return null; // kullanıcı vazgeçti

    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null) {
      throw const AuthException(
        'Google kimlik doğrulaması başarısız: idToken alınamadı. '
        'Web client ID ve SHA-1 parmak izini kontrol edin.',
      );
    }

    return _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
  }

  // -------------------------------------------------------------------
  // ORTAK
  // -------------------------------------------------------------------

  Future<void> signOut() async {
    // Önce token'ı sil: çıkıştan sonra RLS bu satıra erişimi engeller ve
    // cihaz eski hesabın bildirimlerini almaya devam ederdi.
    await PushService.unregister();
    await _auth.signOut();
  }

  /// Google veya telefonla girenlerin eksik profilini tamamlar.
  Future<void> completeProfile({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    String? phone,
    String? district,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadı.');
    }

    await _client.from('profiles').update(<String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'birth_date': _isoDate(birthDate),
      if (phone != null && phone.trim().isNotEmpty) 'phone': normalizePhone(phone),
      if (district != null) 'district': district,
    }).eq('id', user.id);
  }

  /// '0532 111 22 33' / '532 111 22 33' -> '+905321112233'
  ///
  /// Supabase telefon girişi E.164 biçimi bekler; kullanıcının nasıl
  /// yazdığından bağımsız olarak tek biçime indiriyoruz.
  static String normalizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('00')) return '+${digits.substring(2)}';
    if (digits.startsWith('90') && digits.length >= 12) return '+$digits';
    if (digits.startsWith('0')) digits = digits.substring(1);

    return '${AppConfig.phoneCountryCode}$digits';
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final Provider<AuthController> authControllerProvider =
    Provider<AuthController>((Ref ref) => AuthController(ref.watch(supabaseProvider)));
