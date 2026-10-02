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
    // Fonksiyonlarımızın raise ettiği mesajlar zaten Türkçe.
    return error.message;
  }
  return 'İşlem tamamlanamadı: $error';
}
