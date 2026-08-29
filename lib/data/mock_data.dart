import '../models/models.dart';

/// Statik mock veriler.
///
/// Supabase'e geçerken bu sınıfın yerini repository implementasyonları alır;
/// ekranlar yalnızca provider'lara baktığı için UI kodu değişmez.
abstract final class MockData {
  static final DateTime _now = DateTime.now();

  static DateTime _daysFromNow(int days, {int hour = 21, int minute = 0}) =>
      DateTime(_now.year, _now.month, _now.day + days, hour, minute);

  // -------------------------------------------------------------------
  // Örnek takım kaptanı
  // -------------------------------------------------------------------
  // Not: Gerçek kullanıcı artık Supabase oturumundan geliyor
  // (currentUserProvider). Buradaki id yalnızca örnek takımların
  // bir sahibi olsun diye duruyor; giriş yapan kullanıcıyla eşleşmez.
  static const String demoCaptainId = 'u-001';

  // -------------------------------------------------------------------
  // Halı sahalar
  // -------------------------------------------------------------------
  static const List<Pitch> pitches = <Pitch>[
    Pitch(
      id: 'p-01',
      name: 'Bornova Spor Kompleksi',
      district: 'Bornova',
      address: 'Kazımdirik Mah. 296 Sk. No:4',
      phone: '+90 232 333 00 01',
      teamCount: 14,
      pricePerHour: 900,
      hasParking: true,
      hasShower: true,
      description: 'İki adet 7v7 saha, profesyonel gece aydınlatması.',
    ),
    Pitch(
      id: 'p-02',
      name: 'Karşıyaka Arena',
      district: 'Karşıyaka',
      address: 'Bostanlı Mah. Cemal Gürsel Cad. No:112',
      phone: '+90 232 333 00 02',
      teamCount: 11,
      pricePerHour: 1100,
      isIndoor: true,
      hasParking: true,
      hasShower: true,
      description: 'Kapalı saha, yeni suni çim, kafeterya mevcut.',
    ),
    Pitch(
      id: 'p-03',
      name: 'Buca Halısaha',
      district: 'Buca',
      address: 'Şirinyer Mah. 187 Sk. No:9',
      phone: '+90 232 333 00 03',
      teamCount: 9,
      pricePerHour: 750,
      hasShower: true,
      description: 'Tek saha, hafta içi gündüz indirimli.',
    ),
    Pitch(
      id: 'p-04',
      name: 'Gaziemir Yıldız Saha',
      district: 'Gaziemir',
      address: 'Atatürk Mah. 25 Sk. No:2',
      phone: '+90 232 333 00 04',
      teamCount: 7,
      pricePerHour: 800,
      hasParking: true,
      description: 'Geniş otopark, 8v8 saha.',
    ),
    Pitch(
      id: 'p-05',
      name: 'Konak Sahil Spor',
      district: 'Konak',
      address: 'Göztepe Mah. Mithatpaşa Cad. No:401',
      phone: '+90 232 333 00 05',
      teamCount: 6,
      pricePerHour: 950,
      hasShower: true,
      description: 'Sahil kenarında, manzaralı saha.',
    ),
    Pitch(
      id: 'p-06',
      name: 'Çiğli Futbol Park',
      district: 'Çiğli',
      address: 'Ataşehir Mah. 8020 Sk. No:15',
      phone: '+90 232 333 00 06',
      teamCount: 5,
      pricePerHour: 700,
      isIndoor: true,
      hasParking: true,
      hasShower: true,
      description: 'İki kapalı saha, duş ve soyunma odası.',
    ),
    Pitch(
      id: 'p-07',
      name: 'Balçova Termal Saha',
      district: 'Balçova',
      address: 'Bahçelerarası Mah. 34 Sk. No:7',
      phone: '+90 232 333 00 07',
      teamCount: 4,
      pricePerHour: 850,
      hasShower: true,
      description: 'Termal tesis içinde, 6v6 saha.',
    ),
    Pitch(
      id: 'p-08',
      name: 'Urla Sahil Halısaha',
      district: 'Urla',
      address: 'İskele Mah. 1006 Sk. No:3',
      phone: '+90 232 333 00 08',
      teamCount: 3,
      pricePerHour: 650,
      hasParking: true,
      description: 'Deniz kenarı, yaz aylarında yoğun.',
    ),
  ];

