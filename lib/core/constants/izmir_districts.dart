/// İzmir'in 30 ilçesi ve Türkçe alfabetik sıralama yardımcıları.
abstract final class IzmirDistricts {
  /// Türk alfabesine göre sıralanmış tam liste.
  static const List<String> all = <String>[
    'Aliağa',
    'Balçova',
    'Bayındır',
    'Bayraklı',
    'Bergama',
    'Beydağ',
    'Bornova',
    'Buca',
    'Çeşme',
    'Çiğli',
    'Dikili',
    'Foça',
    'Gaziemir',
    'Güzelbahçe',
    'Karabağlar',
    'Karaburun',
    'Karşıyaka',
    'Kemalpaşa',
    'Kınık',
    'Kiraz',
    'Konak',
    'Menderes',
    'Menemen',
    'Narlıdere',
    'Ödemiş',
    'Seferihisar',
    'Selçuk',
    'Tire',
    'Torbalı',
    'Urla',
  ];

  /// Türkçe alfabetik sırayla yeni bir liste döndürür.
  ///
  /// `String.compareTo` Unicode kod noktasına göre çalıştığı için
  /// Ç/Ğ/İ/Ö/Ş/Ü harflerini listenin sonuna atar; bu yüzden kendi
  /// karşılaştırıcımızı kullanıyoruz.
  static List<String> sorted(Iterable<String> districts) =>
      districts.toList()..sort(compare);

  static const String _alphabet = 'aäbcçdefgğhıijklmnoöprsştuüvyz';

  /// Türkçe küçük harfe çevirir (I -> ı, İ -> i).
  ///
  /// `String.toLowerCase()` Unicode varsayılanını uygular ve
  /// 'I' -> 'i', 'İ' -> 'i̇' (birleşik nokta) üretir; bu Türkçe için yanlıştır.
  static String toLowerTr(String value) => value
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .toLowerCase();

  /// Türkçe alfabeye göre iki metni karşılaştırır.
  static int compare(String a, String b) {
    final String x = toLowerTr(a);
    final String y = toLowerTr(b);
    final int len = x.length < y.length ? x.length : y.length;

    for (int i = 0; i < len; i++) {
      final int ix = _alphabet.indexOf(x[i]);
      final int iy = _alphabet.indexOf(y[i]);
      // Alfabede olmayan karakterler (boşluk, tire vb.) sona gider.
      final int rankX = ix == -1 ? _alphabet.length : ix;
      final int rankY = iy == -1 ? _alphabet.length : iy;
      if (rankX != rankY) return rankX.compareTo(rankY);
    }
    return x.length.compareTo(y.length);
  }
}
