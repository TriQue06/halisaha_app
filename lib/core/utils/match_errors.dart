import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase/Postgres hatalarını kullanıcıya gösterilebilir Türkçe metne çevirir.
///
/// Özellikle `matches_active_pair_uniq` benzersizlik ihlali ham hâliyle
/// ("duplicate key value violates unique constraint...") kullanıcıya hiçbir şey
/// anlatmıyordu; burada anlaşılır karşılıklarını veriyoruz.
String turkishMatchError(Object error) {
  if (error is PostgrestException) {
    final String text = '${error.message} ${error.details ?? ''}'.toLowerCase();

    if (text.contains('teams_name_pitch_uniq')) {
      return 'Bu sahada aynı isimde bir takım zaten var. Başka bir ad seç.';
    }
    if (error.code == '23505' || text.contains('matches_active_pair_uniq')) {
      return 'Bu takımla aramızda zaten devam eden bir maç var. '
          'Önce onu sonuçlandır ya da iptal et.';
    }
    if (error.code == '42501' || text.contains('insufficient_privilege')) {
      return 'Bu işlem için yetkin yok. Yalnızca takım kaptanı yapabilir.';
    }
    if (text.contains('uygunsuz ifade')) {
      return 'Girdiğin metin uygunsuz bir ifade içeriyor. Lütfen düzelt.';
    }
    if (text.contains('askiya alindigi icin bu islem')) {
      return 'Hesabın askıya alındığı için bu işlemi yapamazsın.';
    }
    if (text.contains('18 yas')) {
      return 'Japon Kale 18 yaş ve üzeri içindir.';
    }
    if (text.contains('24 saat icinde girmezse')) {
      return 'Skoru önce teklifi gönderen takım girer. Maçtan 24 saat sonra '
          'hâlâ girilmemişse sen girebilirsin.';
    }
    if (text.contains('1 saat sonra girilebilir')) {
      return 'Skor, maç saatinden 1 saat sonra girilebilir.';
    }
    if (text.contains('bu asamada goruntulenemez')) {
      return 'İletişim bilgisi, iki taraf da "Maça Hazırım" dedikten sonra açılır.';
    }
    if (text.contains('tarafi degilsiniz')) {
      return 'Bu maçın taraflarından biri değilsin.';
    }
    if (text.contains('gol toplami') || text.contains('asist toplami')) {
      return 'Gol veya asist toplamı takımın skorunu geçemez.';
    }
    if (text.contains('7 gun icinde girilebilir')) {
      return 'Gol ve asistler maç bittikten sonraki 7 gün içinde girilebilir.';
    }
    if (text.contains('mac teklifi icin takim kadrosunda')) {
      return 'Maç teklifi göndermek için kadronda en az 7 oyuncu olmalı. '
          'Profilim → takımına dokun → Kadro → Düzenle.';
    }
    if (text.contains('kabul etmek icin takim kadrosunda')) {
      return 'Teklifi kabul etmek için kadronda en az 7 oyuncu olmalı. '
          'Profilim → takımına dokun → Kadro → Düzenle.';
    }
    if (text.contains('teklifi gonderilemiyor')) {
      return 'Bu takıma maç teklifi gönderilemiyor.';
    }
    if (text.contains('askiya alindigi')) {
      return 'Hesabın askıya alındığı için maç teklifi gönderemezsin.';
    }
    if (text.contains('kendisine mac teklifi')) {
      return 'Bir takım kendisine maç teklifi gönderemez.';
    }
    // Uygulama geçmiş saati göndermeden önce uyarıyor; bu, cihaz saati
    // yanlışsa ya da seçim ile kayıt arasında saat geçtiyse görülür.
    if (text.contains('gelecekte olmalidir')) {
      return 'Maç saati şu andan sonra olmalı. Lütfen ileri bir saat seç.';
    }
    // Fonksiyonlarımızın raise ettiği mesajlar Türkçe (ASCII); İngilizce
    // teknik Postgres/PostgREST hataları kullanıcıya gösterilmez.
    if (_looksTechnical(error.message)) return _generic;
    return error.message;
  }
  if (error is AuthException) return _generic;
  final String raw = error.toString().toLowerCase();
  if (raw.contains('socket') || raw.contains('network') || raw.contains('timeout') ||
      raw.contains('connection')) {
    return 'İnternet bağlantısı yok gibi görünüyor. Bağlantını kontrol edip tekrar dene.';
  }
  return _generic;
}

const String _generic = 'İşlem tamamlanamadı. Lütfen biraz sonra tekrar dene.';

/// Postgres/PostgREST'in İngilizce teknik mesajları ("permission denied",
/// "column ... does not exist", "JSON object requested" ...).
bool _looksTechnical(String message) {
  final String m = message.toLowerCase();
  return m.contains('permission denied') ||
      m.contains('does not exist') ||
      m.contains('violates') ||
      m.contains('json object') ||
      m.contains('could not find') ||
      m.contains('syntax error') ||
      m.contains('invalid input') ||
      m.contains('jwt') ||
      m.contains('schema cache');
}
