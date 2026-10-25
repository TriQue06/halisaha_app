# Japon Kale ⚽

İzmir'de halı saha çevresinde takımları ve kalecileri buluşturan mobil uygulama
(Flutter + Supabase). iOS (App Store), Android (Google Play) ve web önizleme.

## Ne yapar?

- **Takım kaptanı:** bir sahaya takım kurar (en az 7 kişilik kadro), o sahadaki
  takımlara maç teklifi gönderir, maçı kilitler (gün/saat + 5v5–11v11), maç
  kadrosunu seçer, skoru ve gol/asistleri girer.
- **Kaleci:** oynayabildiği ilçeleri ve müsaitliğini yayımlar; takımlar
  arayarak ulaşır, oyuncular puan verir.
- **Herkes:** sahaları, takım profillerini (kadro, skorlu maç geçmişi) ve
  sahaların gol/asist krallığını inceler.
- **Güvenlik:** raporlama, engelleme, panelden banlama, uygunsuz ifade filtresi.

## Çalıştırma

```bash
flutter pub get
```

```bash
flutter run
```

Release (APK/AAB) için `android/key.properties` şart; yoksa derleme bilerek durur.

## Mimari

```
lib/
├── main.dart                     # Açılış, tema, yerelleştirme, yazı ölçeği
├── core/                         # tema, sabitler, push servisi, ortak widget'lar
├── models/models.dart            # Modeller + PendingMatch aşama makinesi
├── data/                         # Supabase depoları (maç, takım/kadro, moderasyon)
├── state/                        # Riverpod provider'ları ve aksiyonlar
└── features/
    ├── auth/                     # Giriş, kayıt, e-posta kodu, profil tamamlama
    ├── shell/                    # Ana Sayfa · Sahalar · Maçlar · Kaleciler · Profil
    ├── home/                     # Yapılacaklar, popüler sahalar, takvim
    ├── pitches/                  # Saha listesi (ilçe filtresi) + saha detayı
    ├── matches/                  # Bekleyen maçlar + maç geçmişi
    ├── teams/                    # Takım kurma/kadro, takım profili, maç kadrosu, skor
    ├── goalkeepers/              # Kaleci listesi
    ├── profile/                  # Takımlarım, kaleci profili, maç kartı
    ├── moderation/               # Rapor et / engelle
    └── settings/                 # Tema, yazı, bildirim tercihleri, hesap silme
```

Ekranlar Supabase'i doğrudan çağırmaz; provider'lar üzerinden depolara gider.
Yetki ve iş kuralları (kim neyi yapabilir, durum geçişleri, kadro sayısı,
skor) **veritabanında** denetlenir; uygulama yalnızca doğru butonu gösterir.

## Maç akışı

| Aşama | Durum | Aksiyon | İletişim |
|---|---|---|---|
| 1 | `pending` | Kabul / Reddet (7 günde yanıt yoksa düşer) | gizli |
| 2 | `accepted` | **Maça Hazırım** (iki taraf, 7 gün) | gizli |
| 3 | `mutually_agreed` / `scheduled` | Gün-saat + kaç kişilik, maç kadrosu | **açık** |
| 4 | maç saati + 1 sa | Skor + gol/asist (teklif sahibi; 24 sa girmezse rakip) | açık |

Kabul edilmiş maç her aşamada iptal edilebilir. Gol/asist ve kadro maçtan
sonraki 7 gün içinde düzeltilebilir.

## Gizlilik kuralları (veritabanında)

- Telefon ve doğum tarihi başka kullanıcılara okunamaz; rakibin numarası yalnızca
  iki taraf "Maça Hazırım" dedikten sonra `get_opponent_contact` ile gelir.
- Kayıtlı olmayan oyuncuların soyadı başkalarına baş harf olarak görünür
  ("Ahmet Y."); tam ad yalnızca takımın kaptanına açıktır.
- Engellenen/banlanan kullanıcıların takımları ve kaleci profilleri listelerden
  düşer; banlı hesap hiçbir yoldan yazamaz ama hesabını silebilir.

## Veritabanı

Şema ve kurulum: [supabase/README.md](supabase/README.md). Migration'lar
`supabase/migrations` altında, tarih sırasıyla SQL Editor'de çalıştırılır.

## Test

```bash
flutter test
```

```bash
cd supabase/tests && npm install && npm test
```

İlki model, form ve ekran testleri; ikincisi tüm migration'ları gerçek bir
Postgres'te çalıştırıp yetki ve maç akışı senaryolarını dener
(bkz. [supabase/tests/README.md](supabase/tests/README.md)).
