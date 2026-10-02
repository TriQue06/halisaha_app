-- =====================================================================
-- Takim kadrolari, mac kadrosu (5v5 - 11v11), skor ve oyuncu istatistikleri
-- =====================================================================
-- * team_players   : takimin kadro havuzu (sistemde kayitli olmasi gerekmez)
-- * matches        : team_size (5-11), challenger_score, opponent_score
-- * match_lineups  : maca cikan oyuncular + gol / asist
-- * Kurallar       : kadroda en az 7 oyuncu yoksa teklif gonderilemez/kabul
--                    edilemez; kadro, skor ve istatistik yalnizca RPC ile yazilir
-- * Okuma          : team_player_stats, pitch_player_stats (gol/asist kralligi),
--                    get_team_match_history (skorlu)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. KADRO HAVUZU
-- ---------------------------------------------------------------------
create table if not exists public.team_players (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid        not null references public.teams (id) on delete cascade,
  first_name  text        not null,
  last_name   text        not null,
  -- Ileride oyuncuyu kayitli bir kullaniciyla eslestirmek icin (opsiyonel).
  profile_id  uuid        references public.profiles (id) on delete set null,
  -- Kadrodan cikarilan oyuncu silinmez, pasiflesir: gecmis maclari ve
  -- istatistikleri kaybolmasin.
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint team_players_first_name_chk check (char_length(btrim(first_name)) between 1 and 40),
  constraint team_players_last_name_chk  check (char_length(btrim(last_name))  between 1 and 40)
);

create index if not exists idx_team_players_team on public.team_players (team_id) where is_active;

-- Takimin aktif kadro sayisi
create or replace function public.team_roster_size(p_team_id uuid)
returns int
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $fn$
  select count(*)::int from public.team_players where team_id = p_team_id and is_active;
$fn$;

-- ---------------------------------------------------------------------
-- 2. MAC ALANLARI
-- ---------------------------------------------------------------------
alter table public.matches
  add column if not exists team_size        smallint,
  add column if not exists challenger_score smallint,
  add column if not exists opponent_score   smallint;

alter table public.matches drop constraint if exists matches_team_size_chk;
alter table public.matches add constraint matches_team_size_chk
  check (team_size is null or team_size between 5 and 11);

alter table public.matches drop constraint if exists matches_scores_chk;
alter table public.matches add constraint matches_scores_chk
  check (
    (challenger_score is null and opponent_score is null)
    or (challenger_score between 0 and 99 and opponent_score between 0 and 99
        and (   (result = 'challenger_won'  and challenger_score >  opponent_score)
             or (result = 'draw'            and challenger_score =  opponent_score)
             or (result = 'challenger_lost' and challenger_score <  opponent_score)))
  );

-- ---------------------------------------------------------------------
-- 3. MAC KADROSU + GOL / ASIST
-- ---------------------------------------------------------------------
create table if not exists public.match_lineups (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid        not null references public.matches (id) on delete cascade,
  team_id     uuid        not null references public.teams (id) on delete cascade,
  player_id   uuid        references public.team_players (id) on delete set null,
  -- Isim kopyasi: oyuncunun adi sonradan degisse de mac kaydi ayni kalir.
  first_name  text        not null,
  last_name   text        not null,
  slot        smallint    not null,
  goals       smallint    not null default 0,
  assists     smallint    not null default 0,
  created_at  timestamptz not null default now(),

  constraint match_lineups_stats_chk   check (goals between 0 and 50 and assists between 0 and 50),
  constraint match_lineups_player_uniq unique (match_id, player_id),
  constraint match_lineups_slot_uniq   unique (match_id, team_id, slot)
);

create index if not exists idx_match_lineups_match  on public.match_lineups (match_id);
create index if not exists idx_match_lineups_player on public.match_lineups (player_id);

