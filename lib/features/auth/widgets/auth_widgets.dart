import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Giriş/kayıt ekranlarının ortak yeşil gradyanlı üst başlığı.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[AppColors.darkSurfaceAlt, AppColors.darkBackground]
              : const <Color>[AppColors.primaryGreen, AppColors.deepGreen],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_soccer, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'RakipVar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Google ile giriş butonu (marka rengi yerine nötr, Google yönergelerine uygun).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const _GoogleGlyph(),
      label: const Text('Google ile devam et'),
    );
  }
}

/// Google'ın dört renkli "G" harfi — ağ bağlantısı gerektirmeyen basit çizim.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: <Color>[
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      child: Container(
        width: 13,
        height: 13,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
        ),
        child: const Text(
          'G',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4285F4),
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// "veya" ayıracı.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'veya'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Hata mesajı kutusu.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Supabase hatalarını kullanıcıya gösterilebilir Türkçe metne çevirir.
String turkishAuthError(Object error) {
  final String raw = error.toString().toLowerCase();

  if (raw.contains('invalid login credentials')) {
    return 'E-posta veya şifre hatalı.';
  }
  if (raw.contains('email not confirmed')) {
    return 'E-posta adresin henüz doğrulanmamış. Gelen kutunu kontrol et.';
  }
  if (raw.contains('user already registered') || raw.contains('already been registered')) {
    return 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı dene.';
  }
  if (raw.contains('password should be at least')) {
    return 'Şifre en az 6 karakter olmalı.';
  }
  if (raw.contains('token has expired') || raw.contains('otp_expired')) {
    return 'Doğrulama kodunun süresi doldu. Yeni kod iste.';
  }
  if (raw.contains('invalid token') || raw.contains('otp') && raw.contains('invalid')) {
    return 'Doğrulama kodu hatalı.';
  }
  if (raw.contains('sms') || raw.contains('phone provider')) {
    return 'SMS gönderilemedi. Telefon girişi henüz yapılandırılmamış olabilir.';
  }
  if (raw.contains('over_email_send_rate_limit') || raw.contains('rate limit')) {
    return 'Çok fazla deneme yaptın. Biraz bekleyip tekrar dene.';
  }
  if (raw.contains('socketexception') || raw.contains('failed host lookup')) {
    return 'İnternet bağlantısı kurulamadı.';
  }
  return 'Bir hata oluştu: $error';
}
