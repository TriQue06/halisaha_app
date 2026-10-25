import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japonkale/features/teams/widgets/roster_editor.dart';
import 'package:japonkale/features/teams/widgets/team_size_picker.dart';
import 'package:japonkale/models/models.dart';

void main() {
  group('Kadro editörü', () {
    late RosterController controller;

    Widget host() => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(child: RosterEditor(controller: controller)),
            ),
          ),
        );

    setUp(() => controller = RosterController());
    tearDown(() => controller.dispose());

    testWidgets('7 boş satırla başlar, 7 satırda silme yok', (WidgetTester tester) async {
      await tester.pumpWidget(host());
      expect(find.widgetWithText(TextFormField, 'Ad / takma ad'), findsNWidgets(kMinRosterSize));
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);
    });

    testWidgets('"Yeni Oyuncu Ekle" satır ekler, fazla satır silinebilir',
        (WidgetTester tester) async {
      await tester.pumpWidget(host());
      await tester.ensureVisible(find.text('Yeni Oyuncu Ekle'));
      await tester.tap(find.text('Yeni Oyuncu Ekle'));
      await tester.pump();
      expect(controller.length, kMinRosterSize + 1);
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsWidgets);

      controller.removeAt(0);
      await tester.pump();
      expect(controller.length, kMinRosterSize);
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);
    });

    testWidgets('ad zorunlu, soyad isteğe bağlı', (WidgetTester tester) async {
      final GlobalKey<FormState> key = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(key: key, child: RosterEditor(controller: controller)),
          ),
        ),
      ));
      expect(key.currentState!.validate(), isFalse);

      // Yalnızca adlar (takma ad olabilir) yeterli; soyad boş kalabilir.
      final Finder names = find.widgetWithText(TextFormField, 'Ad / takma ad');
      for (int i = 0; i < kMinRosterSize; i++) {
        await tester.enterText(names.at(i), 'Oyuncu$i');
      }
      expect(key.currentState!.validate(), isTrue);
      expect(controller.entries.every((RosterEntry e) => e.lastName.isEmpty), isTrue);
      expect(controller.entries.length, kMinRosterSize);
      expect(controller.entries.first.id, isNull);
    });
  });

  testWidgets('kişi sayısı seçimi 5v5 ile 11v11 arası', (WidgetTester tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () async => picked = await showTeamSizePicker(context),
          child: const Text('aç'),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(kMaxTeamSize - kMinTeamSize + 1));
    expect(find.text('5v5'), findsOneWidget);
    expect(find.text('11v11'), findsOneWidget);

    await tester.tap(find.text('9v9'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(picked, 9);
  });

  test('maç geçmişi satırı skoru okur', () {
    final MatchHistoryEntry e = MatchHistoryEntry.fromRow(<String, dynamic>{
      'match_id': 'm1',
      'opponent_id': 't2',
      'opponent_name': 'Kartallar',
      'pitch_name': 'Saha',
      'played_at': '2026-10-01T18:00:00Z',
      'outcome': 'win',
      'team_score': 4,
      'opponent_score': 2,
      'team_size': 7,
    });
    expect(e.outcome, TeamOutcome.win);
    expect(e.scoreLabel, '4 - 2');
    expect(e.teamSize, 7);

    final MatchHistoryEntry legacy = MatchHistoryEntry.fromRow(<String, dynamic>{
      'match_id': 'm2',
      'outcome': 'draw',
    });
    expect(legacy.scoreLabel, isNull);
  });

  test('uygulamadaki sınırlar veritabanıyla aynı', () {
    final String sql = File(
      'supabase/migrations/20261003000000_rosters_lineups_stats.sql',
    ).readAsStringSync();
    expect(sql, contains('jsonb_array_length(p_players) < $kMinRosterSize'));
    expect(sql, contains('team_size between $kMinTeamSize and $kMaxTeamSize'));
    expect(sql, contains('team_roster_size(new.challenger_team_id) < $kMinRosterSize'));
  });
}