-- ---------------------------------------------------------------------
-- 4. KURALLAR (trigger)
-- ---------------------------------------------------------------------
-- Kadroda en az 7 oyuncu: teklif gondermek ve kabul etmek icin sart.
create or replace function public.enforce_roster_minimum()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if tg_op = 'INSERT' then
    if public.team_roster_size(new.challenger_team_id) < 7 then
      raise exception 'Mac teklifi icin takim kadrosunda en az 7 oyuncu olmali'
        using errcode = 'check_violation';
    end if;
  elsif old.status = 'pending' and new.status = 'accepted' then
    if public.team_roster_size(new.opponent_team_id) < 7 then
      raise exception 'Teklifi kabul etmek icin takim kadrosunda en az 7 oyuncu olmali'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_matches_roster_insert on public.matches;
create trigger trg_matches_roster_insert
  before insert on public.matches
  for each row execute function public.enforce_roster_minimum();

drop trigger if exists trg_matches_roster_accept on public.matches;
create trigger trg_matches_roster_accept
  before update on public.matches
  for each row execute function public.enforce_roster_minimum();

-- Kisi sayisi ve skor yalnizca RPC'lerle yazilir (dogrudan UPDATE engelli).
create or replace function public.protect_match_detail_fields()
returns trigger
language plpgsql
as $fn$
begin
  if auth.uid() is not null
     and coalesce(current_setting('app.match_detail_rpc', true), 'off') <> 'on'
     and (   new.team_size        is distinct from old.team_size
          or new.challenger_score is distinct from old.challenger_score
          or new.opponent_score   is distinct from old.opponent_score) then
    raise exception 'Mac kisi sayisi ve skoru yalnizca uygulama uzerinden girilebilir'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_protect_match_detail on public.matches;
create trigger trg_protect_match_detail
  before update on public.matches
  for each row execute function public.protect_match_detail_fields();

-- ---------------------------------------------------------------------
-- 5. KADRO RPC'LERI
-- ---------------------------------------------------------------------
-- Ic yardimci: listeyi kadroya uygular. Listede olmayan oyuncular pasiflesir.
-- p_players: [{ "id": uuid|null, "first_name": "...", "last_name": "..." }]
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
    if v_first = '' or v_last = '' then
      raise exception 'Her oyuncunun adi ve soyadi girilmeli' using errcode = 'check_violation';
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

-- Takimi kadrosuyla birlikte tek islemde kurar.
create or replace function public.create_team_with_roster(
  p_pitch_id uuid,
  p_name     text,
  p_players  jsonb
)
returns public.teams
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_team public.teams;
begin
  if v_uid is null then
    raise exception 'Takim kurmak icin oturum gerekli';
  end if;
  if char_length(btrim(coalesce(p_name, ''))) < 3 then
    raise exception 'Takim adi en az 3 karakter olmali';
  end if;

  -- contact_phone trigger ile profildeki numaradan doldurulur.
  insert into public.teams (pitch_id, captain_id, name, contact_phone)
  values (p_pitch_id, v_uid, btrim(p_name), '')
  returning * into v_team;

  perform public._apply_team_roster(v_team.id, p_players);
  return v_team;
end;
$fn$;

