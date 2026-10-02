import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moderation_repository.dart';
import 'app_providers.dart';
import 'auth_controller.dart';

final Provider<ModerationRepository> moderationRepositoryProvider =
    Provider<ModerationRepository>(
        (Ref ref) => ModerationRepository(ref.watch(supabaseProvider)));

/// Ayarlar → Engellenen kullanıcılar listesi.
final AutoDisposeFutureProvider<List<BlockedUser>> blockedUsersProvider =
    FutureProvider.autoDispose<List<BlockedUser>>((Ref ref) {
  ref.watch(sessionProvider);
  return ref.watch(moderationRepositoryProvider).fetchBlockedUsers();
});

/// Raporlama ve engelleme aksiyonları.
///
/// Engelleme/engel kaldırma sonrası kullanıcı içeren tüm listeler
/// tazeleniyor; filtreyi veritabanı uyguladığı için yeniden çekmek yeterli.
class ModerationActions {
  const ModerationActions(this._ref);

  final Ref _ref;

  ModerationRepository get _repo => _ref.read(moderationRepositoryProvider);

  Future<void> report({
    required String reportedUserId,
    required ReportContext context,
    required ReportReason reason,
    String? description,
    String? matchId,
  }) {
    return _repo.submitReport(
      reportedUserId: reportedUserId,
      context: context,
      reason: reason,
      description: description,
      matchId: matchId,
    );
  }

  /// İptal edilen maç sayısını döndürür.
  Future<int> block(String userId) async {
    final int cancelled = await _repo.blockUser(userId);
    _refreshLists();
    return cancelled;
  }

  Future<void> unblock(String userId) async {
    await _repo.unblockUser(userId);
    _refreshLists();
  }

  void _refreshLists() {
    _ref.invalidate(goalkeepersProvider);
    _ref.invalidate(teamsForPitchProvider);
    _ref.invalidate(pendingMatchesProvider);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(blockedUsersProvider);
  }
}

final Provider<ModerationActions> moderationActionsProvider =
    Provider<ModerationActions>(ModerationActions.new);
