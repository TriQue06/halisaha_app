import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/models.dart';

// =====================================================================
// KULLANICI
// =====================================================================

final Provider<UserProfile> currentUserProvider =
    Provider<UserProfile>((Ref ref) => MockData.currentUser);

// =====================================================================
// HALI SAHALAR
// =====================================================================

final Provider<List<Pitch>> pitchesProvider =
    Provider<List<Pitch>>((Ref ref) => MockData.pitches);

/// Ana sayfa: en çok takım barındıran 3 saha.
final Provider<List<Pitch>> popularPitchesProvider = Provider<List<Pitch>>((Ref ref) {
  final List<Pitch> all = <Pitch>[...ref.watch(pitchesProvider)]
    ..sort((Pitch a, Pitch b) => b.teamCount.compareTo(a.teamCount));
  return all.take(3).toList(growable: false);
});

/// Sahalar sekmesindeki arama metni.
final StateProvider<String> pitchSearchQueryProvider = StateProvider<String>((Ref ref) => '');

/// Ada, ilçeye veya adrese göre filtrelenmiş saha listesi.
final Provider<List<Pitch>> filteredPitchesProvider = Provider<List<Pitch>>((Ref ref) {
  final String query = ref.watch(pitchSearchQueryProvider).trim().toLowerCase();
  final List<Pitch> pitches = ref.watch(pitchesProvider);
  if (query.isEmpty) return pitches;

  return pitches.where((Pitch p) {
    return p.name.toLowerCase().contains(query) ||
        p.district.toLowerCase().contains(query) ||
        p.address.toLowerCase().contains(query);
  }).toList(growable: false);
});

// =====================================================================
// TAKIMLAR
// =====================================================================

/// Takım listesi — yeni takım oluşturma bu controller üzerinden yapılır.
class TeamsController extends Notifier<List<Team>> {
  @override
  List<Team> build() => MockData.teams;

  /// Saha detayındaki "Takımımı Bu Sahaya Kaydet" akışı.
  Team createTeam({
    required String pitchId,
    required String name,
    required String contactPhone,
  }) {
    final Team team = Team(
      id: 't-${DateTime.now().millisecondsSinceEpoch}',
      pitchId: pitchId,
      captainId: MockData.currentUserId,
      name: name,
      contactPhone: contactPhone,
    );
    state = <Team>[...state, team];
    return team;
  }
}

final NotifierProvider<TeamsController, List<Team>> teamsProvider =
    NotifierProvider<TeamsController, List<Team>>(TeamsController.new);

/// Bir sahaya kayıtlı takımlar — puan durumuna göre sıralı.
final ProviderFamily<List<Team>, String> teamsForPitchProvider =
    Provider.family<List<Team>, String>((Ref ref, String pitchId) {
  final List<Team> teams =
      ref.watch(teamsProvider).where((Team t) => t.pitchId == pitchId).toList()
        ..sort((Team a, Team b) => b.points.compareTo(a.points));
  return teams;
});

/// Kullanıcının BU sahadaki takımı (yoksa null).
///
/// "MEYDAN OKU" butonunun görünürlüğü tamamen buna bağlıdır:
/// kullanıcının o sahada kayıtlı takımı yoksa buton gizlenir.
final ProviderFamily<Team?, String> myTeamForPitchProvider =
    Provider.family<Team?, String>((Ref ref, String pitchId) {
  final String uid = ref.watch(currentUserProvider).id;
  for (final Team team in ref.watch(teamsProvider)) {
    if (team.pitchId == pitchId && team.captainId == uid) return team;
  }
  return null;
});

/// Kullanıcının kaptanı olduğu tüm takımlar.
final Provider<List<Team>> myTeamsProvider = Provider<List<Team>>((Ref ref) {
  final String uid = ref.watch(currentUserProvider).id;
  return ref.watch(teamsProvider).where((Team t) => t.captainId == uid).toList(growable: false);
});

// =====================================================================
// KALECİLER
// =====================================================================

final Provider<List<Goalkeeper>> goalkeepersProvider =
    Provider<List<Goalkeeper>>((Ref ref) => MockData.goalkeepers);

/// Kaleci sekmesinde seçili ilçe (null = tüm ilçeler).
final StateProvider<String?> selectedDistrictProvider = StateProvider<String?>((Ref ref) => null);

/// Seçili ilçeye göre filtrelenmiş, puanı yüksekten düşüğe kaleci listesi.
final Provider<List<Goalkeeper>> filteredGoalkeepersProvider =
    Provider<List<Goalkeeper>>((Ref ref) {
  final String? district = ref.watch(selectedDistrictProvider);
  final List<Goalkeeper> all = ref.watch(goalkeepersProvider);

  final List<Goalkeeper> filtered = district == null
      ? <Goalkeeper>[...all]
      : all.where((Goalkeeper g) => g.districts.contains(district)).toList();

  filtered.sort((Goalkeeper a, Goalkeeper b) => b.rating.compareTo(a.rating));
  return filtered;
});

/// Kullanıcının kendi kaleci profili — yoksa ana sayfadaki CTA görünür.
class MyGoalkeeperController extends Notifier<Goalkeeper?> {
  @override
  Goalkeeper? build() => MockData.myGoalkeeperProfile;

