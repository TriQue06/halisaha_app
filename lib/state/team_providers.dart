import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/team_repository.dart';
import '../models/models.dart';
import 'app_providers.dart';
import 'auth_controller.dart';

final Provider<TeamRepository> teamRepositoryProvider =
    Provider<TeamRepository>((Ref ref) => TeamRepository(ref.watch(supabaseProvider)));

/// Takım profili başlığı (engellenen takım için null).
final AutoDisposeFutureProviderFamily<Team?, String> teamByIdProvider =
    FutureProvider.autoDispose.family<Team?, String>((Ref ref, String teamId) {
  ref.watch(sessionProvider);
  return ref.watch(teamRepositoryProvider).fetchTeam(teamId);
});

/// Takımın aktif kadrosu ve oyuncu istatistikleri.
final AutoDisposeFutureProviderFamily<List<TeamPlayer>, String> teamRosterProvider =
    FutureProvider.autoDispose.family<List<TeamPlayer>, String>((Ref ref, String teamId) {
  ref.watch(sessionProvider);
  return ref.watch(teamRepositoryProvider).fetchRoster(teamId);
});

/// Herhangi bir takımın maç geçmişi.
final AutoDisposeFutureProviderFamily<List<MatchHistoryEntry>, String> teamHistoryProvider =
    FutureProvider.autoDispose.family<List<MatchHistoryEntry>, String>(
        (Ref ref, String teamId) {
  ref.watch(sessionProvider);
  return ref.watch(teamRepositoryProvider).fetchTeamHistory(teamId);
});

/// Maç detayı: skor + iki takımın kadrosu.
final AutoDisposeFutureProviderFamily<MatchDetail?, String> matchDetailProvider =
    FutureProvider.autoDispose.family<MatchDetail?, String>((Ref ref, String matchId) {
  ref.watch(sessionProvider);
  return ref.watch(teamRepositoryProvider).fetchMatchDetail(matchId);
});

/// Saha krallık listesi anahtarı.
typedef PitchLeadersKey = ({String pitchId, bool byAssists});

/// Sahanın gol / asist krallığı (ilk 10).
final AutoDisposeFutureProviderFamily<List<LeaderboardEntry>, PitchLeadersKey>
    pitchLeadersProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, PitchLeadersKey>(
        (Ref ref, PitchLeadersKey key) {
  ref.watch(sessionProvider);
  return ref
      .watch(teamRepositoryProvider)
      .fetchPitchLeaders(key.pitchId, byAssists: key.byAssists);
});

/// Kadro, maç kadrosu ve istatistik aksiyonları; sonrasında ilgili
/// listeleri tazeler.
class TeamActions {
  const TeamActions(this._ref);

  final Ref _ref;

  TeamRepository get _repo => _ref.read(teamRepositoryProvider);

  Future<Team> createTeam({
    required String pitchId,
    required String name,
    required List<RosterEntry> players,
  }) async {
    final Team team = await _repo.createTeamWithRoster(
      pitchId: pitchId,
      name: name,
      players: players,
    );
    _ref.invalidate(myTeamsProvider);
    _ref.invalidate(teamsForPitchProvider(pitchId));
    _ref.invalidate(pitchesProvider); // takım sayısı değişti
    return team;
  }

  Future<void> saveRoster(String teamId, List<RosterEntry> players) async {
    await _repo.saveRoster(teamId, players);
    _ref.invalidate(teamRosterProvider(teamId));
  }

  Future<void> setLineup(String matchId, List<String> playerIds) async {
    await _repo.setLineup(matchId, playerIds);
    _ref.invalidate(pendingMatchesProvider);
    _ref.invalidate(matchDetailProvider(matchId));
  }

  Future<void> reportScore({
    required String matchId,
    required int myScore,
    required int opponentScore,
    required Map<String, PlayerMatchStats> stats,
  }) async {
    await _repo.reportScore(
      matchId: matchId,
      myScore: myScore,
      opponentScore: opponentScore,
      stats: stats,
    );
    _afterResult(matchId);
  }

  Future<void> savePlayerStats(String matchId, Map<String, PlayerMatchStats> stats) async {
    await _repo.savePlayerStats(matchId, stats);
    _afterResult(matchId);
  }

  void _afterResult(String matchId) {
    _ref.invalidate(pendingMatchesProvider);
    _ref.invalidate(matchHistoryProvider);
    _ref.invalidate(myTeamsProvider); // G/B/M değişti
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(matchDetailProvider(matchId));
    _ref.invalidate(teamRosterProvider);
    _ref.invalidate(teamHistoryProvider);
    _ref.invalidate(pitchLeadersProvider);
    _ref.invalidate(teamsForPitchProvider);
  }
}

final Provider<TeamActions> teamActionsProvider = Provider<TeamActions>(TeamActions.new);
