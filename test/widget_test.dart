import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rakipvar/core/constants/izmir_districts.dart';
import 'package:rakipvar/main.dart';
import 'package:rakipvar/models/models.dart';
import 'package:rakipvar/state/app_providers.dart';

PendingMatch _match({
  required MatchStatus status,
  bool isChallenger = true,
  bool myTeamReady = false,
  bool opponentReady = false,
  DateTime? acceptedAt,
  DateTime? matchDate,
}) {
  return PendingMatch(
    id: 'm-test',
    myTeamName: 'Bornova Kartalları',
    opponentTeamName: 'Ege FC',
    opponentPhone: '+90 500 000 00 00',
    opponentCaptainName: 'Test Kaptan',
    pitchName: 'Test Sahası',
    status: status,
    isChallenger: isChallenger,
    myTeamReady: myTeamReady,
    opponentReady: opponentReady,
    acceptedAt: acceptedAt,
    matchDate: matchDate,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  group('PendingMatch aşama makinesi', () {
    test('1. aşama: bize meydan okunduysa davet alındı olur', () {
      expect(
        _match(status: MatchStatus.pending, isChallenger: false).stage,
        PendingMatchStage.invitationReceived,
      );
      expect(
        _match(status: MatchStatus.pending).stage,
        PendingMatchStage.invitationSent,
      );
    });

    test('2. aşama: kabul sonrası karşılıklı onay beklenir', () {
      final PendingMatch match = _match(
        status: MatchStatus.accepted,
        acceptedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(match.stage, PendingMatchStage.readinessPending);
      expect(match.isContactVisible, isFalse, reason: 'İletişim henüz açılmamalı');
      expect(match.timeLeftForReadiness.inDays, 4);
    });

    test('2. aşama: 1 hafta dolduysa süresi dolmuş sayılır', () {
      final PendingMatch match = _match(
        status: MatchStatus.accepted,
        acceptedAt: DateTime.now().subtract(const Duration(days: 8)),
      );
      expect(match.stage, PendingMatchStage.expired);
      expect(match.timeLeftForReadiness, Duration.zero);
    });

    test('3. aşama: karşılıklı onaydan sonra iletişim açılır', () {
      final PendingMatch match = _match(
        status: MatchStatus.mutuallyAgreed,
        myTeamReady: true,
        opponentReady: true,
        acceptedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(match.stage, PendingMatchStage.confirmed);
      expect(match.isContactVisible, isTrue);
    });

    test('4. aşama: maç saati + 1 saat geçince sonuç istenir', () {
      final DateTime past = DateTime.now().subtract(const Duration(hours: 3));
      expect(
        _match(status: MatchStatus.scheduled, matchDate: past).stage,
        PendingMatchStage.awaitingResult,
      );

      // Henüz 1 saat dolmadıysa hâlâ "kesinleşti" aşamasında.
      final DateTime justNow = DateTime.now().subtract(const Duration(minutes: 20));
      expect(
        _match(status: MatchStatus.scheduled, matchDate: justNow).stage,
        PendingMatchStage.confirmed,
      );
    });
  });

  group('Onay akışı controller', () {
    test('markReady iki taraf da hazır olunca maçı kesinleştirir', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final PendingMatchesController controller =
          container.read(pendingMatchesProvider.notifier);

      // m-04: biz hazırız, rakip zaten hazır değil -> önce rakip hazır olsun
      controller.acceptChallenge('m-01');
      final PendingMatch accepted = container
          .read(pendingMatchesProvider)
          .firstWhere((PendingMatch m) => m.id == 'm-01');
      expect(accepted.stage, PendingMatchStage.readinessPending);

      controller.markReady('m-01');
      final PendingMatch afterReady = container
          .read(pendingMatchesProvider)
          .firstWhere((PendingMatch m) => m.id == 'm-01');
      // Rakip henüz onaylamadığı için hâlâ 2. aşamada.
      expect(afterReady.myTeamReady, isTrue);
      expect(afterReady.stage, PendingMatchStage.readinessPending);
    });

    test('reportResult maçı listeden çıkarıp geçmişe ekler', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final int historyBefore = container.read(matchHistoryProvider).length;
      container.read(pendingMatchesProvider.notifier).reportResult('m-07', TeamOutcome.win);

      expect(
        container.read(pendingMatchesProvider).any((PendingMatch m) => m.id == 'm-07'),
        isFalse,
      );
      expect(container.read(matchHistoryProvider).length, historyBefore + 1);
      expect(container.read(matchHistoryProvider).first.outcome, TeamOutcome.win);
    });
  });

  group('Popüler sahalar', () {
    test('en çok takım barındıran 3 saha döner', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final List<Pitch> popular = container.read(popularPitchesProvider);
      expect(popular, hasLength(3));
      expect(popular[0].teamCount >= popular[1].teamCount, isTrue);
      expect(popular[1].teamCount >= popular[2].teamCount, isTrue);
    });
  });

  group('İzmir ilçeleri', () {
    test('Türkçe alfabetik sıralama Ç/Ö/Ş harflerini doğru yerleştirir', () {
      final List<String> sorted =
          IzmirDistricts.sorted(<String>['Ödemiş', 'Aliağa', 'Çeşme', 'Seferihisar', 'Buca']);
      expect(sorted, <String>['Aliağa', 'Buca', 'Çeşme', 'Ödemiş', 'Seferihisar']);
    });

    test('30 ilçe tanımlı', () {
      expect(IzmirDistricts.all, hasLength(30));
    });
  });

  testWidgets('Uygulama açılır ve 5 sekme görünür', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RakipVarApp()));
    await tester.pumpAndSettle();

    expect(find.text('RakipVar'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Sahalar'), findsOneWidget);
    expect(find.text('Kaleciler'), findsOneWidget);
    expect(find.text('Profilim'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('En Popüler Sahalar'), findsOneWidget);
    expect(find.text('Kaleci Profili Oluştur'), findsOneWidget);
  });
}
