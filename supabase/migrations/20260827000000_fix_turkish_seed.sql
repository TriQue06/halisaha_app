-- =====================================================================
-- Seed verisindeki saha adlarını ve adreslerini Türkçe karakterlerle düzeltir.
-- İlk seed ASCII yazılmıştı; veritabanı UTF-8'i sorunsuz sakladığı için
-- doğru yazımlara geçiyoruz.
--
-- Eşleştirme ASCII isim üzerinden yapılır; idempotenttir (tekrar
-- çalıştırıldığında eşleşme bulamaz, hiçbir şeyi bozmaz).
-- =====================================================================

update public.pitches set
  name     = 'Karşıyaka Arena',
  address  = 'Bostanlı Mah. Karşıyaka/İzmir'
where name = 'Karsiyaka Arena';

update public.pitches set
  name     = 'Buca Halısaha',
  address  = 'Şirinyer Mah. Buca/İzmir'
where name = 'Buca Halisaha';

update public.pitches set
  name     = 'Çiğli Futbol Park',
  address  = 'Ataşehir Mah. Çiğli/İzmir',
  district = 'Çiğli'
where name = 'Cigli Futbol Park';

update public.pitches set
  address = 'Kazımdirik Mah. Bornova/İzmir'
where name = 'Bornova Spor Kompleksi';

update public.pitches set
  name    = 'Gaziemir Yıldız Saha',
  address = 'Atatürk Mah. Gaziemir/İzmir'
where name = 'Gaziemir Yildiz Saha';

update public.pitches set
  address = 'Göztepe Mah. Konak/İzmir'
where name = 'Konak Sahil Spor';

-- İlçe adlarını da Türkçe yazıma çevir (kaleci ilçe filtresi bunlarla eşleşecek)
update public.pitches set district = 'Karşıyaka' where district = 'Karsiyaka';
update public.pitches set district = 'Çiğli'     where district = 'Cigli';

-- Kontrol
-- select name, district, address from public.pitches order by name;
