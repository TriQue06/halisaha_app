-- =====================================================================
-- DUZELTME: fill_contact_phone_from_profile() kaleci kaydinda patliyor
--
-- Hata: record "new" has no field "captain_id" (42703)
--
-- Onceki surum sahibi tek bir CASE ifadesiyle seciyordu:
--   v_owner := case tg_table_name when 'teams' then new.captain_id
--                                 else new.id end;
-- PL/pgSQL bir ifadeyi calistirmadan once TAMAMINI hazirliyor; bu sirada
-- secilmeyecek daldaki new.captain_id de cozulmeye calisiliyor.
-- goalkeepers tablosunda o kolon olmadigi icin kaleci profili
-- kaydedilemiyordu (takim tarafi etkilenmiyordu).
--
-- IF dallari ayri ayri ve yalnizca calistiklarinda hazirlandigi icin
-- teams dali goalkeepers satirinda hic cozulmuyor.
--
-- Trigger'lar ayni fonksiyonu kullandigi icin yeniden olusturmaya gerek
-- yok; create or replace yeterli.
-- =====================================================================

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
  if tg_table_name = 'teams' then
    v_owner := new.captain_id;
  else
    v_owner := new.id;
  end if;

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