  // -------------------------------------------------------------------
  // Takımlar (pitchId üzerinden sahaya bağlı)
  // -------------------------------------------------------------------
  static const List<Team> teams = <Team>[
    // Bornova - kullanıcının takımı burada
    Team(
      id: 't-01',
      pitchId: 'p-01',
      captainId: demoCaptainId,
      name: 'Bornova Kartalları',
      contactPhone: '+90 532 111 22 33',
      wins: 12,
      draws: 4,
      losses: 3,
    ),
    Team(
      id: 't-02',
      pitchId: 'p-01',
      captainId: 'u-002',
      name: 'Kazımdirik United',
      contactPhone: '+90 533 222 33 44',
      wins: 9,
      draws: 6,
      losses: 5,
    ),
    Team(
      id: 't-03',
      pitchId: 'p-01',
      captainId: 'u-003',
      name: 'Ege FC',
      contactPhone: '+90 534 333 44 55',
      wins: 7,
      draws: 2,
      losses: 9,
    ),
    Team(
      id: 't-04',
      pitchId: 'p-01',
      captainId: 'u-004',
      name: 'Erzene Spor',
      contactPhone: '+90 535 444 55 66',
      wins: 5,
      draws: 5,
      losses: 8,
    ),
    // Karşıyaka
    Team(
      id: 't-05',
      pitchId: 'p-02',
      captainId: 'u-005',
      name: 'Bostanlı Yıldızları',
      contactPhone: '+90 536 555 66 77',
      wins: 15,
      draws: 3,
      losses: 2,
    ),
    Team(
      id: 't-06',
      pitchId: 'p-02',
      captainId: 'u-006',
      name: 'Mavişehir SK',
      contactPhone: '+90 537 666 77 88',
      wins: 8,
      draws: 4,
      losses: 6,
    ),
    // Buca
    Team(
      id: 't-07',
      pitchId: 'p-03',
      captainId: 'u-007',
      name: 'Şirinyer Gücü',
      contactPhone: '+90 538 777 88 99',
      wins: 6,
      draws: 7,
      losses: 4,
    ),
    Team(
      id: 't-08',
      pitchId: 'p-03',
      captainId: 'u-008',
      name: 'Buca Efes',
      contactPhone: '+90 539 888 99 00',
      wins: 4,
      draws: 3,
      losses: 10,
    ),
    // Gaziemir
    Team(
      id: 't-09',
      pitchId: 'p-04',
      captainId: 'u-009',
      name: 'Gaziemir Şimşek',
      contactPhone: '+90 541 999 00 11',
      wins: 10,
      draws: 1,
      losses: 4,
    ),
  ];

