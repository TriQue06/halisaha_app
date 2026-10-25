import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/splash/app_bootstrap.dart';
import 'state/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Hazırlık (Supabase vb.) artık burada beklenmiyor: arayüz hemen açılır
  // ve açılış animasyonu oynarken [_initializeServices] paralel çalışır.
  runApp(const ProviderScope(child: JaponKaleApp()));
}

bool _supabaseInitialized = false;

/// Uygulamanın kullanılabilmesi için gereken hazırlık.
///
/// [AppBootstrap] bunu açılış animasyonuyla aynı anda çalıştırır ve bitene
/// kadar [AuthGate]'i göstermez; Supabase'e dokunan her şey bundan sonra.
Future<void> _initializeServices() async {
  // Türkçe tarih/ay isimleri için yerelleştirme verisini yükle.
  await initializeDateFormatting('tr_TR');

  // "Tekrar dene"de ikinci kez başlatılmasın. Kendi bayrağımızı tutuyoruz:
  // Supabase.instance'ın "başlatılmadı" kontrolü yalnızca bir assert ve
  // release derlemesinde hiç çalışmıyor. Ona güvenildiğinde release'de
  // Supabase hiç başlatılmıyor, uygulama gri ekranda kalıyordu.
  if (!_supabaseInitialized) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    _supabaseInitialized = true;
  }

  // Web sürümünde push bildirimi yok (web implementasyonu kurulu değil).
  // Beklenmiyor: ilk açılıştaki bildirim izni sorusu cevaplanana kadar
  // uygulama açılışta takılı kalmasın. Kendi içinde hataları yakalıyor.
  if (!kIsWeb) unawaited(PushService.initialize());
}

class JaponKaleApp extends ConsumerWidget {
  const JaponKaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Japon Kale',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const <Locale>[Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Ayarlardaki yazı boyutu, telefonun erişilebilirlik yazı boyutunun
      // üzerine çarpan olarak uygulanır (önceden sistem ayarını eziyordu).
      // Düzen bozulmasın diye toplam 0.8 - 2.0 aralığında tutulur.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        final double system = media.textScaler.scale(14) / 14;
        final double scale = (system * settings.textScale).clamp(0.8, 2.0);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      // Açılış animasyonu + hazırlık, ardından oturum durumuna göre
      // giriş / profil tamamlama / ana ekran.
      home: const AppBootstrap(
        initialize: _initializeServices,
        child: AuthGate(),
      ),
    );
  }
}
