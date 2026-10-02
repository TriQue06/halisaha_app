import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japonkale/data/moderation_repository.dart';
import 'package:japonkale/features/moderation/report_action_sheet.dart';
import 'package:japonkale/state/app_providers.dart';

void main() {
  group('Rapor sebepleri', () {
    test('kodlar veritabanındaki reports.reason kontrolüyle birebir aynı', () {
      final String sql = File(
        'supabase/migrations/20261002000000_reports_and_blocks.sql',
      ).readAsStringSync();
      final RegExpMatch? m =
          RegExp(r"check \(reason in \(([^)]*)\)\)").firstMatch(sql);
      expect(m, isNotNull);
      final Set<String> dbCodes = RegExp(r"'([a-z_]+)'")
          .allMatches(m!.group(1)!)
          .map((RegExpMatch x) => x.group(1)!)
          .toSet();
      expect(
          ReportReason.values.map((ReportReason r) => r.code).toSet(), dbCodes);
    });

    test('yalnızca "Diğer" açıklama zorunlu tutar', () {
      expect(
        ReportReason.values.where((ReportReason r) => r.requiresDescription),
        <ReportReason>[ReportReason.other],
      );
    });
  });

  group('Rapor et / Engelle menüsü', () {
    Widget host(String userId) => ProviderScope(
          overrides: <Override>[
            currentUserIdProvider.overrideWithValue('ben'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ModerationMenuButton(
                userId: userId,
                displayName: 'Kartallar',
                reportContext: ReportContext.team,
              ),
            ),
          ),
        );

    testWidgets('kullanıcının kendi içeriğinde görünmez',
        (WidgetTester tester) async {
      await tester.pumpWidget(host('ben'));
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    testWidgets('başkasının içeriğinde rapor et ve engelle seçenekleri var',
        (WidgetTester tester) async {
      await tester.pumpWidget(host('baskasi'));
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Rapor et'), findsOneWidget);
      expect(find.text('Engelle'), findsOneWidget);
    });

    testWidgets('rapor penceresi sebep seçilmeden gönderilemez',
        (WidgetTester tester) async {
      await tester.pumpWidget(host('baskasi'));
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rapor et'));
      await tester.pumpAndSettle();

      FilledButton submit() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Raporu gönder'));
      expect(submit().onPressed, isNull);

      await tester.tap(find.text('Spam veya reklam'));
      await tester.pump();
      expect(submit().onPressed, isNotNull);

      // "Diğer" seçilince açıklama yazılmadan gönderilemez.
      await tester.tap(find.text('Diğer'));
      await tester.pump();
      expect(submit().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Sahada kavga çıkardı');
      await tester.pump();
      expect(submit().onPressed, isNotNull);
    });
  });
}
