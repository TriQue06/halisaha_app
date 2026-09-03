import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Kayıt sırasında e-postaya gönderilen doğrulama kodunun girildiği ekran.
///
/// Kod doğrulanınca hesap onaylanır ve oturum açılır; [AuthGate] devralıp
/// kullanıcıyı ana ekrana geçirir. Kayıt bu adım tamamlanmadan bitmez.
class EmailOtpScreen extends ConsumerStatefulWidget {
  const EmailOtpScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isBusy = false;
  String? _error;

  /// Yeni kod isteyebilmek için beklenecek süre (saniye).
  int _resendCooldown = _resendSeconds;

  /// Kodun geçerliliğinin bitmesine kalan süre (saniye).
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
      await ref.read(authControllerProvider).verifyEmailOtp(
            email: widget.email,
            token: code,
          );
      // Oturum açıldı; giriş ekranına kadar olan yığını temizle.
      if (mounted) Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
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

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authControllerProvider).resendEmailOtp(widget.email);
      _codeController.clear();
      _startTimers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni kod gönderildi. Önceki kod geçersiz oldu.'),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = turkishAuthError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isExpired = _validitySeconds == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('E-postanı doğrula')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.mark_email_unread_outlined,
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
                  text: '${AppConfig.otpLength} haneli doğrulama kodunu ',
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
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
                  if (value.length == AppConfig.otpLength) _verify();
                },
              ),
              const SizedBox(height: 10),

              // --- Geçerlilik sayacı ---------------------------------
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
                onPressed: (_isBusy || isExpired) ? null : _verify,
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
                    : const Text('Doğrula ve Kaydı Tamamla'),
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
          ),
        ),
      ),
    );
  }
}
