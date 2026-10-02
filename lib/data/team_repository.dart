import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_repository.dart';

/// Takım kadroları, maç kadrosu, skor ve oyuncu istatistikleri.
///
/// Yazma işlemlerinin tamamı RPC: kadro en az 7 kişi, maç kadrosu tam
/// kişi sayısı kadar, gol toplamı skoru geçemez gibi kurallar veritabanında
/// denetleniyor.
class TeamRepository {
  TeamRepository(this._client);

  final SupabaseClient _client;

  // -------------------------------------------------------------------
  // TAKIM + KADRO
  // -------------------------------------------------------------------

  /// Takımı kadrosuyla birlikte tek işlemde kurar.
  Future<Team> createTeamWithRoster({
    required String pitchId,
    required String name,
    required List<RosterEntry> players,
  }) async {
    final dynamic row = await _client.rpc<dynamic>(
      'create_team_with_roster',
      params: <String, dynamic>{
        'p_pitch_id': pitchId,
        'p_name': name.trim(),
        'p_players': players.map((RosterEntry p) => p.toJson()).toList(),
      },
    );
    return SupabaseRepository.teamFromRow(row as Map<String, dynamic>);
  }

  /// Kadroyu kaydeder. Listede olmayan oyuncular pasifleşir (geçmiş
  /// istatistikleri korunur).
  Future<void> saveRoster(String teamId, List<RosterEntry> players) {
    return _client.rpc<dynamic>('save_team_roster', params: <String, dynamic>{
      'p_team_id': teamId,
      'p_players': players.map((RosterEntry p) => p.toJson()).toList(),
    });
  }

  /// Takım profili başlığı. Engellenen/banlanan kullanıcının takımı için null.
  Future<Team?> fetchTeam(String teamId) async {
    final Map<String, dynamic>? row = await _client
        .from('teams_with_stats')
        .select()
        .eq('id', teamId)
        .maybeSingle();
    return row == null ? null : SupabaseRepository.teamFromRow(row);
  }

  /// Aktif kadro, oyuncu başına maç / gol / asist ile.
  Future<List<TeamPlayer>> fetchRoster(String teamId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('team_player_stats')
        .select()
        .eq('team_id', teamId)
        .eq('is_active', true)
        .order('first_name')
        .order('last_name');
    return rows.map(TeamPlayer.fromRow).toList(growable: false);
  }

