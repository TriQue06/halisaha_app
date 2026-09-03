-- =====================================================================
-- Giriş yöntemi yalnızca e-posta + Google olarak sadeleştirildi.
--
-- Telefonla giriş (SMS OTP) kaldırıldı: Türkiye'ye A2P SMS için Twilio
-- alfanümerik gönderici adı ön kaydı gerekiyor (~2 hafta) ve 18 Kasım
-- 2026'dan itibaren kayıtsız gönderimler engelleniyor. Bu yüzden telefon
-- artık bir KİMLİK DOĞRULAMA yöntemi değil, yalnızca isteğe bağlı bir
-- İLETİŞİM alanı.
--
-- Sonuç: profilin "tamamlanmış" sayılması için telefon aranmıyor.
-- Telefon, gerçekten gerektiği yerde toplanıyor:
--   - takım kurarken  -> teams.contact_phone (zorunlu)
--   - kaleci olurken  -> goalkeepers.contact_phone (zorunlu)
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
      and p.birth_date is not null
      -- telefon artık zorunlu değil
  );
$fn$;

comment on function public.is_profile_complete(uuid) is
  'Profil, takım kurmaya ve kaleci profiline yetecek kadar dolu mu? '
  'Ad, soyad ve doğum tarihi yeterli; telefon iletişim adımlarında ayrıca isteniyor.';

-- ---------------------------------------------------------------------
-- handle_new_user: telefon artık auth.users.phone'dan gelmeyecek
-- (telefonla kayıt kapalı), yalnızca e-posta kaydındaki metadata'dan
-- gelebilir. Fonksiyonun geri kalanı aynı; sadece niyeti netleştiriyoruz.
-- ---------------------------------------------------------------------
comment on function public.handle_new_user() is
  'Yeni auth.users kaydı için profiles satırı oluşturur. E-posta kaydında '
  'ad/soyad/doğum tarihi metadata ile gelir; Google girişinde full_name '
  'bölünür ve avatar_url alınır.';