-- Kadroyu gunceller (yalnizca kaptan).
create or replace function public.save_team_roster(p_team_id uuid, p_players jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_team_captain(p_team_id) then
    raise exception 'Bu takimin kadrosunu yalnizca kaptan duzenleyebilir'
      using errcode = 'insufficient_privilege';
  end if;
  perform public._apply_team_roster(p_team_id, p_players);
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6. MAC KILITLEME: gun/saat + kac kisilik
-- ---------------------------------------------------------------------
drop function if exists public.schedule_match(uuid, timestamptz);
create or replace function public.schedule_match(
  p_match_id   uuid,
  p_match_date timestamptz,
  p_team_size  smallint default null
)
returns public.matches
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_match    public.matches;
  v_old_size smallint;
begin
  if p_match_date <= now() then
    raise exception 'Mac tarihi gelecekte olmalidir';
  end if;
  if p_team_size is not null and p_team_size not between 5 and 11 then
    raise exception 'Mac 5 ile 11 kisilik arasinda olmali' using errcode = 'check_violation';
  end if;

  select * into v_match from public.matches where id = p_match_id for update;
  if v_match.id is null or v_match.status not in ('mutually_agreed','scheduled') then
    raise exception 'Mutabakati tamamlanmis bir mac bulunamadi';
  end if;
  if not public.is_team_captain(v_match.challenger_team_id) then
    raise exception 'Mac gun/saatini yalnizca meydan okuyan takim girebilir'
      using errcode = 'insufficient_privilege';
  end if;
  v_old_size := v_match.team_size;

  perform set_config('app.match_detail_rpc', 'on', true);
  update public.matches
     set match_date = p_match_date,
         team_size  = coalesce(p_team_size, team_size)
   where id = p_match_id
  returning * into v_match;
  perform set_config('app.match_detail_rpc', 'off', true);

  -- Kisi sayisi degistiyse secilmis kadrolar gecersiz kalir.
  if v_old_size is distinct from v_match.team_size then
    delete from public.match_lineups where match_id = p_match_id;
  end if;

  return v_match;
end;
$fn$;

-- Kaptan, kendi takiminin maca cikacak oyuncularini secer (tam team_size kadar).
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

  if v_match.status <> 'scheduled' or v_match.team_size is null then
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

  delete from public.match_lineups where match_id = p_match_id and team_id = v_team;
  insert into public.match_lineups (match_id, team_id, player_id, first_name, last_name, slot)
  select p_match_id, v_team, tp.id, tp.first_name, tp.last_name, u.ord::smallint
    from unnest(p_player_ids) with ordinality as u(pid, ord)
    join public.team_players tp on tp.id = u.pid;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 7. SKOR + GOL / ASIST
-- ---------------------------------------------------------------------
-- Ic yardimci. p_stats: [{ "player_id": uuid, "goals": int, "assists": int }]
-- Listede olmayan oyuncularin degerleri sifirlanir.
create or replace function public._apply_player_stats(
  p_match_id   uuid,
  p_team_id    uuid,
  p_team_score int,
  p_stats      jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_goals   int;
  v_assists int;
begin
  if p_stats is null or jsonb_typeof(p_stats) <> 'array' then
    return;
  end if;

  select coalesce(sum(greatest(coalesce((e ->> 'goals')::int, 0), 0)), 0),
         coalesce(sum(greatest(coalesce((e ->> 'assists')::int, 0), 0)), 0)
    into v_goals, v_assists
    from jsonb_array_elements(p_stats) e;

  -- Kendi kalesine gol olabilir; bu yuzden "esit" degil "en fazla".
  if p_team_score is not null and v_goals > p_team_score then
    raise exception 'Oyuncularin gol toplami (%) takimin skorunu (%) gecemez', v_goals, p_team_score
      using errcode = 'check_violation';
  end if;
  if p_team_score is not null and v_assists > p_team_score then
    raise exception 'Asist toplami (%) takimin skorunu (%) gecemez', v_assists, p_team_score
      using errcode = 'check_violation';
  end if;

  update public.match_lineups
     set goals = 0, assists = 0
   where match_id = p_match_id and team_id = p_team_id;

  update public.match_lineups l
     set goals   = least(greatest(coalesce((e ->> 'goals')::int, 0), 0), 50),
         assists = least(greatest(coalesce((e ->> 'assists')::int, 0), 0), 50)
    from jsonb_array_elements(p_stats) e
   where l.match_id = p_match_id
     and l.team_id  = p_team_id
     and l.player_id = nullif(e ->> 'player_id', '')::uuid;
end;
$fn$;

-- Teklifi gonderen kaptan skoru (ve kendi oyuncularinin gol/asistini) girer.
-- Sonuc skordan turetilir; G/B/M mevcut trigger ile guncellenir.
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
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match.id is null or v_match.status <> 'scheduled' or v_match.result is not null then
    raise exception 'Sonuc girilebilecek bir mac bulunamadi';
  end if;
  if not public.is_team_captain(v_match.challenger_team_id) then
    raise exception 'Mac skorunu yalnizca teklifi gonderen takim girebilir'
      using errcode = 'insufficient_privilege';
  end if;
  if v_match.match_date is null or v_match.match_date > now() then
    raise exception 'Mac baslamadan skor girilemez';
  end if;
  if p_my_score not between 0 and 99 or p_opponent_score not between 0 and 99 then
    raise exception 'Skor 0 ile 99 arasinda olmali' using errcode = 'check_violation';
  end if;

  v_result := case
                when p_my_score > p_opponent_score then 'challenger_won'
                when p_my_score = p_opponent_score then 'draw'
                else 'challenger_lost'
              end::public.match_result;

  perform set_config('app.match_detail_rpc', 'on', true);
  update public.matches
     set challenger_score = p_my_score,
         opponent_score   = p_opponent_score,
         result           = v_result
   where id = p_match_id
  returning * into v_match;
  perform set_config('app.match_detail_rpc', 'off', true);

  perform public._apply_player_stats(p_match_id, v_match.challenger_team_id, p_my_score, p_stats);
  return v_match;
end;
$fn$;

-- Iki kaptan da kendi oyuncularinin gol/asistini mac bittikten sonraki
-- 7 gun icinde girebilir veya duzeltebilir.
create or replace function public.save_match_player_stats(p_match_id uuid, p_stats jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
  v_team  uuid;
  v_score int;
begin
  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Mac bulunamadi';
  end if;

  if public.is_team_captain(v_match.challenger_team_id) then
    v_team  := v_match.challenger_team_id;
    v_score := v_match.challenger_score;
  elsif public.is_team_captain(v_match.opponent_team_id) then
    v_team  := v_match.opponent_team_id;
    v_score := v_match.opponent_score;
  else
    raise exception 'Gol ve asistleri yalnizca takim kaptanlari girebilir'
      using errcode = 'insufficient_privilege';
  end if;

  if v_match.status <> 'completed'
     or v_match.result_reported_at < now() - interval '7 days' then
    raise exception 'Gol ve asistler mac bittikten sonraki 7 gun icinde girilebilir';
  end if;

  perform public._apply_player_stats(p_match_id, v_team, v_score, p_stats);
end;
$fn$;

-- ---------------------------------------------------------------------
-- 8. OKUMA: mac gecmisi (skorlu), oyuncu istatistikleri, saha kralliklari
-- ---------------------------------------------------------------------
drop function if exists public.get_team_match_history(uuid, int);
create or replace function public.get_team_match_history(p_team_id uuid, p_limit int default 50)
returns table (
  match_id       uuid,
  played_at      timestamptz,
  opponent_id    uuid,
  opponent_name  text,
  pitch_name     text,
  outcome        text,       -- 'win' | 'draw' | 'loss' (p_team_id perspektifi)
  team_score     smallint,   -- eski maclarda null (yalnizca G/B/M girilmisti)
  opponent_score smallint,
  team_size      smallint,
  reported_at    timestamptz
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $fn$
  select m.id,
         coalesce(m.match_date, m.result_reported_at),
         opp.id,
         opp.name,
         p.name,
         case
           when m.result = 'draw' then 'draw'
           when (m.challenger_team_id = p_team_id and m.result = 'challenger_won')
             or (m.opponent_team_id  = p_team_id and m.result = 'challenger_lost') then 'win'
           else 'loss'
         end,
         case when m.challenger_team_id = p_team_id then m.challenger_score else m.opponent_score end,
         case when m.challenger_team_id = p_team_id then m.opponent_score else m.challenger_score end,
         m.team_size,
         m.result_reported_at
  from public.matches m
  join public.teams opp
    on opp.id = case when m.challenger_team_id = p_team_id
                     then m.opponent_team_id else m.challenger_team_id end
  join public.pitches p on p.id = m.pitch_id
  where m.status = 'completed'
    and p_team_id in (m.challenger_team_id, m.opponent_team_id)
  order by coalesce(m.match_date, m.result_reported_at) desc
  limit greatest(p_limit, 1);
$fn$;

-- Takim profilindeki kadro: oyuncu basina mac / gol / asist.
create or replace view public.team_player_stats
with (security_invoker = true) as
  select tp.id         as player_id,
         tp.team_id,
         tp.first_name,
         tp.last_name,
         tp.is_active,
         count(l.id) filter (where m.status = 'completed')::int                 as appearances,
         coalesce(sum(l.goals)   filter (where m.status = 'completed'), 0)::int as goals,
         coalesce(sum(l.assists) filter (where m.status = 'completed'), 0)::int as assists
  from public.team_players tp
  left join public.match_lineups l on l.player_id = tp.id
  left join public.matches m       on m.id = l.match_id
  group by tp.id;

-- Saha bazli gol / asist kralligi. Engellenen ve banlanan kullanicilarin
-- takimlari listede gorunmez.
create or replace view public.pitch_player_stats
with (security_invoker = true) as
  select s.player_id,
         s.first_name,
         s.last_name,
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

-- ---------------------------------------------------------------------
-- 9. RLS + YETKILER
-- ---------------------------------------------------------------------
alter table public.team_players  enable row level security;
alter table public.match_lineups enable row level security;

drop policy if exists "team_players_select_authenticated" on public.team_players;
create policy "team_players_select_authenticated"
  on public.team_players for select
  to authenticated
  using (true);

drop policy if exists "match_lineups_select_authenticated" on public.match_lineups;
create policy "match_lineups_select_authenticated"
  on public.match_lineups for select
  to authenticated
  using (true);

-- Yazma yalnizca RPC'lerle; istemciye yalnizca okuma.
revoke all on public.team_players, public.match_lineups,
              public.team_player_stats, public.pitch_player_stats
  from anon, authenticated;
grant select on public.team_players, public.match_lineups,
                public.team_player_stats, public.pitch_player_stats
  to authenticated;

revoke all on function public._apply_team_roster(uuid, jsonb)                  from public, anon, authenticated;
revoke all on function public._apply_player_stats(uuid, uuid, int, jsonb)      from public, anon, authenticated;
revoke all on function public.create_team_with_roster(uuid, text, jsonb)       from public, anon;
revoke all on function public.save_team_roster(uuid, jsonb)                    from public, anon;
revoke all on function public.schedule_match(uuid, timestamptz, smallint)      from public, anon;
revoke all on function public.set_match_lineup(uuid, uuid[])                   from public, anon;
revoke all on function public.report_match_score(uuid, int, int, jsonb)        from public, anon;
revoke all on function public.save_match_player_stats(uuid, jsonb)             from public, anon;

grant execute on function public.create_team_with_roster(uuid, text, jsonb)    to authenticated;
grant execute on function public.save_team_roster(uuid, jsonb)                 to authenticated;
grant execute on function public.schedule_match(uuid, timestamptz, smallint)   to authenticated;
grant execute on function public.set_match_lineup(uuid, uuid[])                to authenticated;
grant execute on function public.report_match_score(uuid, int, int, jsonb)     to authenticated;
grant execute on function public.save_match_player_stats(uuid, jsonb)          to authenticated;
grant execute on function public.get_team_match_history(uuid, int)             to authenticated;
grant execute on function public.team_roster_size(uuid)                        to authenticated;

-- PostgREST sema onbellegini yenile (yeni tablo/fonksiyonlar hemen gorunsun).
notify pgrst, 'reload schema';