  // -------------------------------------------------------------------
  // Kaleciler
  // -------------------------------------------------------------------
  static const List<Goalkeeper> goalkeepers = <Goalkeeper>[
    Goalkeeper(
      id: 'g-01',
      fullName: 'Mert Yılmaz',
      age: 27,
      districts: <String>['Bornova', 'Buca', 'Bayraklı'],
      about: '10 yıldır kalede oynuyorum. Hafta içi akşam ve hafta sonu müsaitim.',
      phone: '+90 532 100 10 10',
      rating: 4.7,
      ratingCount: 32,
    ),
    Goalkeeper(
      id: 'g-02',
      fullName: 'Can Demir',
      age: 22,
      districts: <String>['Karşıyaka', 'Çiğli'],
      about: 'Üniversite takımında kalecilik yapıyorum, refleks ve ayak oyunu iyi.',
      phone: '+90 533 200 20 20',
      rating: 4.2,
      ratingCount: 18,
    ),
    Goalkeeper(
      id: 'g-03',
      fullName: 'Emre Kaya',
      age: 31,
      districts: <String>['Konak', 'Balçova', 'Karabağlar', 'Narlıdere'],
      about: 'Tecrübeli kaleci. Kısa sürede haber verirseniz yetişebilirim.',
      phone: '+90 534 300 30 30',
      rating: 4.9,
      ratingCount: 54,
    ),
    Goalkeeper(
      id: 'g-04',
      fullName: 'Ozan Şahin',
      age: 25,
      districts: <String>['Gaziemir', 'Buca', 'Menderes'],
      about: 'Salı ve perşembe akşamları boşum. Eldivenim ve formam kendime ait.',
      phone: '+90 535 400 40 40',
      rating: 3.8,
      ratingCount: 11,
    ),
    Goalkeeper(
      id: 'g-05',
      fullName: 'Kerem Aydın',
      age: 29,
      districts: <String>['Bornova', 'Kemalpaşa'],
      about: 'Uzun toplarda ve penaltılarda iddialıyım.',
      phone: '+90 536 500 50 50',
      rating: 4.4,
      ratingCount: 26,
    ),
    Goalkeeper(
      id: 'g-06',
      fullName: 'Deniz Arslan',
      age: 24,
      districts: <String>['Urla', 'Güzelbahçe', 'Seferihisar'],
      about: 'Hafta sonları sahil hattındaki sahalarda oynayabilirim.',
      phone: '+90 537 600 60 60',
      rating: 4.0,
      ratingCount: 9,
    ),
    Goalkeeper(
      id: 'g-07',
      fullName: 'Burak Öztürk',
      age: 35,
      districts: <String>['Karşıyaka', 'Bayraklı', 'Bornova'],
      about: 'Amatör küme tecrübem var, düzenli maç arıyorum.',
      phone: '+90 538 700 70 70',
      rating: 4.6,
      ratingCount: 41,
    ),
  ];

  /// Kullanıcının kendi kaleci profili (henüz oluşturulmadıysa null).
  static const Goalkeeper? myGoalkeeperProfile = null;

  // -------------------------------------------------------------------
  // Maç geçmişi (en yeniden eskiye)
  // -------------------------------------------------------------------
  static List<MatchHistoryEntry> get matchHistory => <MatchHistoryEntry>[
        MatchHistoryEntry(
          id: 'm-h1',
          opponentName: 'Kazımdirik United',
          pitchName: 'Bornova Spor Kompleksi',
          playedAt: _daysFromNow(-4),
          outcome: TeamOutcome.win,
        ),
        MatchHistoryEntry(
          id: 'm-h2',
          opponentName: 'Ege FC',
          pitchName: 'Bornova Spor Kompleksi',
          playedAt: _daysFromNow(-11),
          outcome: TeamOutcome.draw,
        ),
        MatchHistoryEntry(
          id: 'm-h3',
          opponentName: 'Erzene Spor',
          pitchName: 'Bornova Spor Kompleksi',
          playedAt: _daysFromNow(-19),
          outcome: TeamOutcome.loss,
        ),
        MatchHistoryEntry(
          id: 'm-h4',
          opponentName: 'Bostanlı Yıldızları',
          pitchName: 'Karşıyaka Arena',
          playedAt: _daysFromNow(-27),
          outcome: TeamOutcome.win,
        ),
        MatchHistoryEntry(
          id: 'm-h5',
          opponentName: 'Şirinyer Gücü',
          pitchName: 'Buca Halısaha',
          playedAt: _daysFromNow(-33),
          outcome: TeamOutcome.win,
        ),
      ];

