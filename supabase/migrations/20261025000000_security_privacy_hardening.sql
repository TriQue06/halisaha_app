-- =====================================================================
-- GUVENLIK, GIZLILIK VE MODERASYON SAGLAMLASTIRMASI
-- (App Store 1.2, 1.6, 5.1 + kod incelemesi bulgulari)
--
--  1. Ic fonksiyonlarin PUBLIC calistirma yetkisi kapatiliyor
--     (apply_match_result_to_stats ile G/B/M elle sisirilebiliyordu).
--  2. Telefon ve dogum tarihi artik baska kullanicilara okunamiyor
--     (kolon bazli yetki); kendi profil satiri get_my_profile() ile.
--  3. matches tablosuna dogrudan yazma kapandi; her sey RPC ile.
--  4. Banli hesap hicbir yoldan yazamiyor; engelleme temel tablolarda.
--  5. Kayitli olmayan oyuncularin soyadi herkese acik degil (bas harf).
--  6. Uygunsuz ifade filtresi (takim adi, oyuncu, kaleci aciklamasi, ad).
--  7. Yeni rapor geldiginde yoneticilere bildirim (app_admins).
--  8. Bildirim tercihleri sunucuda; kosul kabulu kayit altinda.
--  9. 18 yas kurali sunucuda; yanitlanmayan teklifler 7 gunde dusuyor.
-- 10. Sonucu teklif sahibi girmezse rakip kaptan da girebiliyor.
--
-- ONCE 20261002 ve 20261003 migration'lari calismis olmali.
-- DIKKAT: Bu dosyadan sonra uygulamanin ESKI surumleri profil ve takim
-- okuyamaz; yeni surum (1.0.2) dagitilirken calistirin.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. IC FONKSIYONLAR: yalnizca trigger/sunucu cagirabilir
--    Postgres'te fonksiyonlar varsayilan olarak PUBLIC'e aciktir;
--    yalnizca anon/authenticated'dan almak yetmez.
-- ---------------------------------------------------------------------
revoke all on function public.apply_match_result_to_stats(uuid, uuid, public.match_result, int)
  from public, anon, authenticated;
revoke all on function public.auto_cancel_stale_matches() from public, anon, authenticated;
revoke all on function public.send_match_result_prompts() from public, anon, authenticated;
revoke all on function public.create_notification(uuid, public.notification_type, text, text, uuid, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.auto_cancel_stale_matches() to service_role;
grant execute on function public.send_match_result_prompts() to service_role;

-- Herkese acik kalan RPC'ler anonim kullaniciya kapatiliyor.
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.challenge_team(uuid, uuid, text)',
    'public.respond_to_challenge(uuid, boolean)',
    'public.confirm_match(uuid)',
    'public.report_match_result(uuid, text)',
    'public.cancel_match(uuid, text)',
    'public.rate_goalkeeper(uuid, smallint, text)',
    'public.get_opponent_contact(uuid)',
    'public.mark_notifications_read(uuid[])',
    'public.update_my_phone(text)',
    'public.register_device_token(text, text)',
    'public.unregister_device_token(text)',
    'public.get_team_match_history(uuid, int)'
  ] loop
    begin
      execute format('revoke all on function %s from public, anon', f);
      execute format('grant execute on function %s to authenticated', f);
    exception when undefined_function then
      raise notice 'Fonksiyon yok, atlandi: %', f;
    end;
  end loop;
end;
$$;


-- ---------------------------------------------------------------------
-- 2. PROFIL: yeni alanlar + kendi profilini okuma RPC'si
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists notify_challenges boolean not null default true,
  add column if not exists notify_matches    boolean not null default true,
  add column if not exists terms_version     text,
  add column if not exists terms_accepted_at timestamptz;

