import 'package:supabase_flutter/supabase_flutter.dart';

/// Rapor sebepleri. [code] veritabanındaki `reports.reason` kontrolüyle
/// birebir aynı olmalı.
enum ReportReason {
  fakeInfo('fake_info', 'Sahte veya yanıltıcı bilgi'),
  noShow('no_show', 'Maça gelmedi / güvenilmez'),
  abusive('abusive', 'Küfür, hakaret veya taciz'),
  inappropriate('inappropriate', 'Uygunsuz fotoğraf veya içerik'),
  spam('spam', 'Spam veya reklam'),
  other('other', 'Diğer');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;

  /// "Diğer" seçilince ne olduğunun yazılması şart.
  bool get requiresDescription => this == ReportReason.other;
}

/// Raporun uygulamanın neresinden geldiği (`reports.context`).
enum ReportContext {
  goalkeeper('goalkeeper'),
  team('team'),
  match('match');

  const ReportContext(this.code);

  final String code;
}

/// Aynı kişi için incelenmeyi bekleyen bir rapor zaten var.
class DuplicateReportException implements Exception {
  const DuplicateReportException();
}

/// Engellenen bir kullanıcı (Ayarlar → Engellenen kullanıcılar).
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.name,
    required this.blockedAt,
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final DateTime blockedAt;
  final String? avatarUrl;
}

/// Raporlama ve engelleme işlemleri.
///
/// Engellenen kişinin içeriğinin listelerden düşmesi istemcide değil
/// **veritabanında** yapılıyor: `goalkeeper_profiles` ve `teams_with_stats`
/// view'ları `is_hidden_from_me()` ile filtreli. Böylece her liste sorgusu
/// kendiliğinden doğru sonucu veriyor ve uygulamayı atlayıp API'yi
/// doğrudan çağıran biri de engellendiği kişiyi göremiyor.
class ModerationRepository {
  ModerationRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitReport({
    required String reportedUserId,
    required ReportContext context,
    required ReportReason reason,
    String? description,
    String? matchId,
  }) async {
    final String text = description?.trim() ?? '';
    try {
      // reporter_id yazılmıyor: veritabanında varsayılanı auth.uid().
      await _client.from('reports').insert(<String, dynamic>{
        'reported_user_id': reportedUserId,
        'context': context.code,
        'reason': reason.code,
        if (text.isNotEmpty) 'description': text,
        if (matchId != null && matchId.isNotEmpty) 'reported_match_id': matchId,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const DuplicateReportException();
      rethrow;
    }
  }

  /// Engeller; aradaki devam eden maçlar iptal edilir. İptal edilen maç
  /// sayısını döndürür.
  Future<int> blockUser(String userId) async {
    final dynamic result = await _client.rpc<dynamic>(
      'block_user',
      params: <String, dynamic>{'p_user_id': userId},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  Future<void> unblockUser(String userId) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('blocked_users')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', userId);
  }

  Future<List<BlockedUser>> fetchBlockedUsers() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return const <BlockedUser>[];

    final List<Map<String, dynamic>> rows = await _client
        .from('blocked_users')
        .select('blocked_id, created_at, '
            'blocked:profiles!blocked_users_blocked_id_fkey(first_name, last_name, avatar_url)')
        .eq('blocker_id', uid)
        .order('created_at', ascending: false);

    return rows.map((Map<String, dynamic> row) {
      final Map<String, dynamic>? p = row['blocked'] as Map<String, dynamic>?;
      final String name = <String?>[
        p?['first_name'] as String?,
        p?['last_name'] as String?,
      ].whereType<String>().join(' ').trim();
      return BlockedUser(
        userId: row['blocked_id'] as String,
        name: name.isEmpty ? 'Kullanıcı' : name,
        avatarUrl: p?['avatar_url'] as String?,
        blockedAt:
            DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
    }).toList(growable: false);
  }
}
