import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_repository.dart';
import '../models/models.dart';
import 'auth_controller.dart';

/// Supabase okuma/yazma katmanı.
final Provider<SupabaseRepository> repositoryProvider =
    Provider<SupabaseRepository>((Ref ref) => SupabaseRepository(ref.watch(supabaseProvider)));

// =====================================================================
// KULLANICI
// =====================================================================

/// Giriş yapmış kullanıcının id'si. Oturum yoksa null.
final Provider<String?> currentUserIdProvider =
    Provider<String?>((Ref ref) => ref.watch(sessionProvider)?.user.id);

/// Giriş yapmış kullanıcının profili (`profiles` tablosundan).
final Provider<UserProfile?> currentUserProvider = Provider<UserProfile?>((Ref ref) {
  final Map<String, dynamic>? row = ref.watch(myProfileProvider).valueOrNull;
  return row == null ? null : UserProfile.fromRow(row);
});

// =====================================================================
// HALI SAHALAR
// =====================================================================

/// Aktif sahalar, takım sayısıyla birlikte (takım sayısına göre sıralı).
final FutureProvider<List<Pitch>> pitchesProvider =
    FutureProvider<List<Pitch>>((Ref ref) {
  // Oturum değişince yeniden çekilsin.
  ref.watch(sessionProvider);
  return ref.watch(repositoryProvider).fetchPitches();
});

/// Ana sayfa: en çok takım barındıran ilk 3 saha.
final Provider<AsyncValue<List<Pitch>>> popularPitchesProvider =
    Provider<AsyncValue<List<Pitch>>>((Ref ref) {
  return ref.watch(pitchesProvider).whenData(
        (List<Pitch> all) => all.take(3).toList(growable: false),
      );
});

/// Sahalar sekmesindeki arama metni.
final StateProvider<String> pitchSearchQueryProvider = StateProvider<String>((Ref ref) => '');

/// Ada, ilçeye veya adrese göre filtrelenmiş saha listesi.
final Provider<AsyncValue<List<Pitch>>> filteredPitchesProvider =
    Provider<AsyncValue<List<Pitch>>>((Ref ref) {
  final String query = ref.watch(pitchSearchQueryProvider).trim().toLowerCase();

  return ref.watch(pitchesProvider).whenData((List<Pitch> pitches) {
    if (query.isEmpty) return pitches;
    return pitches
        .where((Pitch p) =>
            p.name.toLowerCase().contains(query) ||
            p.district.toLowerCase().contains(query) ||
            p.address.toLowerCase().contains(query))
        .toList(growable: false);
  });
});

/// Tek bir sahayı id'sinden bulur.
final ProviderFamily<AsyncValue<Pitch?>, String> pitchByIdProvider =
    Provider.family<AsyncValue<Pitch?>, String>((Ref ref, String pitchId) {
  return ref.watch(pitchesProvider).whenData(
        (List<Pitch> all) =>
            all.where((Pitch p) => p.id == pitchId).firstOrNull,
      );
});

// =====================================================================
// TAKIMLAR
// =====================================================================

/// Bir sahaya kayıtlı takımlar — puan durumuna göre sıralı.
final FutureProviderFamily<List<Team>, String> teamsForPitchProvider =
    FutureProvider.family<List<Team>, String>((Ref ref, String pitchId) {
  ref.watch(sessionProvider);
  return ref.watch(repositoryProvider).fetchTeamsForPitch(pitchId);
});

/// Kullanıcının kaptanı olduğu takımlar.
final FutureProvider<List<Team>> myTeamsProvider = FutureProvider<List<Team>>((Ref ref) {
  ref.watch(sessionProvider);
  return ref.watch(repositoryProvider).fetchMyTeams();
});

/// Kullanıcının BU sahadaki takımı (yoksa null).
///
/// "MAÇ TEKLİFİ" butonunun görünürlüğü tamamen buna bağlıdır.
final ProviderFamily<Team?, String> myTeamForPitchProvider =
    Provider.family<Team?, String>((Ref ref, String pitchId) {
  final List<Team>? teams = ref.watch(myTeamsProvider).valueOrNull;
  if (teams == null) return null;
  return teams.where((Team t) => t.pitchId == pitchId).firstOrNull;
});

/// Takım oluşturma.
final Provider<Future<Team> Function({
  required String pitchId,
  required String name,
})> createTeamProvider = Provider((Ref ref) {
  return ({
    required String pitchId,
    required String name,
  }) async {
    final Team team = await ref.read(repositoryProvider).createTeam(
          pitchId: pitchId,
          name: name,
        );
    ref.invalidate(myTeamsProvider);
    ref.invalidate(teamsForPitchProvider(pitchId));
    ref.invalidate(pitchesProvider); // takım sayısı değişti
    return team;
  };
});

