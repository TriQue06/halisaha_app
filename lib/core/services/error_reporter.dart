import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Yakalanmayan hataları Supabase'deki `client_errors` tablosuna yazar.
///
/// Crashlytics yerine hafif bir çözüm: ek yerel paket yok, Dart tarafındaki
/// hataların (Flutter çerçevesi + async hatalar) mesajı ve yığın izi kaydedilir.
/// SQL Editor'den bakılır:
///   select * from public.client_errors order by created_at desc limit 50;
///
/// Sınırlar: oturum açık değilse yazılmaz; aynı hata bir oturumda bir kez,
/// toplamda en fazla [_maxPerSession] kayıt. Debug derlemede hiç yazmaz.
abstract final class ErrorReporter {
  static const int _maxPerSession = 15;
  static final Set<String> _seen = <String>{};
  static String? _version;

  /// `main()`'de, `runApp`'ten önce çağrılır.
  static void install() {
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previous?.call(details);
      unawaited(report(details.exception, details.stack, fatal: false));
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(report(error, stack, fatal: true));
      // false: sistemin varsayılan davranışı da çalışsın (konsola yazar).
      return false;
    };
  }

  /// Bir hatayı kaydeder. Asla hata fırlatmaz.
  static Future<void> report(Object error, StackTrace? stack, {bool fatal = false}) async {
    if (kDebugMode || kIsWeb) return;
    if (_isNoise(error)) return;

    final String message = error.toString();
    final String key = message.length > 160 ? message.substring(0, 160) : message;
    if (_seen.length >= _maxPerSession || !_seen.add(key)) return;

    try {
      final SupabaseClient client = Supabase.instance.client;
      if (client.auth.currentSession == null) return;

      _version ??= await () async {
        final PackageInfo info = await PackageInfo.fromPlatform();
        return '${info.version}+${info.buildNumber}';
      }();

      final String trace = stack?.toString() ?? '';
      await client.rpc<dynamic>('log_client_error', params: <String, dynamic>{
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'p_app_version': _version,
        'p_message': message.length > 1000 ? message.substring(0, 1000) : message,
        'p_stack': trace.length > 4000 ? trace.substring(0, 4000) : trace,
        'p_fatal': fatal,
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Kayıt da başarısız olduysa yapacak bir şey yok.
    }
  }

  /// Bağlantı kopması gibi hatalar uygulama hatası değil; kaydı doldurmasın.
  static bool _isNoise(Object error) {
    final String s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection closed') ||
        s.contains('connection reset') ||
        s.contains('network is unreachable') ||
        s.contains('timeoutexception') ||
        s.contains('handshakeexception') ||
        s.contains('clientexception');
  }
}
