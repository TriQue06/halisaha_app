import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// SMS ile gelen doğrulama kodunun girildiği ekran.
///
/// Kod doğrulanınca Supabase oturumu açar; [AuthGate] bunu görüp
/// kullanıcıyı profil tamamlama veya ana ekrana yönlendirir.
class PhoneOtpScreen extends ConsumerStatefulWidget {
  const PhoneOtpScreen({super.key, required this.phone});

  /// E.164 biçiminde numara (+905321112233).
  final String phone;

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isBusy = false;
  String? _error;

  /// Yeniden kod gönderme için bekleme süresi (saniye).
  int _resendCooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
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
      await ref.read(authControllerProvider).verifyPhoneOtp(
            phone: widget.phone,
            token: code,
          );
      // Oturum açıldı; giriş ekranına kadar olan yığını temizle.
      if (mounted) Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    } catch (error) {
      if (mounted) setState(() => _error = turkishAuthError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authControllerProvider).sendPhoneOtp(widget.phone);
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni kod gönderildi.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = turkishAuthError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Doğrulama')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.sms_outlined,
                size: 46,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Kodu gir',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Doğrulama kodunu ',
                  children: <InlineSpan>[
                    TextSpan(
                      text: widget.phone,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: ' numarasına gönderdik.'),
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
                maxLength: AppConfig.otpLength,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: TextStyle(letterSpacing: 12, fontSize: 26),
                ),
                onChanged: (String value) {
                  if (_error != null) setState(() => _error = null);
                  // Kod tamamlanınca otomatik doğrula.
                  if (value.length == AppConfig.otpLength) _verify();
                },
              ),
              const SizedBox(height: 16),

              if (_error != null) ...<Widget>[
                AuthErrorBox(message: _error!),
                const SizedBox(height: 16),
              ],

              FilledButton(
                onPressed: _isBusy ? null : _verify,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Doğrula ve Giriş Yap'),
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
            ],
          ),
        ),
      ),
    );
  }
}
