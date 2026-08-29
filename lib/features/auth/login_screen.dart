import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../state/auth_controller.dart';
import 'phone_otp_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_widgets.dart';

/// Giriş ekranı — üç yöntem bir arada.
///
/// Sekmeler: **E-posta** (şifreyle) ve **Telefon** (SMS kodu).
/// Altta her iki sekmede de ortak Google butonu.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _isBusy = false;
  bool _isGoogleBusy = false;
  String? _error;

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
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

  Future<void> _sendPhoneCode() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    final String phone = _phoneController.text;

    try {
      await ref.read(authControllerProvider).sendPhoneOtp(phone);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhoneOtpScreen(phone: AuthController.normalizePhone(phone)),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email adresine sıfırlama bağlantısı gönderildi.')),
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

              // --- Yöntem sekmeleri --------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (_) => _setError(null),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    tabs: const <Widget>[
                      Tab(text: 'E-posta'),
                      Tab(text: 'Telefon'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: AuthErrorBox(message: _error!),
                ),

              // --- Sekme içerikleri --------------------------------
              AnimatedBuilder(
                animation: _tabController,
                builder: (BuildContext context, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _tabController.index == 0 ? _emailForm() : _phoneForm(),
                  );
                },
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

  Widget _phoneForm() {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const <String>[AutofillHints.telephoneNumber],
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(14),
            ],
            onFieldSubmitted: (_) => _sendPhoneCode(),
            decoration: const InputDecoration(
              labelText: 'Telefon numarası',
              hintText: '532 111 22 33',
              prefixText: '+90 ',
              prefixIcon: Icon(Icons.smartphone_rounded),
            ),
            validator: (String? value) {
              final String digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              // Baştaki 0 ile veya 0'sız yazılabilir.
              final String core = digits.startsWith('0') ? digits.substring(1) : digits;
              if (core.length != 10) return '10 haneli numaranı gir (5XX XXX XX XX).';
              if (!core.startsWith('5')) return 'Cep telefonu numarası 5 ile başlamalı.';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Numarana 6 haneli bir doğrulama kodu göndereceğiz. '
            'Kayıtlı değilsen hesabın otomatik oluşturulur.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isBusy ? null : _sendPhoneCode,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Kod Gönder'),
          ),
        ],
      ),
    );
  }
}