-- Kendi profil satiri (telefon ve dogum tarihi dahil). Satir yoksa
-- (kayit trigger'i calismadiysa) giris saglayicisinin verdigi adla
-- olusturulur: giristen sonra hata ekrani cikmasin (App Store 2.1).
create or replace function public.get_my_profile()
returns public.profiles
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_row  public.profiles;
  v_meta jsonb;
  v_full text;
begin
  if v_uid is null then
    raise exception 'Oturum gerekli' using errcode = 'insufficient_privilege';
  end if;

  select * into v_row from public.profiles where id = v_uid;
  if v_row.id is not null then
    return v_row;
  end if;

  select coalesce(raw_user_meta_data, '{}'::jsonb) into v_meta from auth.users where id = v_uid;
  v_full := btrim(coalesce(v_meta ->> 'full_name', v_meta ->> 'name', ''));

  insert into public.profiles (id, first_name, last_name)
  values (
    v_uid,
    left(coalesce(nullif(btrim(v_meta ->> 'first_name'), ''),
                  nullif(btrim(v_meta ->> 'given_name'), ''),
                  split_part(v_full, ' ', 1), ''), 40),
    left(coalesce(nullif(btrim(v_meta ->> 'last_name'), ''),
                  nullif(btrim(v_meta ->> 'family_name'), ''),
                  nullif(btrim(substr(v_full, length(split_part(v_full, ' ', 1)) + 1)), ''),
                  ''), 40)
  )
  on conflict (id) do nothing;

  select * into v_row from public.profiles where id = v_uid;
  return v_row;
end;
$fn$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

-- Bildirim tercihleri (push fonksiyonu bunlara bakarak gonderir).
create or replace function public.set_notification_prefs(p_challenges boolean, p_matches boolean)
returns void
language sql
security definer
set search_path = public, pg_temp
as $fn$
  update public.profiles
     set notify_challenges = coalesce(p_challenges, notify_challenges),
         notify_matches    = coalesce(p_matches, notify_matches)
   where id = auth.uid();
$fn$;

revoke all on function public.set_notification_prefs(boolean, boolean) from public, anon;
grant execute on function public.set_notification_prefs(boolean, boolean) to authenticated;

-- Kullanim kosullari kabulunun kaydi (hangi surum, ne zaman).
create or replace function public.accept_terms(p_version text)
returns void
language sql
security definer
set search_path = public, pg_temp
as $fn$
  update public.profiles
     set terms_version = left(p_version, 20),
         terms_accepted_at = now()
   where id = auth.uid()
     and terms_version is distinct from left(p_version, 20);
$fn$;

revoke all on function public.accept_terms(text) from public, anon;
grant execute on function public.accept_terms(text) to authenticated;


-- ---------------------------------------------------------------------
-- 3. KOLON BAZLI OKUMA: telefon ve dogum tarihi gizli
--    Tablo duzeyindeki SELECT kaldirilip yalnizca acik kolonlar veriliyor.
-- ---------------------------------------------------------------------
revoke select on public.profiles from anon, authenticated;
grant select (id, first_name, last_name, avatar_url, district, created_at, updated_at)
  on public.profiles to authenticated;

revoke select on public.teams from anon, authenticated;
grant select (id, pitch_id, captain_id, name, logo_url, description,
              wins, draws, losses, is_active, created_at, updated_at)
  on public.teams to authenticated;

-- profiles_with_age tum kolonlari aciyordu; uygulama kullanmiyor.
revoke all on public.profiles_with_age from anon, authenticated;

-- teams_with_stats: contact_phone olmadan yeniden (kolon dusurmek icin drop).
drop view if exists public.teams_with_stats;
create view public.teams_with_stats
with (security_invoker = true) as
  select t.id, t.pitch_id, t.captain_id, t.name, t.logo_url, t.description,
         t.wins, t.draws, t.losses, t.is_active, t.created_at, t.updated_at,
         (t.wins + t.draws + t.losses) as played,
         (t.wins * 3 + t.draws)        as points,
         case when (t.wins + t.draws + t.losses) = 0 then 0
              else round(t.wins::numeric * 100 / (t.wins + t.draws + t.losses), 1)
         end                           as win_rate
  from public.teams t
  where not public.is_hidden_from_me(t.captain_id);

revoke all on public.teams_with_stats from anon, authenticated;
grant select on public.teams_with_stats to authenticated;

-- Kaleci listesi yasi gosteriyor ama dogum tarihini artik okuyamiyor:
-- view sahibi yetkisiyle calisir, yalnizca yas doner. Engelleme filtresi
-- view icinde (auth.uid() view sahibinde de cagiranin kimligidir).
-- Kalecinin numarasi bilerek acik: kaleci ilanina iletisim icin koyuyor.
drop view if exists public.goalkeeper_profiles;
create view public.goalkeeper_profiles
with (security_invoker = false) as
  select g.id,
         p.first_name,
         p.last_name,
         p.avatar_url,
         public.calculate_age(p.birth_date) as age,
         g.districts,
         g.about,
         g.contact_phone,
         g.is_available,
         g.rating_avg,
         g.rating_count,
         g.created_at
  from public.goalkeepers g
  join public.profiles p on p.id = g.id
  where not public.is_hidden_from_me(g.id);

revoke all on public.goalkeeper_profiles from anon, authenticated;
grant select on public.goalkeeper_profiles to authenticated;

-- Rakibin telefonu yalnizca iki taraf "Maca Hazirim" dedikten sonra
-- (onceden 'accepted' asamasinda da donuyordu).
create or replace function public.get_opponent_contact(p_match_id uuid)
returns table (team_id uuid, team_name text, contact_phone text, captain_name text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
  v_uid   uuid := auth.uid();
  v_opp   uuid;
begin
  select * into v_match from public.matches where id = p_match_id;

  if v_match.id is null or v_match.status not in ('mutually_agreed','scheduled') then
    raise exception 'Iletisim bilgisi bu asamada goruntulenemez';
  end if;

  if public.is_team_captain(v_match.challenger_team_id, v_uid) then
    v_opp := v_match.opponent_team_id;
  elsif public.is_team_captain(v_match.opponent_team_id, v_uid) then
    v_opp := v_match.challenger_team_id;
  else
    raise exception 'Bu macin tarafi degilsiniz' using errcode = 'insufficient_privilege';
  end if;

  return query
    select t.id, t.name, t.contact_phone, trim(pr.first_name || ' ' || pr.last_name)
    from public.teams t
    join public.profiles pr on pr.id = t.captain_id
    where t.id = v_opp;
end;
$fn$;


-- ---------------------------------------------------------------------
-- 4. ENGELLEME VE BAN TEMEL TABLOLARDA
-- ---------------------------------------------------------------------
drop policy if exists "teams_select_authenticated" on public.teams;
create policy "teams_select_authenticated"
  on public.teams for select
  to authenticated
  using (not public.is_hidden_from_me(captain_id));

drop policy if exists "goalkeepers_select_authenticated" on public.goalkeepers;
create policy "goalkeepers_select_authenticated"
  on public.goalkeepers for select
  to authenticated
  using (not public.is_hidden_from_me(id));

-- Banli hesap hicbir tabloya yazamaz. Hesap silme (DELETE) serbest.
-- Mac sonucu trigger'inin takim istatistigi guncellemesi (bypass_guards)
-- ve sunucu islemleri (auth.uid() bos) etkilenmez.
create or replace function public.block_banned_writes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if auth.uid() is null
     or coalesce(current_setting('app.bypass_guards', true), 'off') = 'on' then
    return new;
  end if;
  if exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_banned) then
    raise exception 'Hesabin askiya alindigi icin bu islem yapilamaz'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$fn$;

do $$
declare
  t text;
begin
  foreach t in array array['teams','goalkeepers','goalkeeper_ratings','matches',
                           'team_players','match_lineups','reports','blocked_users'] loop
    execute format('drop trigger if exists trg_block_banned_writes on public.%I', t);
    execute format('create trigger trg_block_banned_writes before insert or update on public.%I
                    for each row execute function public.block_banned_writes()', t);
  end loop;
end;
$$;


-- ---------------------------------------------------------------------
-- 5. MACLAR: dogrudan yazma kapali, RPC'ler yetkiyi kendisi denetler
-- ---------------------------------------------------------------------
revoke insert, update, delete on public.matches from anon, authenticated;

-- Bu RPC'ler RLS'e (dogrudan yazma yetkisine) dayaniyordu; artik sahibi
-- yetkisiyle calisiyor. Yetki kontrolleri fonksiyon icinde ve
-- handle_match_transition trigger'inda (auth.uid() ile) yapiliyor.
alter function public.challenge_team(uuid, uuid, text)    security definer;
alter function public.respond_to_challenge(uuid, boolean) security definer;
alter function public.confirm_match(uuid)                 security definer;
alter function public.report_match_result(uuid, text)     security definer;

-- Iptal: artik yalnizca macin taraflari (RLS yerine acik kontrol).
create or replace function public.cancel_match(p_match_id uuid, p_reason text default null)
returns public.matches
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
begin
  if not public.is_match_participant(p_match_id) then
    raise exception 'Bu macin tarafi degilsiniz' using errcode = 'insufficient_privilege';
  end if;

  update public.matches
  set status = 'cancelled', cancelled_by = auth.uid(), cancel_reason = left(p_reason, 200)
  where id = p_match_id
    and status in ('pending','accepted','mutually_agreed','scheduled')
  returning * into v_match;

  if v_match.id is null then
    raise exception 'Iptal edilebilecek bir mac bulunamadi';
  end if;

  return v_match;
end;
$fn$;

-- Durum gecisleri (20260826 surumu) + iki degisiklik:
--  * yanitlanmayan teklif 'pending' -> 'auto_cancelled' dusebilir,
--  * sonuc RPC uzerinden rakip kaptan tarafindan da girilebilir.
-- Ayrica takim/saha kimlikleri sonradan degistirilemez.
create or replace function public.handle_match_transition()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_is_challenger boolean;
  v_is_opponent   boolean;
  v_via_rpc       boolean := coalesce(current_setting('app.match_detail_rpc', true), 'off') = 'on';
begin
  v_is_challenger := v_uid is not null and public.is_team_captain(new.challenger_team_id, v_uid);
  v_is_opponent   := v_uid is not null and public.is_team_captain(new.opponent_team_id,  v_uid);

  if new.challenger_team_id is distinct from old.challenger_team_id
     or new.opponent_team_id is distinct from old.opponent_team_id
     or new.pitch_id is distinct from old.pitch_id then
    raise exception 'Macin takimlari ve sahasi degistirilemez' using errcode = 'insufficient_privilege';
  end if;

  if new.status is distinct from old.status then
    if not (
         (old.status = 'pending'         and new.status in ('accepted','rejected','cancelled','auto_cancelled'))
      or (old.status = 'accepted'        and new.status in ('mutually_agreed','cancelled','auto_cancelled'))
      or (old.status = 'mutually_agreed' and new.status in ('scheduled','cancelled'))
      or (old.status = 'scheduled'       and new.status in ('completed','cancelled'))
    ) then
      raise exception 'Gecersiz mac statu gecisi: % -> %', old.status, new.status
        using errcode = 'check_violation';
    end if;
  end if;

  if v_uid is not null then
    if old.status = 'pending' and new.status in ('accepted','rejected') and not v_is_opponent then
      raise exception 'Meydan okumayi yalnizca rakip takim kaptani yanitlayabilir'
        using errcode = 'insufficient_privilege';
    end if;

    if new.match_date is distinct from old.match_date and not v_is_challenger then
      raise exception 'Mac gun/saatini yalnizca meydan okuyan takim girebilir'
        using errcode = 'insufficient_privilege';
    end if;

    -- Sonuc: teklif sahibi her zaman; rakip kaptan yalnizca skor RPC'si ile.
    if new.result is distinct from old.result
       and not (v_is_challenger or (v_via_rpc and v_is_opponent)) then
      raise exception 'Mac sonucunu yalnizca maci oynayan takimlar bildirebilir'
        using errcode = 'insufficient_privilege';
    end if;

    if new.challenger_confirmed_at is distinct from old.challenger_confirmed_at and not v_is_challenger then
      raise exception 'Baska takim adina mac kabulu verilemez' using errcode = 'insufficient_privilege';
    end if;
    if new.opponent_confirmed_at is distinct from old.opponent_confirmed_at and not v_is_opponent then
      raise exception 'Baska takim adina mac kabulu verilemez' using errcode = 'insufficient_privilege';
    end if;
  end if;

  if old.status = 'pending' and new.status in ('accepted','rejected') then
    new.responded_at := coalesce(new.responded_at, now());
    if new.status = 'accepted' then
      new.cancel_deadline := coalesce(new.cancel_deadline, now() + interval '7 days');
    end if;
  end if;

  if new.status = 'accepted'
     and new.challenger_confirmed_at is not null
     and new.opponent_confirmed_at   is not null then
    new.status   := 'mutually_agreed';
    new.agreed_at := now();
  end if;

  if new.status = 'mutually_agreed' and new.match_date is not null then
    new.status := 'scheduled';
  end if;

  if new.result is not null and old.result is null then
    new.status             := 'completed';
    new.result_reported_at := coalesce(new.result_reported_at, now());
    new.result_reported_by := coalesce(new.result_reported_by, v_uid);
  end if;

  return new;
end;
$fn$;

-- Kabul edilmeyen (accepted) ve hic yanitlanmayan (pending) maclar 7 gunde duser.
create or replace function public.auto_cancel_stale_matches()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_count int;
begin
  with stale as (
    update public.matches
    set status = 'auto_cancelled',
        cancel_reason = case when status = 'pending'
                             then '1 hafta icinde teklife yanit verilmedi'
                             else '1 hafta icinde karsilikli mac kabulu verilmedi' end
    where (status = 'accepted' and cancel_deadline is not null and cancel_deadline < now())
       or (status = 'pending' and created_at < now() - interval '7 days')
    returning id
  )
  select count(*) into v_count from stale;
  return v_count;
end;
$fn$;
revoke all on function public.auto_cancel_stale_matches() from public, anon, authenticated;
grant execute on function public.auto_cancel_stale_matches() to service_role;

-- Skor: teklif sahibi hemen, rakip kaptan teklif sahibi 24 saat icinde
-- girmezse. Mac saatinden 1 saat sonra acilir (uygulamayla ayni kural).
create or replace function public.report_match_score(
  p_match_id       uuid,
  p_my_score       int,
  p_opponent_score int,
  p_stats          jsonb default '[]'::jsonb
)
returns public.matches
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_match  public.matches;
  v_result public.match_result;
  v_mine   uuid;
  v_ch     int;
  v_op     int;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match.id is null or v_match.status <> 'scheduled' or v_match.result is not null then
    raise exception 'Sonuc girilebilecek bir mac bulunamadi';
  end if;
  if v_match.match_date is null or v_match.match_date + interval '1 hour' > now() then
    raise exception 'Skor, mac saatinden 1 saat sonra girilebilir';
  end if;
  if p_my_score not between 0 and 99 or p_opponent_score not between 0 and 99 then
    raise exception 'Skor 0 ile 99 arasinda olmali' using errcode = 'check_violation';
  end if;

  if public.is_team_captain(v_match.challenger_team_id) then
    v_mine := v_match.challenger_team_id;
    v_ch := p_my_score;  v_op := p_opponent_score;
  elsif public.is_team_captain(v_match.opponent_team_id) then
    if v_match.match_date + interval '25 hours' > now() then
      raise exception 'Skoru once teklifi gonderen takim girer; 24 saat icinde girmezse sen girebilirsin';
    end if;
    v_mine := v_match.opponent_team_id;
    v_ch := p_opponent_score;  v_op := p_my_score;
  else
    raise exception 'Mac skorunu yalnizca maci oynayan takimlar girebilir'
      using errcode = 'insufficient_privilege';
  end if;

  v_result := case
                when v_ch > v_op then 'challenger_won'
                when v_ch = v_op then 'draw'
                else 'challenger_lost'
              end::public.match_result;

  perform set_config('app.match_detail_rpc', 'on', true);
  update public.matches
     set challenger_score = v_ch,
         opponent_score   = v_op,
         result           = v_result
   where id = p_match_id
  returning * into v_match;
  perform set_config('app.match_detail_rpc', 'off', true);

  perform public._apply_player_stats(p_match_id, v_mine, p_my_score, p_stats);
  return v_match;
end;
$fn$;
revoke all on function public.report_match_score(uuid, int, int, jsonb) from public, anon;
grant execute on function public.report_match_score(uuid, int, int, jsonb) to authenticated;

-- Kadro, mac bittikten sonraki 7 gun icinde de secilebilir (gol/asist
-- girmek icin; maca kadrosuz cikan takimlar icin).
create or replace function public.set_match_lineup(p_match_id uuid, p_player_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
  v_team  uuid;
  v_count int := coalesce(array_length(p_player_ids, 1), 0);
  v_keep  jsonb;
begin
  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Mac bulunamadi';
  end if;

  if public.is_team_captain(v_match.challenger_team_id) then
    v_team := v_match.challenger_team_id;
  elsif public.is_team_captain(v_match.opponent_team_id) then
    v_team := v_match.opponent_team_id;
  else
    raise exception 'Mac kadrosunu yalnizca takim kaptanlari secebilir'
      using errcode = 'insufficient_privilege';
  end if;

  if v_match.team_size is null
     or not (v_match.status = 'scheduled'
             or (v_match.status = 'completed'
                 and v_match.result_reported_at > now() - interval '7 days')) then
    raise exception 'Kadro, mac gunu ve kac kisilik oldugu belirlendikten sonra secilebilir';
  end if;
  if v_count <> v_match.team_size then
    raise exception 'Bu mac % kisilik; tam % oyuncu secmelisin', v_match.team_size, v_match.team_size
      using errcode = 'check_violation';
  end if;
  if (select count(distinct x) from unnest(p_player_ids) x) <> v_count then
    raise exception 'Ayni oyuncu iki kez secilemez' using errcode = 'check_violation';
  end if;
  if (select count(*) from public.team_players
       where id = any (p_player_ids) and team_id = v_team and is_active) <> v_count then
    raise exception 'Secilen oyuncular takim kadrosunda degil' using errcode = 'check_violation';
  end if;

  -- Ayni oyuncu yeniden secildiyse gol/asisti korunsun.
  select coalesce(jsonb_object_agg(player_id::text, jsonb_build_array(goals, assists)), '{}'::jsonb)
    into v_keep
    from public.match_lineups
   where match_id = p_match_id and team_id = v_team and player_id is not null;

  delete from public.match_lineups where match_id = p_match_id and team_id = v_team;
  insert into public.match_lineups (match_id, team_id, player_id, first_name, last_name, slot, goals, assists)
  select p_match_id, v_team, tp.id, tp.first_name, tp.last_name, u.ord::smallint,
         coalesce((v_keep -> tp.id::text ->> 0)::smallint, 0),
         coalesce((v_keep -> tp.id::text ->> 1)::smallint, 0)
    from unnest(p_player_ids) with ordinality as u(pid, ord)
    join public.team_players tp on tp.id = u.pid;
end;
$fn$;
revoke all on function public.set_match_lineup(uuid, uuid[]) from public, anon;
grant execute on function public.set_match_lineup(uuid, uuid[]) to authenticated;


-- ---------------------------------------------------------------------
-- 6. KAYITLI OLMAYAN OYUNCULAR: soyad herkese acik degil
--    Herkes "Ahmet Y." gorur; tam ad yalnizca takimin kaptanina.
--    Soyad artik istege bagli (takma ad kullanilabilir).
-- ---------------------------------------------------------------------
alter table public.team_players drop constraint if exists team_players_last_name_chk;
alter table public.team_players add constraint team_players_last_name_chk
  check (char_length(btrim(last_name)) <= 40);
alter table public.match_lineups alter column last_name set default '';

alter table public.team_players
  add column if not exists display_name text
  generated always as (
    btrim(first_name) || case when btrim(last_name) = '' then ''
                              else ' ' || upper(left(btrim(last_name), 1)) || '.' end
  ) stored;
alter table public.match_lineups
  add column if not exists display_name text
  generated always as (
    btrim(first_name) || case when btrim(coalesce(last_name, '')) = '' then ''
                              else ' ' || upper(left(btrim(last_name), 1)) || '.' end
  ) stored;

revoke select on public.team_players, public.match_lineups from anon, authenticated;
grant select (id, team_id, display_name, is_active, created_at, updated_at)
  on public.team_players to authenticated;
grant select (id, match_id, team_id, player_id, display_name, slot, goals, assists, created_at)
  on public.match_lineups to authenticated;

-- Istatistik view'lari gorunen adla yeniden.
drop view if exists public.pitch_player_stats;
drop view if exists public.team_player_stats;

create view public.team_player_stats
with (security_invoker = true) as
  select tp.id         as player_id,
         tp.team_id,
         tp.display_name,
         tp.is_active,
         count(l.id) filter (where m.status = 'completed')::int                 as appearances,
         coalesce(sum(l.goals)   filter (where m.status = 'completed'), 0)::int as goals,
         coalesce(sum(l.assists) filter (where m.status = 'completed'), 0)::int as assists
  from public.team_players tp
  left join public.match_lineups l on l.player_id = tp.id
  left join public.matches m       on m.id = l.match_id
  group by tp.id;

create view public.pitch_player_stats
with (security_invoker = true) as
  select s.player_id,
         s.display_name,
         s.appearances,
         s.goals,
         s.assists,
         t.id    as team_id,
         t.name  as team_name,
         t.pitch_id
  from public.team_player_stats s
  join public.teams t on t.id = s.team_id
  where t.is_active
    and s.appearances > 0
    and not public.is_hidden_from_me(t.captain_id);

revoke all on public.team_player_stats, public.pitch_player_stats from anon, authenticated;
grant select on public.team_player_stats, public.pitch_player_stats to authenticated;

-- Kaptanin kadro duzenleme ekrani icin tam adlar.
create or replace function public.get_team_roster_full(p_team_id uuid)
returns table (id uuid, first_name text, last_name text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_team_captain(p_team_id) then
    raise exception 'Kadronun tam listesini yalnizca kaptan gorebilir'
      using errcode = 'insufficient_privilege';
  end if;
  return query
    select tp.id, tp.first_name, tp.last_name
      from public.team_players tp
     where tp.team_id = p_team_id and tp.is_active
     order by tp.created_at, tp.first_name;
end;
$fn$;
revoke all on function public.get_team_roster_full(uuid) from public, anon;
grant execute on function public.get_team_roster_full(uuid) to authenticated;

-- Kadro kaydi: soyad istege bagli.
create or replace function public._apply_team_roster(p_team_id uuid, p_players jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_item  jsonb;
  v_id    uuid;
  v_first text;
  v_last  text;
  v_keep  uuid[] := '{}';
begin
  if p_players is null or jsonb_typeof(p_players) <> 'array' then
    raise exception 'Kadro listesi gecersiz';
  end if;
  if jsonb_array_length(p_players) < 7 then
    raise exception 'Kadroda en az 7 oyuncu olmali' using errcode = 'check_violation';
  end if;
  if jsonb_array_length(p_players) > 30 then
    raise exception 'Kadroda en fazla 30 oyuncu olabilir' using errcode = 'check_violation';
  end if;

  for v_item in select * from jsonb_array_elements(p_players) loop
    v_first := btrim(coalesce(v_item ->> 'first_name', ''));
    v_last  := btrim(coalesce(v_item ->> 'last_name', ''));
    if v_first = '' then
      raise exception 'Her oyuncunun adi (veya takma adi) girilmeli' using errcode = 'check_violation';
    end if;

    v_id := nullif(v_item ->> 'id', '')::uuid;
    if v_id is not null then
      update public.team_players
         set first_name = v_first, last_name = v_last, is_active = true, updated_at = now()
       where id = v_id and team_id = p_team_id
      returning id into v_id;
    end if;
    if v_id is null then
      insert into public.team_players (team_id, first_name, last_name)
      values (p_team_id, v_first, v_last)
      returning id into v_id;
    end if;
    v_keep := v_keep || v_id;
  end loop;

  update public.team_players
     set is_active = false, updated_at = now()
   where team_id = p_team_id and is_active and id <> all (v_keep);
end;
$fn$;
revoke all on function public._apply_team_roster(uuid, jsonb) from public, anon, authenticated;
revoke all on function public._apply_player_stats(uuid, uuid, int, jsonb) from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 7. UYGUNSUZ IFADE FILTRESI (App Store 1.2)
--    Sozcuk basina bakar; "sıkı", "sikke" gibi masum kelimeler gecer.
-- ---------------------------------------------------------------------
create or replace function public.has_objectionable_text(p_text text)
returns boolean
language sql
immutable
as $fn$
  select coalesce(lower(p_text), '') ~* (
    '(^|[^[:alnum:]çğıöşü])('
    || 'amk|amq|aq|a\.q|amına|amina|amcık|amcik|ananı|anani|ananızı'
    || '|orospu|orosbu|oç|o\.ç|piç|pic|siktir|sikerim|sikeyim|siktiğim|siktigim|sikik|sikim|sikis|sikiş|sik'
    || '|yarrak|yarak|yarram|göt|götveren|gotveren|ibne|kahpe|pezevenk|pezeveng|gavat|yavşak|yavsak'
    || '|kaltak|şerefsiz|serefsiz|puşt|pust|dalyarak|dallama'
    || '|fuck|fucking|fucker|shit|bitch|cunt|whore|slut|dick|pussy|nigger|nigga|faggot|porn|porno|sex|seks'
    || ')([^[:alnum:]çğıöşü]|$)'
  );
$fn$;

create or replace function public.reject_objectionable_text()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $fn$
declare
  v_text text := '';
begin
  -- Ayri IF dallari sart: tek bir CASE ifadesi tum dallardaki alanlari
  -- (ornegin goalkeepers'ta olmayan new.name) derlemeye calisip hata verir.
  if tg_table_name = 'teams' then
    v_text := coalesce(new.name, '') || ' ' || coalesce(new.description, '');
  elsif tg_table_name = 'goalkeepers' then
    v_text := coalesce(new.about, '');
  elsif tg_table_name in ('team_players', 'profiles') then
    v_text := coalesce(new.first_name, '') || ' ' || coalesce(new.last_name, '');
  end if;
  if public.has_objectionable_text(v_text) then
    raise exception 'Uygunsuz ifade iceriyor; lutfen duzeltin' using errcode = 'check_violation';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_text_filter on public.teams;
create trigger trg_text_filter before insert or update of name, description on public.teams
  for each row execute function public.reject_objectionable_text();
drop trigger if exists trg_text_filter on public.goalkeepers;
create trigger trg_text_filter before insert or update of about on public.goalkeepers
  for each row execute function public.reject_objectionable_text();
drop trigger if exists trg_text_filter on public.team_players;
create trigger trg_text_filter before insert or update of first_name, last_name on public.team_players
  for each row execute function public.reject_objectionable_text();
drop trigger if exists trg_text_filter on public.profiles;
create trigger trg_text_filter before insert or update of first_name, last_name on public.profiles
  for each row execute function public.reject_objectionable_text();


-- ---------------------------------------------------------------------
-- 8. RAPOR GELINCE YONETICILERE BILDIRIM
--    Yonetici eklemek (SQL Editor):
--      insert into public.app_admins (user_id)
--      select id from auth.users where email = 'ornek@gmail.com';
-- ---------------------------------------------------------------------
create table if not exists public.app_admins (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.app_admins enable row level security;
revoke all on public.app_admins from anon, authenticated;

create or replace function public.notify_admins_of_report()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  r record;
begin
  for r in select user_id from public.app_admins loop
    perform public.create_notification(
      r.user_id,
      'generic',
      'Yeni rapor',
      'Bir kullanici raporlandi (' || new.reason || '). Supabase > reports_inbox uzerinden 24 saat icinde inceleyin.',
      null, null,
      jsonb_build_object('action', 'review_report', 'report_id', new.id)
    );
  end loop;
  return new;
end;
$fn$;

drop trigger if exists trg_reports_notify_admins on public.reports;
create trigger trg_reports_notify_admins
  after insert on public.reports
  for each row execute function public.notify_admins_of_report();


-- ---------------------------------------------------------------------
-- 9. YAS: 18 yas alti dogum tarihi kaydedilemez (kosullarla ayni kural)
-- ---------------------------------------------------------------------
create or replace function public.enforce_adult_birth_date()
returns trigger
language plpgsql
as $fn$
begin
  if new.birth_date is not null
     and new.birth_date > (current_date - interval '18 years')::date then
    raise exception 'Japon Kale 18 yas ve uzeri icindir' using errcode = 'check_violation';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_profiles_adult on public.profiles;
create trigger trg_profiles_adult before insert or update of birth_date on public.profiles
  for each row execute function public.enforce_adult_birth_date();

notify pgrst, 'reload schema';
