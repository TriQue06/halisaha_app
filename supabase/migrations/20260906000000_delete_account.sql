-- =====================================================================
-- HESAP SILME (Google Play zorunlulugu)
--
-- Play Store, hesap olusturan uygulamalarda UYGULAMA ICINDEN hesap ve
-- veri silme yolu sunmayi zorunlu tutuyor.
--
-- Istemci auth.users tablosuna dogrudan yazamaz (service_role gerekir ve
-- o anahtar APK'ya konulamaz). Bu yuzden silme islemi security definer
-- bir fonksiyonla yapiliyor: fonksiyon yalnizca auth.uid() ile eslesen
-- satiri siler, yani kullanici sadece KENDI hesabini silebilir.
--
-- auth.users silinince zincirleme her sey dusuyor:
--   auth.users -> profiles -> teams -> matches
--                          -> goalkeepers -> goalkeeper_ratings
--                          -> notifications
--                          -> device_tokens
-- (hepsi "on delete cascade" ile tanimli, ek temizlik gerekmiyor)
--
-- Tek istisna: matches.pitch_id "on delete restrict" ama saha silinmiyor,
-- silinen taraf takim oldugu icin mac zaten cascade ile gidiyor.
-- =====================================================================

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Oturum bulunamadi.' using errcode = '28000';
  end if;

  -- Cihaz token'lari profiles uzerinden cascade ile dusuyor; yine de
  -- once elle siliyoruz ki silme aninda bekleyen bir push denemesi
  -- artik var olmayan hesaba bildirim gondermeye calismasin.
  delete from public.device_tokens where user_id = v_uid;

  -- Asil silme. Geri kalan her sey cascade.
  delete from auth.users where id = v_uid;
end;
$$;

-- Yalnizca giris yapmis kullanicilar cagirabilir.
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

comment on function public.delete_my_account() is
  'Cagiran kullanicinin kendi hesabini ve tum verisini siler (Play Store zorunlulugu).';
