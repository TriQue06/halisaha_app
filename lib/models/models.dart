import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// =====================================================================
// ENUM'LAR  (Supabase şemasındaki enum tipleriyle birebir eşleşir)
// =====================================================================

/// Maçın veritabanındaki yaşam döngüsü.
enum MatchStatus {
  pending, // A meydan okudu, B cevap bekliyor
  rejected, // B reddetti
  accepted, // B kabul etti -> "Maça Hazırım" aşaması (7 günlük sayaç)
  mutuallyAgreed, // iki taraf da "Maça Hazırım" dedi -> iletişim açılır
  scheduled, // meydan okuyan takım gün/saat girdi
  completed, // sonuç girildi
  cancelled,
  autoCancelled, // 1 hafta doldu, sistem iptal etti
}

/// Maç sonucu — her zaman **meydan okuyan** takım perspektifinden tutulur.
enum MatchResult { challengerWon, draw, challengerLost }

/// Takımın kendi perspektifinden sonuç (G / B / M rozetleri için).
enum TeamOutcome {
  win('G'),
  draw('B'),
  loss('M');

  const TeamOutcome(this.shortLabel);
  final String shortLabel;
}

/// "Bekleyen Maçlar" kartının hangi aksiyonu göstereceğini belirleyen aşama.
///
/// 4 aşamalı onay akışı:
///  1. [invitationReceived] / [invitationSent] -> Kabul & Reddet
///  2. [readinessPending]                     -> "Maça Hazırım"
///  3. [confirmed]                            -> İletişim bilgisi açılır
///  4. [awaitingResult]                       -> "Sonucu Gir"
enum PendingMatchStage {
  /// 1a. Bize meydan okundu: Kabul / Reddet butonları.
  invitationReceived,

  /// 1b. Biz meydan okuduk: rakibin yanıtını bekliyoruz.
  invitationSent,

  /// 2. Kabul edildi; iki tarafın da "Maça Hazırım" demesi gerekiyor.
  readinessPending,

  /// 3. İki taraf da hazır; iletişim bilgileri açık, tarih bekleniyor/belli.
  confirmed,

  /// 4. Maç saati + 1 saat geçti; sonuç girilebilir.
  awaitingResult,

  /// Süre dolduğu için sistem tarafından iptal edildi.
  expired,
}