/// Profildeki telefon numarasını günceller.
///
/// Numara tek kaynaktan yönetiliyor: profil değişince takım ve kaleci
/// kayıtları veritabanı trigger'ıyla kendiliğinden güncelleniyor, bu yüzden
/// burada ilgili tüm sağlayıcılar tazeleniyor.
final Provider<Future<void> Function(String)> updatePhoneProvider =
    Provider<Future<void> Function(String)>((Ref ref) {
  return (String phone) async {
    await ref.read(repositoryProvider).updateMyPhone(phone);
    // currentUserProvider myProfileProvider'dan türüyor; asıl tazelenmesi
    // gereken o.
    ref.invalidate(myProfileProvider);
    ref.invalidate(myTeamsProvider);
    ref.invalidate(myGoalkeeperProvider);
    ref.invalidate(goalkeepersProvider);
    ref.invalidate(pendingMatchesProvider);
  };
});

// =====================================================================
// KALECİLER
// =====================================================================

/// Kaleci sekmesinde seçili ilçe (null = tüm ilçeler).
final StateProvider<String?> selectedDistrictProvider = StateProvider<String?>((Ref ref) => null);

/// Seçili ilçeye göre filtrelenmiş kaleciler (puanı yüksekten düşüğe).
///
/// İlçe filtresi veritabanı tarafında uygulanır (`districts @> {ilçe}`).
final FutureProvider<List<Goalkeeper>> goalkeepersProvider =
    FutureProvider<List<Goalkeeper>>((Ref ref) {
  ref.watch(sessionProvider);
  final String? district = ref.watch(selectedDistrictProvider);
  return ref.watch(repositoryProvider).fetchGoalkeepers(district: district);
});

/// Kullanıcının kendi kaleci profili — yoksa ana sayfadaki CTA görünür.
class MyGoalkeeperController extends AsyncNotifier<Goalkeeper?> {
  @override
  Future<Goalkeeper?> build() {
    ref.watch(sessionProvider);
    return ref.watch(repositoryProvider).fetchMyGoalkeeper();
  }

  Future<void> save({
    required List<String> districts,
    required String about,
    bool isAvailable = true,
  }) async {
    state = const AsyncValue<Goalkeeper?>.loading();
    state = await AsyncValue.guard<Goalkeeper?>(() async {
      final SupabaseRepository repo = ref.read(repositoryProvider);
      await repo.upsertMyGoalkeeper(
        districts: districts,
        about: about,
        isAvailable: isAvailable,
      );
      // Liste ekranı da tazelensin ki kaleci hemen görünsün.
      ref.invalidate(goalkeepersProvider);
      return repo.fetchMyGoalkeeper();
    });
  }

  Future<void> delete() async {
    state = const AsyncValue<Goalkeeper?>.loading();
    state = await AsyncValue.guard<Goalkeeper?>(() async {
      await ref.read(repositoryProvider).deleteMyGoalkeeper();
      ref.invalidate(goalkeepersProvider);
      return null;
    });
  }
}

final AsyncNotifierProvider<MyGoalkeeperController, Goalkeeper?> myGoalkeeperProvider =
    AsyncNotifierProvider<MyGoalkeeperController, Goalkeeper?>(MyGoalkeeperController.new);

// =====================================================================
// MAÇ TEKLİFLERİ
// =====================================================================

/// Kullanıcının takımlarını ilgilendiren, sonuçlanmamış maç teklifleri.
final FutureProvider<List<PendingMatch>> pendingMatchesProvider =
    FutureProvider<List<PendingMatch>>((Ref ref) {
  ref.watch(sessionProvider);
  ref.watch(myTeamsProvider);
  return ref.watch(repositoryProvider).fetchPendingMatches();
});

/// Tamamlanmış maçlar, en yeniden eskiye.
final FutureProvider<List<MatchHistoryEntry>> matchHistoryProvider =
    FutureProvider<List<MatchHistoryEntry>>((Ref ref) {
  ref.watch(sessionProvider);
  ref.watch(myTeamsProvider);
  return ref.watch(repositoryProvider).fetchMatchHistory();
});

/// Maç teklifi akışının tüm aksiyonları.
///
/// Her aksiyon Supabase'deki ilgili RPC'yi çağırır (yetki ve durum
/// geçişleri orada denetlenir), sonra listeleri tazeler.
class MatchActions {
  const MatchActions(this._ref);

