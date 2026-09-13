import 'dart:typed_data';

/// Profil fotoğraflarının tutulduğu Supabase Storage bucket'ı.
const String kAvatarBucket = 'avatars';

/// Yüklenebilen profil fotoğrafı biçimleri.
///
/// Tür dosya adından değil içeriğin ilk baytlarından belirleniyor: web'de
/// ve bazı galeri uygulamalarında dosya adı/uzantısı güvenilir değil
/// (uzantısız "image" adı ya da .jpg adlı HEIC gibi).
enum AvatarImageType {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp');

  const AvatarImageType(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  /// Sunucudaki bucket sınırıyla aynı (2 MB). İstemci fotoğrafı 512 px'e
  /// küçülttüğü için normalde bunun çok altında kalır.
  static const int maxBytes = 2 * 1024 * 1024;

  /// Baytlardan biçimi bulur; desteklenmeyen biçimde `null` döner.
  static AvatarImageType? detect(Uint8List bytes) {
    bool matches(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (int i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (matches(const <int>[0xFF, 0xD8, 0xFF])) return jpeg;
    if (matches(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return png;
    }
    // WebP: "RIFF" + 4 bayt boyut + "WEBP"
    if (matches(const <int>[0x52, 0x49, 0x46, 0x46]) &&
        matches(const <int>[0x57, 0x45, 0x42, 0x50], 8)) {
      return webp;
    }
    return null;
  }
}
