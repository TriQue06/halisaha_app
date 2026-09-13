-- =====================================================================
-- PROFIL FOTOGRAFI (Supabase Storage)
--
-- Fotograflar "avatars" bucket'inda <kullanici_id>/avatar_<zaman>.<uzanti>
-- yolunda tutulur; profiles.avatar_url dosyanin public URL'sini gosterir.
-- Kaleci listesi ayni alani view uzerinden okudugu icin ayrica bir
-- kolon yok.
--
-- Bucket public: fotograflar maç/kaleci kartlarinda herkese gorunuyor,
-- okumak icin oturum gerekmez. Yazma ise klasor bazli kisitli: herkes
-- yalnizca kendi kullanici id'si adindaki klasore yukleyip silebilir.
--
-- Boyut/tur siniri sunucuda da uygulanir (istemci 512px'e kucultup
-- yukluyor, bu sinirlar kotu niyetli dogrudan API cagrilarina karsi).
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152, -- 2 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Kendi klasorunu listeleme (eski fotograflari temizlemek icin gerekli).
-- Public URL ile okuma bu politikaya bagli degil.
drop policy if exists "avatars_select_own" on storage.objects;
create policy "avatars_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
