# Veritabanı testleri

`supabase/migrations` altındaki bütün dosyaları sırayla gerçek bir Postgres
(PGlite, WebAssembly) üzerinde çalıştırır, ardından `tests.sql`'deki
senaryoları dener:

- telefon, doğum tarihi ve oyuncu soyadının başkalarına kapalı olması,
- iç fonksiyonların (istatistik, bildirim) dışarıdan çağrılamaması,
- maç akışı: teklif → kabul → hazırım → tarih + kişi sayısı → kadro → skor,
- banlı hesabın yazamaması, engellemenin temel tablolarda çalışması,
- uygunsuz ifade filtresi, 18 yaş kuralı, hesap silme.

Supabase'e özgü parçalar (`auth.uid()`, roller, `storage`, `cron`) `run.mjs`
içinde taklit ediliyor; sunucuya bağlanmaz, hiçbir veriye dokunmaz.

```bash
cd supabase/tests
npm install
npm test
```

Her test `-- TEST: ad` satırıyla başlar. `-- EXPECT ERROR: metin` olan test
hata vermeli; diğerleri son sorguda `ok = true` döndürmeli. Her test kendi
işleminde çalışıp geri alınır.
