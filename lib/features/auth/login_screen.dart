import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../state/auth_controller.dart';
import 'reset_password_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_widgets.dart';

/// Giriş ekranı — iki yöntem: e-posta + şifre ve Google.
///
/// Telefonla giriş kaldırıldı: Türkiye'ye A2P SMS için Twilio'da
/// alfanümerik gönderici adı ön kaydı gerekiyor. Telefon artık yalnızca
/// takım/kaleci iletişim alanı.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isBusy = false;
  bool _isGoogleBusy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setError(Object? error) {
    if (!mounted) return;
    setState(() => _error = error == null ? null : turkishAuthError(error));
  }

  // -------------------------------------------------------------------
  // Aksiyonlar
  // -------------------------------------------------------------------

  Future<void> _signInWithEmail() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
      // Başarılıysa AuthGate oturumu görüp otomatik yönlendirir.
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleBusy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).signInWithGoogle();
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) setState(() => _isGoogleBusy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setError('Önce e-posta adresini gir, sonra sıfırlama isteyebilirsin.');
      return;
    }

    try {
      await ref.read(authControllerProvider).sendPasswordReset(email);
      if (!mounted) return;
      // Kod ekranına geç: akış uygulama içinde tamamlanıyor.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ResetPasswordScreen(email: email)),
      );
    } catch (error) {
      _setError(error);
    }
  }

  // -------------------------------------------------------------------
  // Arayüz
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AuthHeader(
                title: 'Tekrar hoş geldin',
                subtitle: 'Rakibini bul, sahaya çık.',
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: AuthErrorBox(message: _error!),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _emailForm(),
              ),

              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AuthDivider(),
              ),
              const SizedBox(height: 16),

              // --- Google ------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppConfig.isGoogleSignInConfigured
                    ? GoogleSignInButton(
                        onPressed: _isBusy ? null : _signInWithGoogle,
                        isLoading: _isGoogleBusy,
                      )
                    : Text(
                        'Google girişi henüz yapılandırılmadı '
                        '(AppConfig.googleWebClientId boş).',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
              ),
              const SizedBox(height: 26),

              // --- Kayıt bağlantısı --------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Hesabın yok mu?',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                    ),
                    child: const Text('Kayıt ol'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (String? value) {
              final String v = value?.trim() ?? '';
              if (v.isEmpty) return 'E-posta adresini gir.';
              if (!v.contains('@') || !v.contains('.')) return 'Geçerli bir e-posta gir.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const <String>[AutofillHints.password],
            onFieldSubmitted: (_) => _signInWithEmail(),
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (String? value) =>
                (value?.isEmpty ?? true) ? 'Şifreni gir.' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: const Text('Şifremi unuttum'),
            ),
          ),
          FilledButton(
            onPressed: _isBusy ? null : _signInWithEmail,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

}
