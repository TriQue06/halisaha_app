import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/legal_consent.dart';
import '../../state/auth_controller.dart';
import '../settings/delete_account_dialog.dart';
import '../shell/main_shell.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';

/// Uygulamanın giriş kapısı.
///
/// Üç durum:
///   1. Oturum yok            -> [LoginScreen]
///   2. Oturum var, profilde ad-soyad yok -> [CompleteProfileScreen]
///   3. Oturum var, ad-soyad var          -> [MainShell]
///
/// Apple ve Google ad-soyadı kendileri veriyor; o kullanıcılar hiçbir ek
/// ekran görmeden ana sayfaya düşer (App Store Guideline 4 - Design).
/// Eksik doğum tarihi veya telefon burada yol kesmez: profil sekmesindeki
/// "Profilini tamamla" kartından doldurulur.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session? session = ref.watch(sessionProvider);

    if (session == null) return const LoginScreen();

    final AsyncValue<Map<String, dynamic>?> profile = ref.watch(myProfileProvider);

    return profile.when(
      loading: () => const _AuthLoading(),
      error: (Object error, StackTrace stack) => _AuthError(
        message: error.toString(),
        onRetry: () => ref.invalidate(myProfileProvider),
        onSignOut: () => ref.read(authControllerProvider).signOut(),
      ),
      data: (Map<String, dynamic>? data) {
        // Trigger profili henüz oluşturmadıysa kısa bir yarış olabilir;
        // eksik profil ekranı zaten bu durumu da karşılıyor.
        // Panelden banlanan hesap: uygulama kullanılamaz.
        if (data?['is_banned'] == true) {
          return _BannedScreen(
            onSignOut: () => ref.read(authControllerProvider).signOut(),
          );
        }
        // Giriş öncesi kutuda kabul edilen koşulları profile yaz (arka planda).
        if (data != null) {
          TermsAcceptance.syncToServer(ref.read(supabaseProvider), data);
        }
        // Apple ile girene ad-soyad ASLA sorulmaz (Guideline 4); eksikse
        // profil sekmesindeki isteğe bağlı karttan eklenir.
        if (!isProfileComplete(data) && !isAppleUser(session.user)) {
          return const CompleteProfileScreen();
        }
        return const MainShell();
      },
    );
  }
}

/// Topluluk kurallarını ihlal ettiği için askıya alınan hesap.
class _BannedScreen extends StatelessWidget {
  const _BannedScreen({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.gpp_bad_outlined, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 14),
              Text(
                'Hesabın askıya alındı',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Topluluk kurallarını ihlal ettiği için hesabın kullanıma '
                'kapatıldı. İtiraz için ${AppConfig.supportEmail} adresine yazabilirsin.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onSignOut, child: const Text('Çıkış Yap')),
              const SizedBox(height: 8),
              // Askıya alınan kullanıcı da hesabını ve verisini silebilmeli.
              TextButton(
                onPressed: () => showDeleteAccountDialog(context),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: const Text('Hesabımı sil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_off_rounded, size: 44, color: theme.colorScheme.error),
              const SizedBox(height: 14),
              Text(
                'Profil bilgilerin alınamadı',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              // Ham hata metni (İngilizce, teknik) kullanıcıya gösterilmez.
              Text(
                'Sunucuya şu an ulaşılamıyor. İnternet bağlantını kontrol '
                'edip tekrar dene.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tekrar Dene'),
              ),
              TextButton(onPressed: onSignOut, child: const Text('Çıkış Yap')),
            ],
          ),
        ),
      ),
    );
  }
}
