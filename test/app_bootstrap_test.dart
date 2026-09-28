import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japonkale/features/splash/app_bootstrap.dart';

void main() {
  Widget host(Future<void> Function() initialize) => MaterialApp(
        home: AppBootstrap(
          initialize: initialize,
          child: const Text('UYGULAMA'),
        ),
      );

  testWidgets('hazırlık bitmeden uygulamaya geçilmez', (WidgetTester tester) async {
    final Completer<void> init = Completer<void>();
    await tester.pumpWidget(host(() => init.future));

    expect(find.text('Japon Kale'), findsOneWidget);
    expect(find.text('UYGULAMA'), findsNothing);

    // Animasyon süresi doldu ama hazırlık bitmedi: açılış ekranı kalır.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('UYGULAMA'), findsNothing);

    init.complete();
    await tester.pumpAndSettle();
    expect(find.text('UYGULAMA'), findsOneWidget);
    expect(find.text('Japon Kale'), findsNothing);
  });

  testWidgets('hazırlık hızlı bitse de animasyon kısa süre gösterilir, 1 sn geçmez',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(() async {}));

    // Hazırlık anında bitti; en kısa gösterim süresi dolmadan geçilmez.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('UYGULAMA'), findsNothing);

    // Kayma + bekleme + geçiş toplamı 1 saniyenin altında.
    final Duration total = AppBootstrap.introDuration +
        AppBootstrap.holdDuration +
        AppBootstrap.exitDuration;
    expect(total, lessThan(const Duration(seconds: 1)));

    await tester.pump(total);
    await tester.pumpAndSettle();
    expect(find.text('UYGULAMA'), findsOneWidget);
  });

  testWidgets('hazırlık hata verirse tekrar dene butonu çıkar', (WidgetTester tester) async {
    int attempts = 0;
    await tester.pumpWidget(host(() async {
      attempts++;
      if (attempts == 1) throw Exception('ağ yok');
    }));
    // pumpAndSettle animasyon bitince durur; en kısa gösterim
    // zamanlayıcısının dolması için zamanı açıkça ilerlet.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('UYGULAMA'), findsNothing);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('UYGULAMA'), findsOneWidget);
    expect(attempts, 2);
  });
}
