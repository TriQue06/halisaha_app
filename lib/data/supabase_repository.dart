import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Supabase okuma/yazma işlemleri.
///
/// Ekranlar bu sınıfı doğrudan çağırmaz; provider'lar üzerinden erişir.
/// Böylece UI hangi tablodan ne geldiğini bilmek zorunda kalmaz.
class SupabaseRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;

  // -------------------------------------------------------------------
  // HALI SAHALAR
  // -------------------------------------------------------------------

  /// Aktif sahalar, takım sayısıyla birlikte.
  ///
  /// `pitches_with_team_count` view'ı takım sayısını hesaplayarak verir;
  /// "En popüler sahalar" sıralaması buna dayanır.
  Future<List<Pitch>> fetchPitches() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('pitches_with_team_count')
        .select()
        .eq('is_active', true)
        .order('team_count', ascending: false)
        .order('name');

    return rows.map(Pitch.fromRow).toList(growable: false);
  }

  // -------------------------------------------------------------------
  // KALECİLER
  // -------------------------------------------------------------------

  /// Kaleci listesi. [district] verilirse yalnızca o ilçede oynayanlar.
  ///
  /// `districts` bir text[] kolonu olduğu için ilçe filtresi `contains`
  /// (PostgREST `cs`) ile yapılır.
  Future<List<Goalkeeper>> fetchGoalkeepers({String? district}) async {
    var query = _client.from('goalkeeper_profiles').select();

    if (district != null && district.isNotEmpty) {
      query = query.contains('districts', <String>[district]);
    }

    final List<Map<String, dynamic>> rows =
        await query.order('rating_avg', ascending: false);

    return rows.map(Goalkeeper.fromRow).toList(growable: false);
  }

  /// Giriş yapmış kullanıcının kaleci profili (yoksa null).
  Future<Goalkeeper?> fetchMyGoalkeeper() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final Map<String, dynamic>? row = await _client
        .from('goalkeeper_profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    return row == null ? null : Goalkeeper.fromRow(row);
  }

  /// Kaleci profilini oluşturur veya günceller.
  ///
  /// `goalkeepers.id` doğrudan `profiles.id`'dir; bu yüzden upsert
  /// çakışma kolonu olarak id kullanılır. `rating_avg` ve `rating_count`
  /// yazılmaz — onları puanlama trigger'ı yönetir.
  ///
  /// `contact_phone` gönderilmez: veritabanı trigger'ı onu profildeki
  /// numaradan doldurur (tek telefon kaynağı kuralı).
  Future<void> upsertMyGoalkeeper({
    required List<String> districts,
    required String about,
    required bool isAvailable,
  }) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Kaleci profili için oturum gerekli.');
    }

    await _client.from('goalkeepers').upsert(<String, dynamic>{
      'id': uid,
      'districts': districts,
      'about': about,
      // contact_phone yazılmıyor; trigger profilden dolduruyor.
      'contact_phone': '',
      'is_available': isAvailable,
    });
  }

  /// Profildeki telefon numarasını günceller ve normalize edilmiş hâlini
  /// döndürür. Takım ve kaleci kayıtları trigger ile kendiliğinden
  /// güncellenir.
  Future<String> updateMyPhone(String phone) async {
    final dynamic result = await _client.rpc<dynamic>(
      'update_my_phone',
      params: <String, dynamic>{'p_phone': phone},
    );
    return result as String? ?? phone;
  }

  Future<void> deleteMyGoalkeeper() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('goalkeepers').delete().eq('id', uid);
  }

  /// Kaleciye 1-5 arası puan verir (aynı kullanıcı için upsert).
  Future<void> rateGoalkeeper({
    required String goalkeeperId,
    required int rating,
    String? comment,
  }) async {
    await _client.rpc<void>('rate_goalkeeper', params: <String, dynamic>{
      'p_goalkeeper_id': goalkeeperId,
      'p_rating': rating,
      'p_comment': comment,
    });
  }

  // -------------------------------------------------------------------
  // TAKIMLAR
  // -------------------------------------------------------------------

  Future<List<Team>> fetchTeamsForPitch(String pitchId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('teams')
        .select()
        .eq('pitch_id', pitchId)
        .eq('is_active', true);

    final List<Team> teams = rows.map(_teamFromRow).toList()
      ..sort((Team a, Team b) => b.points.compareTo(a.points));
    return teams;
  }

  Future<List<Team>> fetchMyTeams() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return const <Team>[];

    final List<Map<String, dynamic>> rows =
        await _client.from('teams').select().eq('captain_id', uid);

    return rows.map(_teamFromRow).toList(growable: false);
  }

  /// Takım kurar. İletişim numarası gönderilmez; trigger profildeki
  /// numarayı yazar.
  Future<Team> createTeam({
    required String pitchId,
    required String name,
  }) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Takım kurmak için oturum gerekli.');
    }

    final Map<String, dynamic> row = await _client
        .from('teams')
        .insert(<String, dynamic>{
          'pitch_id': pitchId,
          'captain_id': uid,
          'name': name,
          // contact_phone yazılmıyor; trigger profilden dolduruyor.
          'contact_phone': '',
        })
        .select()
        .single();

    return _teamFromRow(row);
  }

  // -------------------------------------------------------------------
  // MAÇ TEKLİFLERİ
  // -------------------------------------------------------------------

  /// Takımların isim/iletişim/kaptan bilgisini de getiren gömülü seçim.
  ///
  /// Yabancı anahtar adları PostgREST'e hangi ilişki üzerinden gideceğini
  /// söyler; `matches` tablosunda `teams`'e iki ayrı FK olduğu için bu şart.
  static const String _matchSelect = '''
    id, status, responded_at, challenger_confirmed_at, opponent_confirmed_at,
    match_date, challenger_team_id, opponent_team_id,
    challenger:teams!matches_challenger_team_id_fkey(
      id, name, contact_phone,
      captain:profiles!teams_captain_id_fkey(first_name, last_name)
    ),
    opponent:teams!matches_opponent_team_id_fkey(
      id, name, contact_phone,
      captain:profiles!teams_captain_id_fkey(first_name, last_name)
    ),
    pitch:pitches(name)
  ''';

  /// Kullanıcının takımlarını ilgilendiren, henüz sonuçlanmamış maçlar.
  ///
  /// Hem gönderdiğimiz hem bize gelen teklifler tek listede döner;
  /// hangisinin hangisi olduğu [PendingMatch.isChallenger] ile ayrılır.
  Future<List<PendingMatch>> fetchPendingMatches() async {
    final List<Team> myTeams = await fetchMyTeams();
    if (myTeams.isEmpty) return const <PendingMatch>[];

    final Set<String> myTeamIds = myTeams.map((Team t) => t.id).toSet();
    final String idList = myTeamIds.join(',');

    final List<Map<String, dynamic>> rows = await _client
        .from('matches')
        .select(_matchSelect)
        .or('challenger_team_id.in.($idList),opponent_team_id.in.($idList)')
        .inFilter('status', <String>['pending', 'accepted', 'mutually_agreed', 'scheduled'])
        .order('created_at', ascending: false);

    return rows
        .map((Map<String, dynamic> row) => _pendingMatchFromRow(row, myTeamIds))
        .toList(growable: false);
  }

  /// Tamamlanmış maçlar, en yeniden eskiye.
  Future<List<MatchHistoryEntry>> fetchMatchHistory() async {
    final List<Team> myTeams = await fetchMyTeams();
    if (myTeams.isEmpty) return const <MatchHistoryEntry>[];

    final List<MatchHistoryEntry> all = <MatchHistoryEntry>[];
    for (final Team team in myTeams) {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'get_team_match_history',
        params: <String, dynamic>{'p_team_id': team.id, 'p_limit': 50},
      );

      for (final dynamic raw in rows) {
        final Map<String, dynamic> row = raw as Map<String, dynamic>;
        all.add(
          MatchHistoryEntry(
            id: row['match_id'] as String,
            opponentName: (row['opponent_name'] as String?) ?? '—',
            pitchName: (row['pitch_name'] as String?) ?? '—',
            playedAt: DateTime.tryParse(row['played_at'] as String? ?? '') ?? DateTime.now(),
            outcome: switch (row['outcome'] as String?) {
              'win' => TeamOutcome.win,
              'loss' => TeamOutcome.loss,
              _ => TeamOutcome.draw,
            },
          ),
        );
      }
    }

    all.sort((MatchHistoryEntry a, MatchHistoryEntry b) => b.playedAt.compareTo(a.playedAt));
    return all;
  }

  /// Maç teklifi gönderir.
  Future<void> sendChallenge({
    required String myTeamId,
    required String opponentTeamId,
    String? message,
  }) {
    return _client.rpc<dynamic>('challenge_team', params: <String, dynamic>{
      'p_challenger_team_id': myTeamId,
      'p_opponent_team_id': opponentTeamId,
      'p_message': message,
    });
  }

  /// Gelen teklifi kabul eder veya reddeder (yalnızca teklif edilen takım).
  Future<void> respondToChallenge({required String matchId, required bool accept}) {
    return _client.rpc<dynamic>('respond_to_challenge', params: <String, dynamic>{
      'p_match_id': matchId,
      'p_accept': accept,
    });
  }

  /// "Maça Hazırım" onayı. İki taraf da verince maç kesinleşir.
  Future<void> confirmMatch(String matchId) {
    return _client.rpc<dynamic>('confirm_match', params: <String, dynamic>{
      'p_match_id': matchId,
    });
  }

  /// Maç gün ve saatini kaydeder (yalnızca teklifi gönderen takım).
  Future<void> scheduleMatch({required String matchId, required DateTime date}) {
    return _client.rpc<dynamic>('schedule_match', params: <String, dynamic>{
      'p_match_id': matchId,
      'p_match_date': date.toUtc().toIso8601String(),
    });
  }

  /// Sonucu bildirir; trigger iki takımın da G/B/M değerlerini günceller.
  Future<void> reportMatchResult({
    required String matchId,
    required TeamOutcome outcome,
  }) {
    return _client.rpc<dynamic>('report_match_result', params: <String, dynamic>{
      'p_match_id': matchId,
      'p_outcome': switch (outcome) {
        TeamOutcome.win => 'won',
        TeamOutcome.draw => 'draw',
        TeamOutcome.loss => 'lost',
      },
    });
  }

  /// Teklifi geri çeker veya maçı iptal eder.
  Future<void> cancelMatch({required String matchId, String? reason}) {
    return _client.rpc<dynamic>('cancel_match', params: <String, dynamic>{
      'p_match_id': matchId,
      'p_reason': reason,
    });
  }

  // -------------------------------------------------------------------
  // BİLDİRİMLER
  // -------------------------------------------------------------------

  /// Kullanıcının bildirimleri, en yeniden eskiye.
  ///
  /// RLS zaten `user_id = auth.uid()` filtresi uyguluyor; ayrıca filtre
  /// vermeye gerek yok.
  Future<List<AppNotification>> fetchNotifications({int limit = 100}) async {
    final List<dynamic> rows = await _client
        .from('notifications')
        .select('id, type, title, body, is_read, created_at, match_id')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromRow)
        .toList(growable: false);
  }

  /// Belirtilen bildirimleri okundu işaretler; [ids] boşsa tümünü işaretler.
  Future<void> markNotificationsRead({List<String>? ids}) {
    return _client.rpc<dynamic>('mark_notifications_read', params: <String, dynamic>{
      'p_ids': ids,
    });
  }

  /// Bildirimi kalıcı olarak siler (RLS: yalnızca kendi bildirimi).
  Future<void> deleteNotification(String id) {
    return _client.from('notifications').delete().eq('id', id);
  }

  /// Veritabanı satırını UI modeline çevirir.
  ///
  /// Kritik nokta: "biz" ve "rakip" alanları, oturumdaki kullanıcının
  /// takımına göre belirlenir. Teklifi gönderen tarafta challenger biziz,
  /// alan tarafta opponent biziz — bu ayrım yapılmazsa iki cihazda da
  /// aynı isim görünür.
  static PendingMatch _pendingMatchFromRow(
    Map<String, dynamic> row,
    Set<String> myTeamIds,
  ) {
    final bool isChallenger = myTeamIds.contains(row['challenger_team_id'] as String);

    final Map<String, dynamic>? mine =
        (isChallenger ? row['challenger'] : row['opponent']) as Map<String, dynamic>?;
    final Map<String, dynamic>? other =
        (isChallenger ? row['opponent'] : row['challenger']) as Map<String, dynamic>?;

    final Map<String, dynamic>? otherCaptain = other?['captain'] as Map<String, dynamic>?;
    final String captainName = <String?>[
      otherCaptain?['first_name'] as String?,
      otherCaptain?['last_name'] as String?,
    ].whereType<String>().join(' ').trim();

    DateTime? parse(String key) {
      final String? value = row[key] as String?;
      return value == null ? null : DateTime.tryParse(value)?.toLocal();
    }

    return PendingMatch(
      id: row['id'] as String,
      myTeamName: (mine?['name'] as String?) ?? 'Takımım',
      opponentTeamName: (other?['name'] as String?) ?? 'Rakip',
      opponentTeamId: (isChallenger
              ? row['opponent_team_id']
              : row['challenger_team_id']) as String? ??
          '',
      opponentPhone: (other?['contact_phone'] as String?) ?? '',
      opponentCaptainName: captainName.isEmpty ? 'Takım kaptanı' : captainName,
      pitchName: ((row['pitch'] as Map<String, dynamic>?)?['name'] as String?) ?? '—',
      status: switch (row['status'] as String?) {
        'pending' => MatchStatus.pending,
        'accepted' => MatchStatus.accepted,
        'mutually_agreed' => MatchStatus.mutuallyAgreed,
        'scheduled' => MatchStatus.scheduled,
        'completed' => MatchStatus.completed,
        'rejected' => MatchStatus.rejected,
        'auto_cancelled' => MatchStatus.autoCancelled,
        _ => MatchStatus.cancelled,
      },
      isChallenger: isChallenger,
      // Onay damgaları taraflara göre eşlenir.
      myTeamReady: isChallenger
          ? row['challenger_confirmed_at'] != null
          : row['opponent_confirmed_at'] != null,
      opponentReady: isChallenger
          ? row['opponent_confirmed_at'] != null
          : row['challenger_confirmed_at'] != null,
      acceptedAt: parse('responded_at'),
      matchDate: parse('match_date'),
    );
  }

  static Team _teamFromRow(Map<String, dynamic> row) {
    return Team(
      id: row['id'] as String,
      pitchId: row['pitch_id'] as String,
      captainId: row['captain_id'] as String,
      name: (row['name'] as String?) ?? '',
      contactPhone: (row['contact_phone'] as String?) ?? '',
      wins: (row['wins'] as num?)?.toInt() ?? 0,
      draws: (row['draws'] as num?)?.toInt() ?? 0,
      losses: (row['losses'] as num?)?.toInt() ?? 0,
    );
  }
}
