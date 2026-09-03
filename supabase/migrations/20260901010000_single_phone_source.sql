-- =====================================================================
-- TEK TELEFON KAYNAGI
--
-- Numara uc ayri yerde tutuluyordu: profiles.phone, teams.contact_phone
-- ve goalkeepers.contact_phone. Kullanici takim kurarken/kaleci profili
-- olustururken numarayi elle yazdigi icin bunlar birbirinden ayrisiyor,
-- rakip kaptan yanlis numara goruyordu.
--
-- Bundan sonra tek dogru kaynak profiles.phone. teams ve goalkeepers
-- kolonlari korunuyor (RPC/view'lar onlara bagli) ama artik elle
-- yazilamiyor: insert/update sirasinda profilden dolduruluyor ve profil
-- numarasi degisince otomatik guncelleniyor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Takim ve kaleci numarasini profilden doldur
-- ---------------------------------------------------------------------
create or replace function public.fill_contact_phone_from_profile()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_owner uuid;
  v_phone text;
begin
  -- teams -> kaptanin profili, goalkeepers -> kaydin kendi id'si
  v_owner := case tg_table_name
               when 'teams' then new.captain_id
               else new.id
             end;

  select p.phone into v_phone from public.profiles p where p.id = v_owner;

  if v_phone is null or length(trim(v_phone)) = 0 then
    -- INSERT: numara olmadan kayit acilamaz.
    if tg_op = 'INSERT' then
      raise exception 'Once profilinize telefon numarasi ekleyin'
        using errcode = 'check_violation';
    end if;
    -- UPDATE: mevcut numarayi koru. Bu sart, cunku takim satirlari mac
    -- sonucu girilince G/B/M icin guncelleniyor; profilinde numara
    -- olmayan eski kullanicilarda hata firlatmak mac sonucunu bloklardi.
    new.contact_phone := old.contact_phone;
    return new;
  end if;

  new.contact_phone := v_phone;
  return new;
end;
$fn$;

drop trigger if exists trg_teams_contact_phone on public.teams;
create trigger trg_teams_contact_phone
  before insert or update on public.teams
  for each row execute function public.fill_contact_phone_from_profile();

drop trigger if exists trg_goalkeepers_contact_phone on public.goalkeepers;
create trigger trg_goalkeepers_contact_phone
  before insert or update on public.goalkeepers
  for each row execute function public.fill_contact_phone_from_profile();

-- ---------------------------------------------------------------------
-- 2. Profil numarasi degisince bagli kayitlari guncelle
-- ---------------------------------------------------------------------
create or replace function public.sync_phone_to_related()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if new.phone is distinct from old.phone and new.phone is not null then
    update public.teams       set contact_phone = new.phone where captain_id = new.id;
    update public.goalkeepers set contact_phone = new.phone where id = new.id;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_profiles_phone_sync on public.profiles;
create trigger trg_profiles_phone_sync
  after update of phone on public.profiles
  for each row execute function public.sync_phone_to_related();

-- ---------------------------------------------------------------------
-- 3. Mevcut kayitlari profildeki numarayla hizala
-- ---------------------------------------------------------------------
update public.teams t
   set contact_phone = p.phone
  from public.profiles p
 where p.id = t.captain_id
   and p.phone is not null
   and t.contact_phone is distinct from p.phone;

update public.goalkeepers g
   set contact_phone = p.phone
  from public.profiles p
 where p.id = g.id
   and p.phone is not null
   and g.contact_phone is distinct from p.phone;

-- ---------------------------------------------------------------------
-- 4. Profil telefonunu guncelleme RPC'si
--    Bicimi tek yerde normalize eder: bosluk/parantez/tire atilir,
--    Turkiye numaralari +90 onekine cevrilir.
-- ---------------------------------------------------------------------
create or replace function public.update_my_phone(p_phone text)
returns text
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_digits text;
  v_phone  text;
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli' using errcode = 'insufficient_privilege';
  end if;

  v_digits := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');

  -- 00 90 5xx / 90 5xx / 0 5xx / 5xx  -> +905xx
  if v_digits like '00%'  then v_digits := substring(v_digits from 3); end if;
  if length(v_digits) = 12 and v_digits like '90%' then
    v_phone := '+' || v_digits;
  elsif length(v_digits) = 11 and v_digits like '0%' then
    v_phone := '+90' || substring(v_digits from 2);
  elsif length(v_digits) = 10 then
    v_phone := '+90' || v_digits;
  else
    v_phone := '+' || v_digits;
  end if;

  if v_phone !~ '^\+?[0-9]{10,15}$' then
    raise exception 'Gecerli bir telefon numarasi girin'
      using errcode = 'check_violation';
  end if;

  update public.profiles set phone = v_phone where id = auth.uid();
  return v_phone;
end;
$fn$;

grant execute on function public.update_my_phone(text) to authenticated;
