import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/services/ad_service.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih/ay isimleri için yerelleştirme verisini yükle.
  await initializeDateFormatting('tr_TR');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  // Push bildirimleri. Kendi içinde hata yakalıyor: Firebase kurulmamış bir
  // ortamda bile uygulama normal açılmaya devam eder.
  await PushService.initialize();

  // Reklamlar. Başarısız olursa uygulama reklamsız çalışmaya devam eder.
  await AdService.initialize();

  runApp(const ProviderScope(child: JaponKaleApp()));
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
      // Ayarlardaki yazı boyutu slider'ı tüm uygulamaya buradan yansır.
      builder: (BuildContext context, Widget? child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: settings.textScale,
          maxScaleFactor: settings.textScale,
          child: child ?? const SizedBox.shrink(),
        );
      },
      // Oturum durumuna göre giriş / profil tamamlama / ana ekran.
      home: const AuthGate(),
    );
  }
}