  // -------------------------------------------------------------------
  // Bekleyen maçlar — 4 aşamanın hepsini kapsayan örnekler
  // -------------------------------------------------------------------
  static List<PendingMatch> get pendingMatches => <PendingMatch>[
        // AŞAMA 1: Bize meydan okundu -> Kabul / Reddet
        PendingMatch(
          id: 'm-01',
          myTeamName: 'Bornova Kartalları',
          opponentTeamName: 'Ege FC',
          opponentPhone: '+90 534 333 44 55',
          opponentCaptainName: 'Serkan Doğan',
          pitchName: 'Bornova Spor Kompleksi',
          status: MatchStatus.pending,
          isChallenger: false,
          myTeamReady: false,
          opponentReady: false,
        ),
        // AŞAMA 1b: Biz meydan okuduk, yanıt bekliyoruz
        PendingMatch(
          id: 'm-02',
          myTeamName: 'Bornova Kartalları',
          opponentTeamName: 'Erzene Spor',
          opponentPhone: '+90 535 444 55 66',
          opponentCaptainName: 'Tolga Aksu',
          pitchName: 'Bornova Spor Kompleksi',
          status: MatchStatus.pending,
          isChallenger: true,
          myTeamReady: false,
          opponentReady: false,
        ),
        // AŞAMA 2: Kabul edildi -> "Maça Hazırım" (henüz kimse basmadı)
        PendingMatch(
          id: 'm-03',
          myTeamName: 'Bornova Kartalları',
          opponentTeamName: 'Kazımdirik United',
          opponentPhone: '+90 533 222 33 44',
          opponentCaptainName: 'Ahmet Korkmaz',
          pitchName: 'Bornova Spor Kompleksi',
          status: MatchStatus.accepted,
          isChallenger: true,
          myTeamReady: false,
          opponentReady: false,
          acceptedAt: _daysFromNow(-2),
        ),
        // AŞAMA 2b: Biz hazırız, rakip bekleniyor (süre azalıyor)
        PendingMatch(
          id: 'm-04',
          myTeamName: 'Bornova Kartalları',
          opponentTeamName: 'Buca Efes',
          opponentPhone: '+90 539 888 99 00',
          opponentCaptainName: 'Volkan Er',
          pitchName: 'Buca Halısaha',
          status: MatchStatus.accepted,
          isChallenger: false,
          myTeamReady: true,
          opponentReady: false,
          acceptedAt: _daysFromNow(-6),
        ),
        // AŞAMA 3: İki taraf da hazır -> iletişim açık, tarih bekleniyor
        PendingMatch(
          id: 'm-05',
          myTeamName: 'Bornova Kartalları',
          opponentTeamName: 'Gaziemir Şimşek',
          opponentPhone: '+90 541 999 00 11',
          opponentCaptainName: 'Hakan Uslu',
          pitchName: 'Gaziemir Yıldız Saha',
          status: MatchStatus.mutuallyAgreed,
          isChallenger: true,
          myTeamReady: true,
          opponentReady: true,
          acceptedAt: _daysFromNow(-3),
        ),
        // AŞAMA 3b: Tarih girilmiş, maç bekleniyor
        PendingMatch(
          id: 'm-06',
          myTeamName: 'Bornova Kartalları',
          opponentTeamName: 'Mavişehir SK',
          opponentPhone: '+90 537 666 77 88',
          opponentCaptainName: 'Onur Bilgin',
          pitchName: 'Karşıyaka Arena',
          status: MatchStatus.scheduled,
          isChallenger: true,
          myTeamReady: true,
          opponentReady: true,
          acceptedAt: _daysFromNow(-5),
          matchDate: _daysFromNow(3, hour: 21),
        ),
        // AŞAMA 4: Maç saati + 1 saat geçti -> "Sonucu Gir"
        PendingMatch(
          id: 'm-07',
          myTeamName: 'Bornova Kartalları',
          opponentTeamName: 'Bostanlı Yıldızları',
          opponentPhone: '+90 536 555 66 77',
          opponentCaptainName: 'Kaan Yüce',
          pitchName: 'Karşıyaka Arena',
          status: MatchStatus.scheduled,
          isChallenger: true,
          myTeamReady: true,
          opponentReady: true,
          acceptedAt: _daysFromNow(-10),
          matchDate: _daysFromNow(-1, hour: 20),
        ),
      ];

  // -------------------------------------------------------------------
  // Takvim etkinlikleri (ana sayfadaki takvimde nokta olarak görünür)
  // -------------------------------------------------------------------
  static List<CalendarEvent> get calendarEvents => <CalendarEvent>[
        CalendarEvent(
          date: _daysFromNow(3, hour: 21),
          title: 'Mavişehir SK',
          subtitle: 'Karşıyaka Arena · 21:00',
        ),
        CalendarEvent(
          date: _daysFromNow(6, hour: 20),
          title: 'Gaziemir Şimşek',
          subtitle: 'Gaziemir Yıldız Saha · 20:00',
        ),
        CalendarEvent(
          date: _daysFromNow(12, hour: 22),
          title: 'Kazımdirik United',
          subtitle: 'Bornova Spor Kompleksi · 22:00',
        ),
      ];
}
