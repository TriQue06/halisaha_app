import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:japonkale/core/constants/izmir_districts.dart';
import 'package:japonkale/features/auth/widgets/auth_widgets.dart';
import 'package:japonkale/features/shell/main_shell.dart';
import 'package:japonkale/models/models.dart';
import 'package:japonkale/state/app_providers.dart';
import 'package:japonkale/state/auth_controller.dart';

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
    test('1. aşama: bize teklif geldiyse davet alındı olur', () {
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

  group('Bildirimler', () {
    test('satır modele çevrilir ve bilinmeyen tip generic olur', () {
      final AppNotification n = AppNotification.fromRow(<String, dynamic>{
        'id': 'n1',
        'type': 'challenge_received',
        'title': 'Yeni maç teklifi!',
        'body': 'Ege FC takımı size maç teklifi gönderdi.',
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'match_id': 'm1',
      });
      expect(n.kind, NotificationKind.challengeReceived);
      expect(n.isRead, isFalse);
      expect(n.relativeTime, 'az önce');
      expect(n.kind.opensMyTeam, isTrue);

      final AppNotification unknown = AppNotification.fromRow(<String, dynamic>{
        'id': 'n2',
        'type': 'her_neyse',
        'title': 'x',
        'is_read': true,
        'created_at': '',
      });
      expect(unknown.kind, NotificationKind.generic);
      expect(unknown.kind.opensMyTeam, isFalse, reason: 'Genel bildirim sekme değiştirmez');
    });

    test('göreli zaman saat/gün eşiklerini aşar', () {
      AppNotification at(Duration ago) => AppNotification(
            id: 'x',
            kind: NotificationKind.generic,
            title: 't',
            body: '',
            isRead: false,
            createdAt: DateTime.now().subtract(ago),
          );
      expect(at(const Duration(minutes: 5)).relativeTime, '5 dk önce');
      expect(at(const Duration(hours: 3)).relativeTime, '3 sa önce');
      expect(at(const Duration(days: 2)).relativeTime, '2 gün önce');
    });
  });

  group('Şifre + şifre onay alanları', () {
    Future<void> pump(WidgetTester tester, GlobalKey<FormState> key,
        TextEditingController pass, TextEditingController confirm) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: key,
              child: PasswordFields(
                passwordController: pass,
                confirmController: confirm,
                obscurePassword: true,
                obscureConfirm: true,
                onTogglePassword: () {},
                onToggleConfirm: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('şifreler eşleşmezse doğrulama başarısız olur',
        (WidgetTester tester) async {
      final GlobalKey<FormState> key = GlobalKey<FormState>();
      final TextEditingController pass = TextEditingController(text: 'gizli123');
      final TextEditingController confirm = TextEditingController(text: 'gizli124');
      await pump(tester, key, pass, confirm);

      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    });

    testWidgets('kısa şifre reddedilir, eşleşen uzun şifre kabul edilir',
        (WidgetTester tester) async {
      final GlobalKey<FormState> key = GlobalKey<FormState>();
      final TextEditingController pass = TextEditingController(text: '123');
      final TextEditingController confirm = TextEditingController(text: '123');
      await pump(tester, key, pass, confirm);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Şifre en az 6 karakter olmalı.'), findsOneWidget);

      pass.text = 'gizli123';
      confirm.text = 'gizli123';
      expect(key.currentState!.validate(), isTrue);
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

  group('Telefon numarası normalizasyonu', () {
    test('farklı yazımlar tek E.164 biçimine indirgenir', () {
      const String expected = '+905321112233';
      for (final String input in <String>[
        '0532 111 22 33',
        '532 111 22 33',
        '5321112233',
        '05321112233',
        '+90 532 111 22 33',
        '90 532 111 22 33',
        '0090 532 111 22 33',
        '(0532) 111-22-33',
      ]) {
        expect(AuthController.normalizePhone(input), expected, reason: 'girdi: $input');
      }
    });
  });

  testWidgets('Ana kabuk açılır ve 5 sekme görünür', (WidgetTester tester) async {
    // JaponKaleApp yerine doğrudan MainShell'i çalıştırıyoruz: JaponKaleApp
    // artık AuthGate üzerinden Supabase.instance'a bağlı ve widget testinde
    // gerçek bir Supabase oturumu başlatmak istemiyoruz.
    await tester.pumpWidget(
      ProviderScope(
        // MainShell artık gerçek kullanıcıyı Supabase oturumundan okuyor.
        // Testte Supabase başlatılmadığı için kullanıcı sağlayıcılarını
        // sabit bir profille değiştiriyoruz.
        overrides: <Override>[
          currentUserIdProvider.overrideWithValue('test-user'),
          currentUserProvider.overrideWithValue(
            UserProfile(
              id: 'test-user',
              firstName: 'Test',
              lastName: 'Kullanıcı',
              phone: '+905000000000',
              birthDate: DateTime(1995, 4, 12),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: <Locale>[Locale('tr', 'TR')],
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MainShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Japon Kale'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Sahalar'), findsOneWidget);
    expect(find.text('Kaleciler'), findsOneWidget);
    expect(find.text('Profilim'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('En Popüler Sahalar'), findsOneWidget);
    expect(find.text('Kaleci Profili Oluştur'), findsOneWidget);
  });
}