// =====================================================================
// MODELLER
// =====================================================================

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.birthDate,
    this.avatarUrl,
    this.district,
  });

  /// Supabase `profiles` tablosundan gelen satırı modele çevirir.
  factory UserProfile.fromRow(Map<String, dynamic> row) {
    final String? birth = row['birth_date'] as String?;
    return UserProfile(
      id: row['id'] as String,
      firstName: (row['first_name'] as String?)?.trim() ?? '',
      lastName: (row['last_name'] as String?)?.trim() ?? '',
      phone: (row['phone'] as String?) ?? '',
      birthDate: birth == null ? null : DateTime.tryParse(birth),
      avatarUrl: (row['avatar_url'] as String?)?.isNotEmpty ?? false
          ? row['avatar_url'] as String
          : null,
      district: row['district'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String phone;

  /// Google ve telefon girişinde gelmeyebilir; profil tamamlanana kadar null.
  final DateTime? birthDate;
  final String? avatarUrl;
  final String? district;

  String get fullName => '$firstName $lastName'.trim();

  /// Doğum tarihinden hesaplanan yaş; tarih yoksa null.
  int? get age {
    final DateTime? birth = birthDate;
    if (birth == null) return null;

    final DateTime now = DateTime.now();
    int years = now.year - birth.year;
    final bool hadBirthday =
        now.month > birth.month || (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthday) years--;
    return years;
  }
}

@immutable
class Pitch {
  const Pitch({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.phone,
    required this.teamCount,
    this.imageUrl,
    this.pricePerHour,
    this.isIndoor = false,
    this.hasParking = false,
    this.hasShower = false,
    this.description = '',
  });

  /// `pitches_with_team_count` view'ından gelen satırı modele çevirir.
  factory Pitch.fromRow(Map<String, dynamic> row) {
    return Pitch(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      district: (row['district'] as String?) ?? '',
      address: (row['address'] as String?) ?? '',
      phone: (row['phone'] as String?) ?? '',
      teamCount: (row['team_count'] as num?)?.toInt() ?? 0,
      imageUrl: row['image_url'] as String?,
      pricePerHour: (row['price_per_hour'] as num?)?.toDouble(),
      isIndoor: (row['is_indoor'] as bool?) ?? false,
      hasParking: (row['has_parking'] as bool?) ?? false,
      hasShower: (row['has_shower'] as bool?) ?? false,
      description: (row['description'] as String?) ?? '',
    );
  }

  final String id;
  final String name;
  final String district;
  final String address;
  final String phone;

  /// Sahaya kayıtlı takım sayısı — "En popüler sahalar" sıralaması buna göre.
  final int teamCount;
  final String? imageUrl;
  final double? pricePerHour;
  final bool isIndoor;
  final bool hasParking;
  final bool hasShower;
  final String description;

  List<String> get features => <String>[
        if (isIndoor) 'Kapalı Saha' else 'Açık Saha',
        if (hasParking) 'Otopark',
        if (hasShower) 'Duş & Soyunma',
      ];
}

@immutable
class Team {
  const Team({
    required this.id,
    required this.pitchId,
    required this.captainId,
    required this.name,
    required this.contactPhone,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
  });

  final String id;
  final String pitchId;
  final String captainId;
  final String name;
  final String contactPhone;
  final int wins; // G
  final int draws; // B
  final int losses; // M

  int get played => wins + draws + losses;
  int get points => wins * 3 + draws;
}

@immutable
class Goalkeeper {
  const Goalkeeper({
    required this.id,
    required this.fullName,
    required this.age,
    required this.districts,
    required this.about,
    required this.phone,
    required this.rating,
    required this.ratingCount,
    this.avatarUrl,
    this.isAvailable = true,
  });

  /// `goalkeeper_profiles` view'ından gelen satırı modele çevirir.
  factory Goalkeeper.fromRow(Map<String, dynamic> row) {
    final String name = <String?>[
      row['first_name'] as String?,
      row['last_name'] as String?,
    ].whereType<String>().join(' ').trim();

    return Goalkeeper(
      id: row['id'] as String,
      fullName: name.isEmpty ? 'İsimsiz kaleci' : name,
      age: (row['age'] as num?)?.toInt() ?? 0,
      districts: ((row['districts'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      about: (row['about'] as String?) ?? '',
      phone: (row['contact_phone'] as String?) ?? '',
      rating: (row['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
      avatarUrl: (row['avatar_url'] as String?)?.isNotEmpty ?? false
          ? row['avatar_url'] as String
          : null,
      isAvailable: (row['is_available'] as bool?) ?? true,
    );
  }

  final String id;
  final String fullName;
  final int age;

  /// Oynayabileceği İzmir ilçeleri.
  final List<String> districts;
  final String about;
  final String phone;

  /// 5 üzerinden ortalama puan.
  final double rating;
  final int ratingCount;
  final String? avatarUrl;
  final bool isAvailable;

  Goalkeeper copyWith({
    List<String>? districts,
    String? about,
    String? phone,
    String? avatarUrl,
    bool? isAvailable,
  }) {
    return Goalkeeper(
      id: id,
      fullName: fullName,
      age: age,
      districts: districts ?? this.districts,
      about: about ?? this.about,
      phone: phone ?? this.phone,
      rating: rating,
      ratingCount: ratingCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

/// Tamamlanmış bir maçın "Maç Geçmişi" listesindeki gösterimi.
@immutable
class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.id,
    required this.opponentName,
    required this.pitchName,
    required this.playedAt,
    required this.outcome,
    this.opponentId = '',
    this.teamScore,
    this.opponentScore,
    this.teamSize,
    this.reportedAt,
  });

  /// `get_team_match_history` RPC satırı.
  factory MatchHistoryEntry.fromRow(Map<String, dynamic> row) {
    DateTime? parse(String key) =>
        DateTime.tryParse(row[key] as String? ?? '')?.toLocal();

    return MatchHistoryEntry(
      id: row['match_id'] as String,
      opponentId: (row['opponent_id'] as String?) ?? '',
      opponentName: (row['opponent_name'] as String?) ?? '—',
      pitchName: (row['pitch_name'] as String?) ?? '—',
      // Yerel saate çevrilmezse 00:00-03:00 (TR) arası maçlar bir
      // önceki güne yazılıyordu; liste yalnızca gün gösteriyor.
      playedAt: parse('played_at') ?? DateTime.now(),
      outcome: switch (row['outcome'] as String?) {
        'win' => TeamOutcome.win,
        'loss' => TeamOutcome.loss,
        _ => TeamOutcome.draw,
      },
      teamScore: (row['team_score'] as num?)?.toInt(),
      opponentScore: (row['opponent_score'] as num?)?.toInt(),
      teamSize: (row['team_size'] as num?)?.toInt(),
      reportedAt: parse('reported_at'),
    );
  }

  final String id;
  final String opponentId;
  final String opponentName;
  final String pitchName;
  final DateTime playedAt;
  final TeamOutcome outcome;

  /// Skorlar eski maçlarda yok (yalnızca G/B/M girilmişti).
  final int? teamScore;
  final int? opponentScore;
  final int? teamSize;
  final DateTime? reportedAt;

  /// "3 - 2"; skor girilmemişse null.
  String? get scoreLabel =>
      teamScore == null || opponentScore == null ? null : '$teamScore - $opponentScore';
}

// =====================================================================
// KADRO, MAÇ KADROSU, İSTATİSTİK
// =====================================================================

/// Kadroda en az bu kadar oyuncu olmalı (veritabanı da denetliyor).
const int kMinRosterSize = 7;

/// Maç başına takım kişi sayısı aralığı (5v5 - 11v11).
const int kMinTeamSize = 5;
const int kMaxTeamSize = 11;

/// Takımın kadro havuzundaki oyuncu ve toplam istatistikleri.
@immutable
class TeamPlayer {
  const TeamPlayer({
    required this.id,
    required this.teamId,
    required this.firstName,
    required this.lastName,
    this.appearances = 0,
    this.goals = 0,
    this.assists = 0,
  });

  /// `team_player_stats` view satırı.
  factory TeamPlayer.fromRow(Map<String, dynamic> row) {
    return TeamPlayer(
      id: row['player_id'] as String,
      teamId: (row['team_id'] as String?) ?? '',
      firstName: (row['first_name'] as String?) ?? '',
      lastName: (row['last_name'] as String?) ?? '',
      appearances: (row['appearances'] as num?)?.toInt() ?? 0,
      goals: (row['goals'] as num?)?.toInt() ?? 0,
      assists: (row['assists'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String teamId;
  final String firstName;
  final String lastName;
  final int appearances;
  final int goals;
  final int assists;

  String get fullName => '$firstName $lastName'.trim();
}

/// Kadro formundan gönderilen satır (id yoksa yeni oyuncu).
@immutable
class RosterEntry {
  const RosterEntry({this.id, required this.firstName, required this.lastName});

  final String? id;
  final String firstName;
  final String lastName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
      };
}

/// Saha gol / asist krallığındaki bir satır.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.name,
    required this.teamId,
    required this.teamName,
    required this.appearances,
    required this.goals,
    required this.assists,
  });

  /// `pitch_player_stats` view satırı.
  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) {
    return LeaderboardEntry(
      playerId: row['player_id'] as String,
      name: '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
      teamId: (row['team_id'] as String?) ?? '',
      teamName: (row['team_name'] as String?) ?? '',
      appearances: (row['appearances'] as num?)?.toInt() ?? 0,
      goals: (row['goals'] as num?)?.toInt() ?? 0,
      assists: (row['assists'] as num?)?.toInt() ?? 0,
    );
  }

  final String playerId;
  final String name;
  final String teamId;
  final String teamName;
  final int appearances;
  final int goals;
  final int assists;
}

/// Maça çıkan bir oyuncu ve o maçtaki gol / asisti.
@immutable
class LineupPlayer {
  const LineupPlayer({
    required this.playerId,
    required this.teamId,
    required this.name,
    required this.slot,
    this.goals = 0,
    this.assists = 0,
  });

  factory LineupPlayer.fromRow(Map<String, dynamic> row) {
    return LineupPlayer(
      playerId: (row['player_id'] as String?) ?? '',
      teamId: (row['team_id'] as String?) ?? '',
      name: '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
      slot: (row['slot'] as num?)?.toInt() ?? 0,
      goals: (row['goals'] as num?)?.toInt() ?? 0,
      assists: (row['assists'] as num?)?.toInt() ?? 0,
    );
  }

  final String playerId;
  final String teamId;
  final String name;
  final int slot;
  final int goals;
  final int assists;
}

/// Maç detayında bir takımın tarafı.
@immutable
class MatchSide {
  const MatchSide({
    required this.teamId,
    required this.teamName,
    required this.captainId,
    required this.lineup,
    this.score,
  });

  final String teamId;
  final String teamName;
  final String captainId;
  final int? score;
  final List<LineupPlayer> lineup;
}

/// Bir maçın skoru ve iki takımın kadrosu.
@immutable
class MatchDetail {
  const MatchDetail({
    required this.id,
    required this.status,
    required this.pitchName,
    required this.challenger,
    required this.opponent,
    this.matchDate,
    this.teamSize,
    this.reportedAt,
  });

  final String id;
  final MatchStatus status;
  final String pitchName;
  final MatchSide challenger;
  final MatchSide opponent;
  final DateTime? matchDate;
  final int? teamSize;
  final DateTime? reportedAt;

  /// Gol/asist, maç bittikten sonraki 7 gün içinde girilebilir/düzeltilebilir.
  bool get areStatsEditable =>
      status == MatchStatus.completed &&
      reportedAt != null &&
      DateTime.now().isBefore(reportedAt!.add(const Duration(days: 7)));

  /// [userId]'nin kaptanı olduğu taraf (yoksa null).
  MatchSide? sideOf(String? userId) {
    if (userId == null) return null;
    if (challenger.captainId == userId) return challenger;
    if (opponent.captainId == userId) return opponent;
    return null;
  }
}

/// "Bekleyen Maçlar" listesindeki bir kayıt.
///
/// UI'daki tüm aksiyonlar [stage] üzerinden türetilir; ekran kodu
/// durum hesabı yapmaz, yalnızca aşamayı okur.
@immutable
class PendingMatch {
  const PendingMatch({
    required this.id,
    required this.myTeamName,
    required this.opponentTeamName,
    this.opponentTeamId = '',
    this.opponentCaptainId = '',
    this.myTeamId = '',
    this.teamSize,
    this.myLineupCount = 0,
    required this.opponentPhone,
    required this.opponentCaptainName,
    required this.pitchName,
    required this.status,
    required this.isChallenger,
    required this.myTeamReady,
    required this.opponentReady,
    this.acceptedAt,
    this.matchDate,
  });

  final String id;
  final String myTeamName;
  final String opponentTeamName;

  /// Saha detayında "bu takımla zaten maçım var mı" kontrolü için.
  final String opponentTeamId;

  /// Rakip takımın kaptanı; maç kartından raporlama/engelleme için.
  final String opponentCaptainId;

  /// Bu maçtaki takımımız (kadro seçimi için).
  final String myTeamId;

  /// Maç kaç kişilik (5-11); gün/saatle birlikte belirlenir.
  final int? teamSize;

  /// Maç kadromuza seçtiğimiz oyuncu sayısı.
  final int myLineupCount;

  /// Kadro seçimi yapılabilir mi? (Gün ve kişi sayısı belli, sonuç girilmemiş.)
  bool get canPickLineup => status == MatchStatus.scheduled && teamSize != null;

  /// Kadro eksiksiz seçildi mi?
  bool get isLineupComplete => teamSize != null && myLineupCount == teamSize;

  /// Yalnızca [PendingMatchStage.confirmed] ve sonrasında UI'da gösterilir.
  final String opponentPhone;
  final String opponentCaptainName;
  final String pitchName;
  final MatchStatus status;

  /// Meydan okuyan taraf biz miyiz? (Sonucu yalnızca meydan okuyan girer.)
  final bool isChallenger;
  final bool myTeamReady;
  final bool opponentReady;

  /// Rakip meydan okumayı kabul ettiği an — 1 haftalık sayaç buradan başlar.
  final DateTime? acceptedAt;
  final DateTime? matchDate;

  /// Karşılıklı onay için son tarih (kabul + 7 gün).
  DateTime? get readinessDeadline => acceptedAt?.add(const Duration(days: 7));

  /// Son tarihe kalan süre; süre dolduysa [Duration.zero].
  Duration get timeLeftForReadiness {
    final DateTime? deadline = readinessDeadline;
    if (deadline == null) return Duration.zero;
    final Duration left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Maç saatinin üzerinden 1 saat geçti mi? (Sonuç girişi bu andan sonra.)
  bool get isResultDue {
    final DateTime? date = matchDate;
    if (date == null) return false;
    return DateTime.now().isAfter(date.add(const Duration(hours: 1)));
  }

  /// Maç gün/saati hâlâ değiştirilebilir mi?
  ///
  /// Tarih henüz girilmediyse ya da maç saati gelmediyse evet. Maç
  /// başladıktan sonra tarihi ileri almak sonuç sorusunu erteleyeceği için
  /// kapalı.
  bool get canReschedule {
    final DateTime? date = matchDate;
    return date == null || date.isAfter(DateTime.now());
  }

  /// İletişim bilgisi yalnızca iki taraf da hazır olduğunda açılır.
  bool get isContactVisible =>
      status == MatchStatus.mutuallyAgreed || status == MatchStatus.scheduled;

  /// Kartın hangi aksiyonları göstereceğini belirleyen tek doğruluk kaynağı.
  PendingMatchStage get stage {
    switch (status) {
      case MatchStatus.pending:
        return isChallenger
            ? PendingMatchStage.invitationSent
            : PendingMatchStage.invitationReceived;

      case MatchStatus.accepted:
        // 2. aşama: iki taraftan en az biri henüz "Maça Hazırım" dememiş.
        //
        // acceptedAt null ise süre hesaplanamaz; bu durumda "süresi doldu"
        // demek yanlış olur — kabul yeni gelmiş demektir. Sunucu tarafında
        // sayacı zaten cancel_deadline ve auto_cancel_stale_matches() tutuyor.
        if (acceptedAt == null) return PendingMatchStage.readinessPending;
        return timeLeftForReadiness == Duration.zero
            ? PendingMatchStage.expired
            : PendingMatchStage.readinessPending;

      case MatchStatus.mutuallyAgreed:
        return PendingMatchStage.confirmed;

      case MatchStatus.scheduled:
        // 4. aşama: maç saati + 1 saat geçtiyse sonuç istenir.
        return isResultDue
            ? PendingMatchStage.awaitingResult
            : PendingMatchStage.confirmed;

      case MatchStatus.autoCancelled:
      case MatchStatus.cancelled:
      case MatchStatus.rejected:
      case MatchStatus.completed:
        return PendingMatchStage.expired;
    }
  }

  PendingMatch copyWith({
    MatchStatus? status,
    bool? myTeamReady,
    bool? opponentReady,
    DateTime? acceptedAt,
    DateTime? matchDate,
  }) {
    return PendingMatch(
      id: id,
      myTeamName: myTeamName,
      opponentTeamName: opponentTeamName,
      opponentTeamId: opponentTeamId,
      opponentCaptainId: opponentCaptainId,
      myTeamId: myTeamId,
      teamSize: teamSize,
      myLineupCount: myLineupCount,
      opponentPhone: opponentPhone,
      opponentCaptainName: opponentCaptainName,
      pitchName: pitchName,
      status: status ?? this.status,
      isChallenger: isChallenger,
      myTeamReady: myTeamReady ?? this.myTeamReady,
      opponentReady: opponentReady ?? this.opponentReady,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      matchDate: matchDate ?? this.matchDate,
    );
  }
}

/// Takvimde gün altına nokta koymak için kullanılan basit etkinlik modeli.
@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.date,
    required this.title,
    required this.subtitle,
  });

  final DateTime date;
  final String title;
  final String subtitle;
}

// =====================================================================
// BİLDİRİMLER
// =====================================================================

/// `notifications` tablosundaki `notification_type` enum'unun Dart karşılığı.
enum NotificationKind {
  challengeReceived,
  challengeAccepted,
  challengeRejected,
  matchMutuallyAgreed,
  matchScheduled,
  matchResultRequest,
  matchCompleted,
  matchAutoCancelled,
  matchCancelled,
  goalkeeperRated,
  generic;

  static NotificationKind fromDb(String? value) => switch (value) {
        'challenge_received' => NotificationKind.challengeReceived,
        'challenge_accepted' => NotificationKind.challengeAccepted,
        'challenge_rejected' => NotificationKind.challengeRejected,
        'match_mutually_agreed' => NotificationKind.matchMutuallyAgreed,
        'match_scheduled' => NotificationKind.matchScheduled,
        'match_result_request' => NotificationKind.matchResultRequest,
        'match_completed' => NotificationKind.matchCompleted,
        'match_auto_cancelled' => NotificationKind.matchAutoCancelled,
        'match_cancelled' => NotificationKind.matchCancelled,
        'goalkeeper_rated' => NotificationKind.goalkeeperRated,
        _ => NotificationKind.generic,
      };

  /// Listede kullanılan ikon.
  IconData get icon => switch (this) {
        NotificationKind.challengeReceived => Icons.sports_soccer_rounded,
        NotificationKind.challengeAccepted => Icons.check_circle_rounded,
        NotificationKind.challengeRejected => Icons.cancel_rounded,
        NotificationKind.matchMutuallyAgreed => Icons.handshake_rounded,
        NotificationKind.matchScheduled => Icons.event_available_rounded,
        NotificationKind.matchResultRequest => Icons.help_center_rounded,
        NotificationKind.matchCompleted => Icons.emoji_events_rounded,
        NotificationKind.matchAutoCancelled => Icons.timer_off_rounded,
        NotificationKind.matchCancelled => Icons.event_busy_rounded,
        NotificationKind.goalkeeperRated => Icons.star_rounded,
        NotificationKind.generic => Icons.notifications_rounded,
      };

  /// Kullanıcıyı ilgili sekmeye yönlendirmek anlamlı mı?
  /// Maçla ilgili tüm bildirimler "Profilim → Takımım" sekmesine gider.
  bool get opensMyTeam => this != NotificationKind.goalkeeperRated &&
      this != NotificationKind.generic;
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.matchId,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      kind: NotificationKind.fromDb(row['type'] as String?),
      title: (row['title'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      isRead: (row['is_read'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      matchId: row['match_id'] as String?,
    );
  }

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? matchId;

  /// "3 dk önce", "2 sa önce", "5 gün önce" biçiminde göreli zaman.
  String get relativeTime {
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return DateFormat('d MMM yyyy', 'tr_TR').format(createdAt);
  }
}
