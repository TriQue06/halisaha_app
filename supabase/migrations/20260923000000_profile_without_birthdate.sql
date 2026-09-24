-- =====================================================================
-- PROFIL TAMAMLIK: DOGUM TARIHI ARTIK ZORUNLU DEGIL
--
-- App Store incelemesi (Guideline 4 - Design, Sign in with Apple):
-- "users are required to provide their name and/or email address after
--  using Sign in with Apple even though that information is already
--  provided by the Authentication Services framework."
--
-- Sebep: profil "tam" sayilmak icin ad, soyad VE dogum tarihi
-- isteniyordu. Apple ad-soyad ve e-posta veriyor ama dogum tarihi
-- vermiyor; bu yuzden Apple ile giren her kullanici girisin hemen
-- ardindan "Profilini Tamamla" ekranina dusuyordu.
--
-- Bundan sonra ad ve soyad yeterli. Dogum tarihi istege bagli:
-- kullanici profilinden sonra girebilir, girilirse yasi gosterilir.
-- =====================================================================

create or replace function public.is_profile_complete(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $fn$
  select exists (
    select 1 from public.profiles p
    where p.id = p_user_id
      and coalesce(trim(p.first_name), '') <> ''
      and coalesce(trim(p.last_name), '')  <> ''
      -- dogum tarihi ve telefon zorunlu degil
  );
$fn$;

comment on function public.is_profile_complete(uuid) is
  'Profil, uygulamayi kullanmaya yetecek kadar dolu mu? Ad ve soyad yeterli; '
  'dogum tarihi istege bagli, telefon iletisim adimlarinda ayrica isteniyor.';
