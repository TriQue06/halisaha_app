import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase/Postgres hatalarını kullanıcıya gösterilebilir Türkçe metne çevirir.
///
/// Özellikle `matches_active_pair_uniq` benzersizlik ihlali ham hâliyle
/// ("duplicate key value violates unique constraint...") kullanıcıya hiçbir şey
/// anlatmıyordu; burada anlaşılır karşılıklarını veriyoruz.
String turkishMatchError(Object error) {
  if (error is PostgrestException) {
    final String text = '${error.message} ${error.details ?? ''}'.toLowerCase();

    if (error.code == '23505' || text.contains('matches_active_pair_uniq')) {
      return 'Bu takımla aramızda zaten devam eden bir maç var. '
          'Önce onu sonuçlandır ya da iptal et.';
    }
    if (error.code == '42501' || text.contains('insufficient_privilege')) {
      return 'Bu işlem için yetkin yok. Yalnızca takım kaptanı yapabilir.';
    }
    if (text.contains('kendisine mac teklifi')) {
      return 'Bir takım kendisine maç teklifi gönderemez.';
    }
    // Fonksiyonlarımızın raise ettiği mesajlar zaten Türkçe.
    return error.message;
  }
  return 'İşlem tamamlanamadı: $error';
}