  final Ref _ref;

  SupabaseRepository get _repo => _ref.read(repositoryProvider);

  void _refresh() {
    _ref.invalidate(pendingMatchesProvider);
    _ref.invalidate(matchHistoryProvider);
    _ref.invalidate(myTeamsProvider); // G/B/M değişmiş olabilir
    _ref.invalidate(notificationsProvider); // trigger yeni bildirim yazmış olabilir
  }

  Future<void> sendChallenge({
    required String myTeamId,
    required String opponentTeamId,
    String? message,
  }) async {
    await _repo.sendChallenge(
      myTeamId: myTeamId,
      opponentTeamId: opponentTeamId,
      message: message,
    );
    _refresh();
  }

  /// AŞAMA 1 — gelen teklifi kabul et.
  Future<void> accept(String matchId) async {
    await _repo.respondToChallenge(matchId: matchId, accept: true);
    _refresh();
  }

  /// AŞAMA 1 — gelen teklifi reddet.
  Future<void> reject(String matchId) async {
    await _repo.respondToChallenge(matchId: matchId, accept: false);
    _refresh();
  }

  /// AŞAMA 2 — "Maça Hazırım". İki taraf da verince maç kesinleşir.
  Future<void> markReady(String matchId) async {
    await _repo.confirmMatch(matchId);
    _refresh();
  }

  /// AŞAMA 3 — teklifi gönderen takım gün ve saati girer.
  Future<void> setMatchDate(String matchId, DateTime date) async {
    await _repo.scheduleMatch(matchId: matchId, date: date);
    _refresh();
  }

  /// AŞAMA 4 — sonucu bildir; G/B/M trigger ile güncellenir.
  Future<void> reportResult(String matchId, TeamOutcome outcome) async {
    await _repo.reportMatchResult(matchId: matchId, outcome: outcome);
    _refresh();
  }

  /// Gönderilen teklifi geri çek veya maçı iptal et.
  Future<void> cancel(String matchId, {String? reason}) async {
    await _repo.cancelMatch(matchId: matchId, reason: reason);
    _refresh();
  }
}

final Provider<MatchActions> matchActionsProvider =
    Provider<MatchActions>(MatchActions.new);

// =====================================================================
// BİLDİRİMLER
// =====================================================================

/// Kullanıcının bildirimleri (en yeniden eskiye).
final FutureProvider<List<AppNotification>> notificationsProvider =
    FutureProvider<List<AppNotification>>((Ref ref) async {
  // Oturum kapalıysa istek atma.
  if (ref.watch(currentUserIdProvider) == null) return const <AppNotification>[];
  return ref.watch(repositoryProvider).fetchNotifications();
});

/// Ana sayfadaki zil ikonunun rozetinde gösterilen okunmamış sayısı.
final Provider<int> unreadNotificationCountProvider = Provider<int>((Ref ref) {
  final List<AppNotification> all =
      ref.watch(notificationsProvider).valueOrNull ?? const <AppNotification>[];
  return all.where((AppNotification n) => !n.isRead).length;
});

/// Bildirim işlemleri; her işlemden sonra liste yenilenir.
class NotificationActions {
  const NotificationActions(this._ref);

  final Ref _ref;

  SupabaseRepository get _repo => _ref.read(repositoryProvider);

  Future<void> markRead(String id) async {
    await _repo.markNotificationsRead(ids: <String>[id]);
    _ref.invalidate(notificationsProvider);
  }

  Future<void> markAllRead() async {
    await _repo.markNotificationsRead();
    _ref.invalidate(notificationsProvider);
  }

  Future<void> delete(String id) async {
    await _repo.deleteNotification(id);
    _ref.invalidate(notificationsProvider);
  }
}

final Provider<NotificationActions> notificationActionsProvider =
    Provider<NotificationActions>(NotificationActions.new);

// =====================================================================
// TAKVİM (Ana sayfa)
// =====================================================================

/// Planlanmış maçlardan türetilen takvim etkinlikleri.
final Provider<List<CalendarEvent>> calendarEventsProvider =
    Provider<List<CalendarEvent>>((Ref ref) {
  final List<PendingMatch> matches =
      ref.watch(pendingMatchesProvider).valueOrNull ?? const <PendingMatch>[];
  return <CalendarEvent>[
    for (final PendingMatch m in matches)
      if (m.matchDate != null)
        CalendarEvent(
          date: m.matchDate!,
          title: m.opponentTeamName,
          subtitle: m.pitchName,
        ),
  ];
});

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
