import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/theme_selector.dart';

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
              // Uygulama logosu (launcher ikonuyla aynı görsel).
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/logo/japonkale.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Japon Kale',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              // Tema seçimi girişten önce de yapılabilsin.
              const ThemeSelector(compact: true),
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

/// Şifre + şifre onay kutusu ikilisi.
///
/// Kayıt ve şifre sıfırlama ekranlarının ikisinde de aynı doğrulama
/// kurallarının geçerli olması için tek yerde tutuluyor: en az 6 karakter
/// ve iki alanın birebir eşleşmesi.
class PasswordFields extends StatelessWidget {
  const PasswordFields({
    super.key,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    this.passwordLabel = 'Şifre',
    this.confirmLabel = 'Şifre (tekrar)',
    this.onConfirmSubmitted,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final String passwordLabel;
  final String confirmLabel;
  final ValueChanged<String>? onConfirmSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          autofillHints: const <String>[AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: passwordLabel,
            helperText: 'En az 6 karakter',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (String? v) =>
              (v?.length ?? 0) < 6 ? 'Şifre en az 6 karakter olmalı.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: confirmController,
          obscureText: obscureConfirm,
          autofillHints: const <String>[AutofillHints.newPassword],
          onFieldSubmitted: onConfirmSubmitted,
          decoration: InputDecoration(
            labelText: confirmLabel,
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: IconButton(
              onPressed: onToggleConfirm,
              icon: Icon(
                obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (String? v) {
            if ((v ?? '').isEmpty) return 'Şifreni tekrar gir.';
            if (v != passwordController.text) return 'Şifreler eşleşmiyor.';
            return null;
          },
        ),
      ],
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
  // SMTP tarafı: Supabase e-postayı gönderemedi.
  // En sık sebepleri: özel SMTP hiç kurulmamış (yerleşik servis yalnızca
  // proje ekibine gönderir) ya da sağlayıcı alıcıyı reddetti (Resend'in
  // onboarding@resend.dev adresi sadece hesap sahibine gönderebilir).
  if (raw.contains('error sending confirmation email') ||
      raw.contains('error sending recovery email') ||
      raw.contains('error sending email') ||
      raw.contains('unexpected_failure')) {
    return 'Doğrulama e-postası gönderilemedi. Bu bir uygulama hatası değil, '
        'e-posta servisi ayarından kaynaklanıyor. Supabase → Project Settings '
        '→ Authentication → SMTP ayarlarını kontrol et.';
  }
  if (raw.contains('email address not authorized')) {
    return 'Bu adrese e-posta gönderme yetkisi yok. Supabase varsayılan '
        'e-posta servisi yalnızca proje ekibine gönderir; özel bir SMTP '
        'sağlayıcı bağlaman gerekiyor.';
  }
  if (raw.contains('over_email_send_rate_limit') || raw.contains('rate limit')) {
    return 'Çok fazla deneme yaptın. Biraz bekleyip tekrar dene.';
  }
  if (raw.contains('socketexception') || raw.contains('failed host lookup')) {
    return 'İnternet bağlantısı kurulamadı.';
  }
  return 'Bir hata oluştu: $error';
}
