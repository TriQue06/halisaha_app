-- =====================================================================
-- handle_new_user trigger'ını üç giriş yöntemine birden uyarlar:
--   1. E-posta + şifre  -> data: {first_name, last_name, birth_date, phone}
--   2. Google           -> full_name / name / avatar_url / picture
--   3. Telefon (SMS OTP)-> auth.users.phone, metadata boş
--
-- Google ve telefon girişinde ad/soyad eksik veya hiç gelmez; uygulama
-- bu durumda "Profilini Tamamla" ekranını gösterir. Trigger elindekiyle
-- en iyi başlangıcı yapar, gerisini kullanıcı doldurur.
-- =====================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_meta       jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_birth      date;
  v_first      text;
  v_last       text;
  v_full_name  text;
  v_avatar     text;
  v_space_pos  int;
begin
  -- --- Doğum tarihi (yalnızca e-posta kaydında gelir) ------------------
  begin
    v_birth := nullif(v_meta ->> 'birth_date', '')::date;
  exception when others then
    v_birth := null;   -- hatalı format kaydı bozmasın
  end;

  -- --- Ad / soyad ------------------------------------------------------
  v_first := nullif(v_meta ->> 'first_name', '');
  v_last  := nullif(v_meta ->> 'last_name', '');

  -- Google 'full_name' veya 'name' gönderir; ad/soyad ayrı gelmez.
  if v_first is null and v_last is null then
    v_full_name := coalesce(
      nullif(v_meta ->> 'full_name', ''),
      nullif(v_meta ->> 'name', '')
    );

    if v_full_name is not null then
      v_full_name := trim(v_full_name);
      -- Son boşluktan böl: "Ali Rıza Tanlık" -> "Ali Rıza" + "Tanlık"
      v_space_pos := length(v_full_name) - position(' ' in reverse(v_full_name)) + 1;

      if position(' ' in v_full_name) > 0 then
        v_first := substring(v_full_name from 1 for v_space_pos - 1);
        v_last  := substring(v_full_name from v_space_pos + 1);
      else
        v_first := v_full_name;   -- tek kelimelik isim
      end if;
    end if;
  end if;

  -- --- Avatar (Google 'avatar_url' veya 'picture' gönderir) ------------
  v_avatar := coalesce(
    nullif(v_meta ->> 'avatar_url', ''),
    nullif(v_meta ->> 'picture', '')
  );

  insert into public.profiles (id, first_name, last_name, birth_date, phone, avatar_url, district)
  values (
    new.id,
    coalesce(v_first, ''),
    coalesce(v_last, ''),
    v_birth,
    -- Telefon girişinde auth.users.phone dolu gelir; e-postada metadata'dan.
    coalesce(nullif(v_meta ->> 'phone', ''), new.phone),
    v_avatar,
    nullif(v_meta ->> 'district', '')
  )
  on conflict (id) do nothing;   -- idempotent

  return new;
end;
$fn$;

-- =====================================================================
-- Profil eksiksiz mi? Uygulama "Profilini Tamamla" ekranını buna göre açar.
-- Takım kurmak ve kaleci profili için ad, doğum tarihi ve telefon şart.
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
      and coalesce(trim(p.phone), '')      <> ''
  );
$fn$;

grant execute on function public.is_profile_complete(uuid) to authenticated;
