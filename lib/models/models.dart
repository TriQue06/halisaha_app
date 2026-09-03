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
  });

  final String id;
  final String opponentName;
  final String pitchName;
  final DateTime playedAt;
  final TeamOutcome outcome;
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
