import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/auth_controller.dart';
import '../shell/main_shell.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';

/// Uygulamanın giriş kapısı.
///
/// Üç durum:
///   1. Oturum yok            -> [LoginScreen]
///   2. Oturum var, profil eksik -> [CompleteProfileScreen]
///      (Google ve telefon girişinde ad/doğum tarihi/telefon gelmez)
///   3. Oturum var, profil tam   -> [MainShell]
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
        if (!isProfileComplete(data)) return const CompleteProfileScreen();
        return const MainShell();
      },
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
              Text(
                message,
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
