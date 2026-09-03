import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../state/auth_controller.dart';
import 'email_otp_screen.dart';
import 'widgets/auth_widgets.dart';

/// E-posta + şifre ile kayıt ekranı.
///
/// Ad, soyad ve doğum tarihi burada toplanıp `signUp` çağrısında metadata
/// olarak gönderilir; `handle_new_user` trigger'ı bunları `profiles`
/// tablosuna yazar. Böylece kullanıcı profil tamamlama ekranını görmez.
///
/// Telefon burada İSTENMEZ — yalnızca takım kurarken ve kaleci profilinde,
/// gerçekten gerektiği anda sorulur.
///
/// Kayıt bu ekranda bitmez: `signUp` sonrası e-postaya 6 haneli kod gider
/// ve kullanıcı [EmailOtpScreen] üzerinde kodu girerek kaydı tamamlar.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();

  DateTime? _birthDate;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isBusy = false;
  bool _acceptedTerms = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 90),
      // En az 13 yaşında olmalı.
      lastDate: DateTime(now.year - 13, now.month, now.day),
      locale: const Locale('tr', 'TR'),
      helpText: 'Doğum tarihini seç',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_birthDate == null) {
      setState(() => _error = 'Doğum tarihini seç.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = 'Devam etmek için koşulları kabul etmelisin.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final AuthResponse response =
          await ref.read(authControllerProvider).signUpWithEmail(
                email: _emailController.text,
                password: _passwordController.text,
                firstName: _firstNameController.text,
                lastName: _lastNameController.text,
                birthDate: _birthDate!,
              );

      if (!mounted) return;

      if (response.session != null) {
        // Supabase'de e-posta doğrulaması kapalıysa oturum hemen açılır.
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        return;
      }

      // Normal akış: e-postaya kod gitti, kayıt kod girilince tamamlanacak.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EmailOtpScreen(email: _emailController.text.trim()),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = turkishAuthError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: <Widget>[
              Text(
                'Aramıza katıl',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Takımını kur, rakip bul, kaleci ara.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // --- Ad / Soyad ---------------------------------------
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Ad'),
                      validator: (String? v) =>
                          (v?.trim().length ?? 0) < 2 ? 'Adını gir.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Soyad'),
                      validator: (String? v) =>
                          (v?.trim().length ?? 0) < 2 ? 'Soyadını gir.' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- Doğum tarihi -------------------------------------
              InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Doğum tarihi',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    errorText: _error == 'Doğum tarihini seç.' ? _error : null,
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Seç'
                        : DateFormat('d MMMM yyyy', 'tr_TR').format(_birthDate!),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _birthDate == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const SizedBox(height: 20),
              const AuthDivider(label: 'giriş bilgileri'),
              const SizedBox(height: 20),

              // --- E-posta ------------------------------------------
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (String? value) {
                  final String v = value?.trim() ?? '';
                  if (v.isEmpty) return 'E-posta adresini gir.';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Geçerli bir e-posta gir.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // --- Şifre + şifre onay -------------------------------
              PasswordFields(
                passwordController: _passwordController,
                confirmController: _passwordConfirmController,
                obscurePassword: _obscurePassword,
                obscureConfirm: _obscurePasswordConfirm,
                onTogglePassword: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onToggleConfirm: () => setState(
                    () => _obscurePasswordConfirm = !_obscurePasswordConfirm),
              ),
              const SizedBox(height: 12),

              // --- Koşullar -----------------------------------------
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: (bool? v) => setState(() => _acceptedTerms = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Kullanım koşullarını ve gizlilik politikasını kabul ediyorum.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),

              if (_error != null && _error != 'Doğum tarihini seç.') ...<Widget>[
                AuthErrorBox(message: _error!),
                const SizedBox(height: 16),
              ],

              FilledButton(
                onPressed: _isBusy ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Hesabımı Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
