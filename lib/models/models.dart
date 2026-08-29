import 'package:flutter/foundation.dart';

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