  void save({
    required List<String> districts,
    required String about,
    required String phone,
    String? avatarUrl,
    bool isAvailable = true,
  }) {
    final UserProfile user = ref.read(currentUserProvider);
    state = Goalkeeper(
      id: user.id,
      fullName: user.fullName,
      age: user.age,
      districts: districts,
      about: about,
      phone: phone,
      rating: state?.rating ?? 0,
      ratingCount: state?.ratingCount ?? 0,
      avatarUrl: avatarUrl ?? state?.avatarUrl,
      isAvailable: isAvailable,
    );
  }

  void delete() => state = null;
}

final NotifierProvider<MyGoalkeeperController, Goalkeeper?> myGoalkeeperProvider =
    NotifierProvider<MyGoalkeeperController, Goalkeeper?>(MyGoalkeeperController.new);

// =====================================================================
// MAÇLAR
// =====================================================================

/// Bekleyen maçlar ve 4 aşamalı onay akışının tüm aksiyonları.
class PendingMatchesController extends Notifier<List<PendingMatch>> {
  @override
  List<PendingMatch> build() => MockData.pendingMatches;

  void _update(String matchId, PendingMatch Function(PendingMatch) transform) {
    state = <PendingMatch>[
      for (final PendingMatch m in state) if (m.id == matchId) transform(m) else m,
    ];
  }

  /// AŞAMA 1 — meydan okumayı kabul et. 7 günlük hazırlık sayacı başlar.
  void acceptChallenge(String matchId) => _update(
        matchId,
        (PendingMatch m) => m.copyWith(
          status: MatchStatus.accepted,
          acceptedAt: DateTime.now(),
        ),
      );

  /// AŞAMA 1 — meydan okumayı reddet.
  void rejectChallenge(String matchId) {
    state = state.where((PendingMatch m) => m.id != matchId).toList(growable: false);
  }

  /// AŞAMA 2 — "Maça Hazırım". İki taraf da bastıysa maç kesinleşir.
  void markReady(String matchId) => _update(matchId, (PendingMatch m) {
        final PendingMatch updated = m.copyWith(myTeamReady: true);
        return updated.opponentReady
            ? updated.copyWith(status: MatchStatus.mutuallyAgreed)
            : updated;
      });

  /// AŞAMA 3 — meydan okuyan takım maç gün ve saatini girer.
  void setMatchDate(String matchId, DateTime date) => _update(
        matchId,
        (PendingMatch m) => m.copyWith(
          matchDate: date,
          status: MatchStatus.scheduled,
        ),
      );

  /// AŞAMA 4 — sonucu bildir; maç listeden düşer, geçmişe eklenir.
  void reportResult(String matchId, TeamOutcome outcome) {
    final PendingMatch? match = state.cast<PendingMatch?>().firstWhere(
          (PendingMatch? m) => m?.id == matchId,
          orElse: () => null,
        );
    if (match == null) return;

    ref.read(matchHistoryProvider.notifier).add(
          MatchHistoryEntry(
            id: match.id,
            opponentName: match.opponentTeamName,
            pitchName: match.pitchName,
            playedAt: match.matchDate ?? DateTime.now(),
            outcome: outcome,
          ),
        );

    state = state.where((PendingMatch m) => m.id != matchId).toList(growable: false);
  }

  /// Saha detayından yeni meydan okuma gönderildiğinde listeye eklenir.
  void sendChallenge({
    required Team myTeam,
    required Team opponent,
    required String pitchName,
  }) {
    state = <PendingMatch>[
      PendingMatch(
        id: 'm-${DateTime.now().millisecondsSinceEpoch}',
        myTeamName: myTeam.name,
        opponentTeamName: opponent.name,
        opponentPhone: opponent.contactPhone,
        opponentCaptainName: opponent.name,
        pitchName: pitchName,
        status: MatchStatus.pending,
        isChallenger: true,
        myTeamReady: false,
        opponentReady: false,
      ),
      ...state,
    ];
  }
}

final NotifierProvider<PendingMatchesController, List<PendingMatch>> pendingMatchesProvider =
    NotifierProvider<PendingMatchesController, List<PendingMatch>>(
  PendingMatchesController.new,
);

/// Maç geçmişi — her zaman en yeniden eskiye sıralı.
class MatchHistoryController extends Notifier<List<MatchHistoryEntry>> {
  @override
  List<MatchHistoryEntry> build() {
    final List<MatchHistoryEntry> history = <MatchHistoryEntry>[...MockData.matchHistory];
    _sort(history);
    return history;
  }

  static void _sort(List<MatchHistoryEntry> list) => list
      .sort((MatchHistoryEntry a, MatchHistoryEntry b) => b.playedAt.compareTo(a.playedAt));

  void add(MatchHistoryEntry entry) {
    final List<MatchHistoryEntry> next = <MatchHistoryEntry>[entry, ...state];
    _sort(next);
    state = next;
  }
}

final NotifierProvider<MatchHistoryController, List<MatchHistoryEntry>> matchHistoryProvider =
    NotifierProvider<MatchHistoryController, List<MatchHistoryEntry>>(
  MatchHistoryController.new,
);

// =====================================================================
// TAKVİM (Ana sayfa)
// =====================================================================

final Provider<List<CalendarEvent>> calendarEventsProvider =
    Provider<List<CalendarEvent>>((Ref ref) => MockData.calendarEvents);

/// Takvimde seçili gün (varsayılan: bugün).
final StateProvider<DateTime> selectedDayProvider = StateProvider<DateTime>((Ref ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Takvimde görüntülenen ay.
final StateProvider<DateTime> focusedMonthProvider = StateProvider<DateTime>((Ref ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month);
});
