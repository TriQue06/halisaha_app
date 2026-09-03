import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Şifre sıfırlama: kod doğrulama + yeni şifre belirleme.
///
/// Supabase'in varsayılan akışı e-postaya bir **bağlantı** gönderir; o
/// bağlantı tarayıcıda açılır ve uygulamaya dönmek için derin bağlantı
/// kurulumu gerekir. Bunun yerine e-postadaki **kodu** kullanıyoruz:
/// kod doğrulanınca geçici oturum açılır, kullanıcı yeni şifresini girer.
///
/// Birinci adımın arayüzü [EmailOtpScreen] ile birebir aynı; yalnızca
/// metinler şifre sıfırlamaya göre değişir.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  /// Kod doğrulandıktan sonra ikinci adıma geçilir.
  bool _codeVerified = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isBusy = false;
  String? _error;

  int _resendCooldown = _resendSeconds;
  int _validitySeconds = _validitySecondsTotal;
  Timer? _timer;

  static const int _resendSeconds = 30;
  static const int _validitySecondsTotal = 5 * 60;

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _startTimers() {
    _timer?.cancel();
    setState(() {
      _resendCooldown = _resendSeconds;
      _validitySeconds = _validitySecondsTotal;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        if (_resendCooldown > 0) _resendCooldown--;
        if (_validitySeconds > 0) _validitySeconds--;
      });
      if (_resendCooldown == 0 && _validitySeconds == 0) timer.cancel();
    });
  }

  String get _validityLabel {
    final int m = _validitySeconds ~/ 60;
    final int s = _validitySeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyCode() async {
    final String code = _codeController.text.trim();
    if (code.length != AppConfig.otpLength) {
      setState(() => _error = '${AppConfig.otpLength} haneli kodu gir.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).verifyPasswordResetOtp(
            email: widget.email,
            token: code,
          );
      if (mounted) {
        // Kod doğrulandı; sayaç artık gereksiz.
        _timer?.cancel();
        setState(() => _codeVerified = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = turkishAuthError(error);
          _codeController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _savePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).updatePassword(_passwordController.text);
      if (!mounted) return;
      // Kod doğrulaması oturumu zaten açtı; kullanıcı giriş yapmış durumda.
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifren güncellendi.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = turkishAuthError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authControllerProvider).sendPasswordReset(widget.email);
      _codeController.clear();
      _startTimers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni kod gönderildi. Önceki kod geçersiz oldu.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = turkishAuthError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_codeVerified ? 'Yeni şifre' : 'Şifreni sıfırla'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: _codeVerified ? _passwordStep(theme) : _codeStep(theme),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 1. adım: kod  (düzen EmailOtpScreen ile aynı)
  // -------------------------------------------------------------------
  Widget _codeStep(ThemeData theme) {
    final bool isExpired = _validitySeconds == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.lock_reset_rounded, size: 46, color: theme.colorScheme.primary),
        const SizedBox(height: 18),
        Text(
          'Kodu gir',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: '${AppConfig.otpLength} haneli şifre sıfırlama kodunu ',
            children: <InlineSpan>[
              TextSpan(
                text: widget.email,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: ' adresine gönderdik.'),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 28),

        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          enabled: !isExpired,
          maxLength: AppConfig.otpLength,
          autofillHints: const <String>[AutofillHints.oneTimeCode],
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: TextStyle(letterSpacing: 10, fontSize: 24),
          ),
          onChanged: (String value) {
            if (_error != null) setState(() => _error = null);
            // Kod tamamlanınca otomatik doğrula.
            if (value.length == AppConfig.otpLength) _verifyCode();
          },
        ),
        const SizedBox(height: 10),

        // --- Geçerlilik sayacı -----------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isExpired ? Icons.timer_off_rounded : Icons.timer_outlined,
              size: 15,
              color: isExpired
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              isExpired
                  ? 'Kodun süresi doldu, yeni kod al'
                  : 'Kod $_validityLabel süre sonra geçersiz olacak',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isExpired
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_error != null) ...<Widget>[
          AuthErrorBox(message: _error!),
          const SizedBox(height: 16),
        ],

        FilledButton(
          onPressed: (_isBusy || isExpired) ? null : _verifyCode,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: _isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kodu Doğrula'),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: _resendCooldown > 0 ? null : _resend,
          child: Text(
            _resendCooldown > 0
                ? 'Yeni kod gönder ($_resendCooldown sn)'
                : 'Yeni kod gönder',
          ),
        ),

        const SizedBox(height: 4),
        Text(
          'Kod gelmediyse spam klasörünü kontrol et.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // 2. adım: yeni şifre (şifre + şifre onay)
  // -------------------------------------------------------------------
  Widget _passwordStep(ThemeData theme) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.check_circle_rounded, size: 46, color: theme.colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            'Yeni şifreni belirle',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Kod doğrulandı. Yeni şifreni girdikten sonra giriş yapmış olacaksın.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),

          PasswordFields(
            passwordController: _passwordController,
            confirmController: _passwordConfirmController,
            obscurePassword: _obscurePassword,
            obscureConfirm: _obscurePasswordConfirm,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onToggleConfirm: () =>
                setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
            passwordLabel: 'Yeni şifre',
            confirmLabel: 'Yeni şifre (tekrar)',
            onConfirmSubmitted: (_) => _savePassword(),
          ),
          const SizedBox(height: 16),

          if (_error != null) ...<Widget>[
            AuthErrorBox(message: _error!),
            const SizedBox(height: 16),
          ],

          FilledButton(
            onPressed: _isBusy ? null : _savePassword,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Şifreyi Kaydet'),
          ),
        ],
      ),
    );
  }
}
