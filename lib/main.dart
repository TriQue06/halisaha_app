import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Türkçe tarih/ay isimleri için yerelleştirme verisini yükle.
  await initializeDateFormatting('tr_TR');

  // Supabase Veritabanı Bağlantısı
  await Supabase.initialize(
    url: 'https://giyazjlrwljsujgczrua.supabase.co',
    publishableKey: 'sb_publishable_pC2I71cFNRVnwzPsw0Ugng_p4wQRXGR',
  );

  runApp(const ProviderScope(child: RakipVarApp()));
}

class RakipVarApp extends ConsumerWidget {
  const RakipVarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'RakipVar',
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
      home: const MainShell(),
    );
  }
}