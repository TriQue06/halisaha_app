-- =====================================================================
-- Örnek halı sahaları kaldırır, gerçek sahayı ekler.
--
-- Kaynaklar (2026-08-30 tarihinde doğrulandı):
--   https://yandex.com.tr/maps/org/eforyum_balcova_hali_saha_tesisleri/141537285626/
--   https://sosyalhalisaha.com/hali-saha/eforyum-hali-saha
--
-- NOT: İşletmenin adında "Balçova" geçiyor ama kayıtlı adresi Narlıdere
-- (Ilıca Mah., Bayrak Sok.). İlçe alanı kaleci filtresinde eşleşme için
-- kullanıldığından gerçek adrese göre 'Narlıdere' giriliyor.
-- =====================================================================

-- --- Örnek sahaları temizle ------------------------------------------
-- Bunlara bağlı takım/maç yoksa güvenle silinir. Varsa silme başarısız
-- olur (matches.pitch_id ON DELETE RESTRICT) — bu bilinçli bir koruma.
delete from public.pitches
where name in (
  'Bornova Spor Kompleksi',
  'Karsiyaka Arena',
  'Karşıyaka Arena',
  'Buca Halisaha',
  'Buca Halısaha',
  'Gaziemir Yildiz Saha',
  'Gaziemir Yıldız Saha',
  'Konak Sahil Spor',
  'Cigli Futbol Park',
  'Çiğli Futbol Park'
);

-- --- Gerçek saha ------------------------------------------------------
insert into public.pitches (
  name, district, address, latitude, longitude, phone,
  description, price_per_hour, is_indoor, has_parking, has_shower, is_active
)
values (
  'Eforyum Halı Saha Tesisleri',
  'Narlıdere',
  'Ilıca Mah. Bayrak Sok. No:1-3',
  38.391791,
  27.029475,
  '+905443563535',
  '5 adet açık halı saha. 24 saat hizmet veriyor. '
    'Saat ücreti için tesisi arayın. İkinci hat: 0554 225 02 59.',
  null,      -- ücret siteler üzerinde yayınlanmıyor
  false,     -- açık saha
  true,      -- engelli otoparkı mevcut
  false,     -- kaynaklarda duş/soyunma bilgisi yok
  true
)
on conflict (name, district) do update set
  address        = excluded.address,
  latitude       = excluded.latitude,
  longitude      = excluded.longitude,
  phone          = excluded.phone,
  description    = excluded.description,
  is_indoor      = excluded.is_indoor,
  has_parking    = excluded.has_parking,
  is_active      = true,
  updated_at     = now();

-- Kontrol
-- select name, district, address, phone from public.pitches order by name;