  /// Herhangi bir takımın tamamlanmış maçları (skorlu).
  Future<List<MatchHistoryEntry>> fetchTeamHistory(String teamId) async {
    final List<dynamic> rows = await _client.rpc<List<dynamic>>(
      'get_team_match_history',
      params: <String, dynamic>{'p_team_id': teamId, 'p_limit': 50},
    );
    return rows
        .map((dynamic r) => MatchHistoryEntry.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Sahanın gol ([byAssists] false) ya da asist krallığı.
  Future<List<LeaderboardEntry>> fetchPitchLeaders(
    String pitchId, {
    required bool byAssists,
    int limit = 10,
  }) async {
    final String column = byAssists ? 'assists' : 'goals';
    final List<Map<String, dynamic>> rows = await _client
        .from('pitch_player_stats')
        .select()
        .eq('pitch_id', pitchId)
        .gt(column, 0)
        .order(column, ascending: false)
        // Eşitlikte daha az maçta yapan önde.
        .order('appearances')
        .limit(limit);
    return rows.map(LeaderboardEntry.fromRow).toList(growable: false);
  }

  // -------------------------------------------------------------------
  // MAÇ KADROSU + SKOR
  // -------------------------------------------------------------------

  /// Kendi takımımızın maça çıkacak oyuncuları (tam kişi sayısı kadar).
  Future<void> setLineup(String matchId, List<String> playerIds) {
    return _client.rpc<dynamic>('set_match_lineup', params: <String, dynamic>{
      'p_match_id': matchId,
      'p_player_ids': playerIds,
    });
  }

  /// Teklifi gönderen kaptan skoru ve kendi oyuncularının gol/asistini girer.
  Future<void> reportScore({
    required String matchId,
    required int myScore,
    required int opponentScore,
    required Map<String, PlayerMatchStats> stats,
  }) {
    return _client.rpc<dynamic>('report_match_score', params: <String, dynamic>{
      'p_match_id': matchId,
      'p_my_score': myScore,
      'p_opponent_score': opponentScore,
      'p_stats': _statsJson(stats),
    });
  }

  /// Maç bittikten sonra (7 gün içinde) gol/asist girişi ya da düzeltmesi.
  Future<void> savePlayerStats(String matchId, Map<String, PlayerMatchStats> stats) {
    return _client.rpc<dynamic>('save_match_player_stats', params: <String, dynamic>{
      'p_match_id': matchId,
      'p_stats': _statsJson(stats),
    });
  }

  static List<Map<String, dynamic>> _statsJson(Map<String, PlayerMatchStats> stats) =>
      <Map<String, dynamic>>[
        for (final MapEntry<String, PlayerMatchStats> e in stats.entries)
          <String, dynamic>{
            'player_id': e.key,
            'goals': e.value.goals,
            'assists': e.value.assists,
          },
      ];

  /// Skor ve iki takımın kadrosu.
  Future<MatchDetail?> fetchMatchDetail(String matchId) async {
    final Map<String, dynamic>? row = await _client
        .from('matches')
        .select('''
          id, status, match_date, team_size, challenger_score, opponent_score,
          result_reported_at, challenger_team_id, opponent_team_id,
          challenger:teams!matches_challenger_team_id_fkey(id, name, captain_id),
          opponent:teams!matches_opponent_team_id_fkey(id, name, captain_id),
          pitch:pitches(name),
          lineups:match_lineups(team_id, player_id, first_name, last_name, slot, goals, assists)
        ''')
        .eq('id', matchId)
        .maybeSingle();
    if (row == null) return null;

    final List<LineupPlayer> lineups = ((row['lineups'] as List<dynamic>?) ?? <dynamic>[])
        .map((dynamic l) => LineupPlayer.fromRow(l as Map<String, dynamic>))
        .toList()
      ..sort((LineupPlayer a, LineupPlayer b) => a.slot.compareTo(b.slot));

    MatchSide side(String key, String scoreKey) {
      final Map<String, dynamic>? team = row[key] as Map<String, dynamic>?;
      final String teamId = (team?['id'] as String?) ?? '';
      return MatchSide(
        teamId: teamId,
        teamName: (team?['name'] as String?) ?? '—',
        captainId: (team?['captain_id'] as String?) ?? '',
        score: (row[scoreKey] as num?)?.toInt(),
        lineup: lineups.where((LineupPlayer p) => p.teamId == teamId).toList(growable: false),
      );
    }

    DateTime? parse(String key) =>
        DateTime.tryParse(row[key] as String? ?? '')?.toLocal();

    return MatchDetail(
      id: row['id'] as String,
      status: row['status'] == 'completed' ? MatchStatus.completed : MatchStatus.scheduled,
      pitchName: ((row['pitch'] as Map<String, dynamic>?)?['name'] as String?) ?? '—',
      challenger: side('challenger', 'challenger_score'),
      opponent: side('opponent', 'opponent_score'),
      matchDate: parse('match_date'),
      teamSize: (row['team_size'] as num?)?.toInt(),
      reportedAt: parse('result_reported_at'),
    );
  }
}

/// Bir oyuncunun tek maçtaki gol / asisti (giriş formu için).
class PlayerMatchStats {
  const PlayerMatchStats({this.goals = 0, this.assists = 0});

  final int goals;
  final int assists;

  PlayerMatchStats copyWith({int? goals, int? assists}) => PlayerMatchStats(
        goals: goals ?? this.goals,
        assists: assists ?? this.assists,
      );
}
