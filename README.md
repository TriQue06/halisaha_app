# RakipVar ⚽

İzmir için halı saha maç ayarlama ve kaleci bulma uygulaması.

## Çalıştırma

```bash
flutter pub get
```

```bash
flutter run
```

## Mimari

```
lib/
├── main.dart                       # ProviderScope + MaterialApp (tema, tr_TR, textScale)
├── core/
│   ├── theme/app_colors.dart       # Koyu yeşil paleti + anlamsal renkler (G/B/M)
│   ├── theme/app_theme.dart        # Açık (yeşil+beyaz) & koyu (yeşil+siyah) tema
│   ├── constants/izmir_districts.dart  # 30 ilçe + Türkçe alfabetik sıralayıcı
│   └── widgets/common_widgets.dart # SectionHeader, RatingStars, StatBadge, InfoPill...
├── models/models.dart              # Enum'lar + modeller + PendingMatch aşama makinesi
├── data/mock_data.dart             # Statik mock veriler (Supabase'e geçişte silinir)
├── state/
│   ├── settings_controller.dart    # Tema / yazı boyutu / bildirimler (kalıcı)
│   └── app_providers.dart          # Riverpod provider ve controller'ları
└── features/
    ├── shell/main_shell.dart       # 5'li BottomNavigationBar
    ├── home/                       # Popüler sahalar → Kaleci CTA → Takvim
    ├── pitches/                    # Saha listesi + saha detayı (MEYDAN OKU kuralı)
    ├── goalkeepers/                # İlçe seçici + kaleci kartları
    ├── profile/                    # Takımım / Kaleci Profilim + bekleyen maçlar
    └── settings/                   # Tema, yazı boyutu, bildirim ayarları
```

State management: **Riverpod 2** (`Notifier` / `Provider` / `Provider.family`).
Ekranlar mock veriyi doğrudan bilmez; yalnızca provider'ları izler. Supabase'e
geçişte `data/mock_data.dart` yerine repository implementasyonları konulur,
UI kodu değişmez.

## Bekleyen Maçlar — 4 aşamalı onay akışı

`PendingMatch.stage` tek doğruluk kaynağıdır; kart hangi butonu göstereceğine
buradan karar verir:

| Aşama | Durum | Görünen aksiyon | İletişim bilgisi |
|---|---|---|---|
| 1 | `pending` | Kabul Et / Reddet (veya "yanıt bekleniyor") | 🔒 gizli |
| 2 | `accepted` | **Maça Hazırım** + 1 haftalık geri sayım | 🔒 gizli |
| 3 | `mutuallyAgreed` / `scheduled` | Maç gün-saati belirle | 🔓 **açık** |
| 4 | `scheduled` + maç saati +1sa geçti | Kazandık / Berabere / Kaybettik | 🔓 açık |

1 hafta içinde iki taraf da onaylamazsa aşama `expired` olur (backend'deki
`auto_cancel_stale_matches()` cron'u ile eşleşir).

## Veritabanı

Supabase şeması `supabase/` klasöründedir — bkz. [supabase/README.md](supabase/README.md).

## Test

```bash
flutter test
```

Aşama makinesi, onay akışı controller'ı, popüler saha sıralaması, Türkçe
alfabetik sıralama ve açılış smoke testi kapsanır.
