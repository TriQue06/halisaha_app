-- =====================================================================
-- RAPORLAMA, ENGELLEME VE BANLAMA
-- (App Store Guideline 1.2 - User Generated Content)
--
-- Apple, kullanici icerigi barindiran uygulamalardan sunlari istiyor:
--   * uygunsuz icerik/kullanici raporlama mekanizmasi,
--   * kotu niyetli kullanicilari engelleme,
--   * raporlara 24 saat icinde aksiyon (icerik kaldirma, kullanici atma).
--
-- Bu dosya:
--   1. profiles.is_banned  : panelden acilan ban bayragi (kullanici degistiremez)
--   2. blocked_users       : kim kimi engelledi
--   3. reports             : sikayetler
--   4. is_hidden_from_me() : engellenen/banlanan kisinin icerigini gizleyen kural
--   5. goalkeeper_profiles ve teams_with_stats view'larina bu kural
--   6. block_user() RPC    : engelle + aradaki aktif maclari iptal et
--   7. challenge_team      : engelli/banli kisiye mac teklifi yok
--   8. reports_inbox       : panelden takip icin okunakli rapor listesi
--
-- NOT: Supabase public semadaki yeni tablo ve view'lara anon/authenticated
-- icin varsayilan olarak TUM yetkileri veriyor. Asagida her nesnede once
-- "revoke all" yapilip sadece gereken yetkiler bilerek veriliyor.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. BAN BAYRAGI
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_banned boolean not null default false;

-- Kullanici kendi profilini guncelleyebiliyor (profiles_update_self);
-- is_banned'i API uzerinden degistiremesin. Panel / SQL Editor'den
-- yapilan degisikliklerde auth.uid() bos oldugu icin onlar etkilenmez.
create or replace function public.protect_profile_ban()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $fn$
begin
  if auth.uid() is not null then
    if tg_op = 'INSERT' then
      new.is_banned := false;
    elsif new.is_banned is distinct from old.is_banned then
      new.is_banned := old.is_banned;
    end if;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_profiles_protect_ban on public.profiles;
create trigger trg_profiles_protect_ban
  before insert or update on public.profiles
  for each row execute function public.protect_profile_ban();


-- ---------------------------------------------------------------------
-- 2. ENGELLEME
-- ---------------------------------------------------------------------
create table if not exists public.blocked_users (
  id          uuid        primary key default gen_random_uuid(),
  blocker_id  uuid        not null references public.profiles (id) on delete cascade,
  blocked_id  uuid        not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint blocked_users_unique   unique (blocker_id, blocked_id),
  constraint blocked_users_not_self check (blocker_id <> blocked_id)
);

create index if not exists idx_blocked_users_blocked on public.blocked_users (blocked_id);

alter table public.blocked_users enable row level security;

-- Kullanici yalnizca KENDI engellemelerini gorur ve kaldirir.
-- Ekleme block_user() RPC'si uzerinden (aktif maclari da iptal ediyor).
drop policy if exists "blocked_users_select_own" on public.blocked_users;
create policy "blocked_users_select_own"
  on public.blocked_users for select
  to authenticated
  using (blocker_id = auth.uid());

drop policy if exists "blocked_users_delete_own" on public.blocked_users;
create policy "blocked_users_delete_own"
  on public.blocked_users for delete
  to authenticated
  using (blocker_id = auth.uid());

revoke all on public.blocked_users from anon, authenticated;
grant select, delete on public.blocked_users to authenticated;


-- ---------------------------------------------------------------------
-- 3. RAPORLAR
-- ---------------------------------------------------------------------
create table if not exists public.reports (
  id                 uuid        primary key default gen_random_uuid(),
  reporter_id        uuid        not null default auth.uid()
                                 references public.profiles (id) on delete cascade,
  reported_user_id   uuid        not null references public.profiles (id) on delete cascade,
  reported_match_id  uuid        references public.matches (id) on delete set null,
  -- Raporun uygulamanin neresinden geldigi
  context            text        not null
                       check (context in ('goalkeeper', 'team', 'match')),
  reason             text        not null
                       check (reason in ('fake_info', 'no_show', 'abusive',
                                         'inappropriate', 'spam', 'other')),
  description        text        check (description is null or char_length(description) <= 1000),
  status             text        not null default 'pending'
                       check (status in ('pending', 'investigating', 'resolved', 'dismissed')),
  admin_note         text,
  created_at         timestamptz not null default now(),
  resolved_at        timestamptz,
  constraint reports_not_self check (reporter_id <> reported_user_id)
);

create index if not exists idx_reports_status on public.reports (status, created_at desc);
create index if not exists idx_reports_reported on public.reports (reported_user_id);

-- Ayni kisiyi, onceki raporu incelenmeden tekrar tekrar raporlamak yok.
create unique index if not exists reports_one_pending_per_pair
  on public.reports (reporter_id, reported_user_id)
  where status = 'pending';

alter table public.reports enable row level security;

drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own"
  on public.reports for insert
  to authenticated
  with check (reporter_id = auth.uid() and status = 'pending');

drop policy if exists "reports_select_own" on public.reports;
create policy "reports_select_own"
  on public.reports for select
  to authenticated
  using (reporter_id = auth.uid());

-- Kolon bazli yetki: kullanici status / admin_note / resolved_at
-- alanlarini dolduramaz; reporter_id varsayilan olarak auth.uid().
revoke all on public.reports from anon, authenticated;
grant select on public.reports to authenticated;
grant insert (reported_user_id, reported_match_id, context, reason, description)
  on public.reports to authenticated;


-- ---------------------------------------------------------------------
-- 4. GIZLEME KURALI
--    Engelleme iki yonlu: A, B'yi engellerse ikisi de birbirinin
--    kaleci profilini ve takimlarini gormez. Banli kisi herkesten gizli.
--    security definer: karsi tarafin engellemesini (RLS geregi kendi
--    satiri olmayan) okuyabilmek icin.
-- ---------------------------------------------------------------------
create or replace function public.is_hidden_from_me(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select p_user is not null
     and p_user is distinct from auth.uid()
     and (
       exists (select 1 from public.profiles p where p.id = p_user and p.is_banned)
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = auth.uid() and b.blocked_id = p_user)
            or (b.blocker_id = p_user   and b.blocked_id = auth.uid())
       )
     );
$fn$;

grant execute on function public.is_hidden_from_me(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 5. LISTE VIEW'LARI: gizlenen kullanicilarin icerigi dusmez
--    (kolonlar ayni, yalnizca WHERE eklendi)
-- ---------------------------------------------------------------------
create or replace view public.teams_with_stats
with (security_invoker = true) as
  select t.*,
         (t.wins + t.draws + t.losses) as played,
         (t.wins * 3 + t.draws)        as points,
         case when (t.wins + t.draws + t.losses) = 0 then 0
              else round(t.wins::numeric * 100 / (t.wins + t.draws + t.losses), 1)
         end                           as win_rate
  from public.teams t
  where not public.is_hidden_from_me(t.captain_id);

create or replace view public.goalkeeper_profiles
with (security_invoker = true) as
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


-- ---------------------------------------------------------------------
-- 6. ENGELLE
-- ---------------------------------------------------------------------
create or replace function public.block_user(p_user_id uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_uid       uuid := auth.uid();
  v_cancelled int  := 0;
begin
  if v_uid is null then
    raise exception 'Oturum gerekli' using errcode = 'insufficient_privilege';
  end if;
  if p_user_id is null or p_user_id = v_uid then
    raise exception 'Kendini engelleyemezsin' using errcode = 'check_violation';
  end if;

  insert into public.blocked_users (blocker_id, blocked_id)
  values (v_uid, p_user_id)
  on conflict (blocker_id, blocked_id) do nothing;

  -- Aradaki devam eden maclar iptal: engellenen kisiyle bulusma
  -- planlanmis olarak kalmasin.
  update public.matches m
     set status = 'cancelled',
         cancelled_by = v_uid,
         cancel_reason = 'Kullanici engellendi'
   where m.status in ('pending', 'accepted', 'mutually_agreed', 'scheduled')
     and (
       (public.team_captain_id(m.challenger_team_id) = v_uid
        and public.team_captain_id(m.opponent_team_id) = p_user_id)
       or
       (public.team_captain_id(m.challenger_team_id) = p_user_id
        and public.team_captain_id(m.opponent_team_id) = v_uid)
     );
  get diagnostics v_cancelled = row_count;

  return v_cancelled;
end;
$fn$;

revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 7. MAC TEKLIFI: engelli/banli kisiye ve banli kisiden teklif yok
--    (20260831000000_challenge_duplicate_guard.sql surumu + 2 kontrol)
-- ---------------------------------------------------------------------
create or replace function public.challenge_team(
  p_challenger_team_id uuid,
  p_opponent_team_id   uuid,
  p_message            text default null
)
returns public.matches
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
begin
  if not public.is_team_captain(p_challenger_team_id) then
    raise exception 'Yalnizca kendi takiminiz adina mac teklifi gonderebilirsiniz'
      using errcode = 'insufficient_privilege';
  end if;

  if p_challenger_team_id = p_opponent_team_id then
    raise exception 'Bir takim kendisine mac teklifi gonderemez'
      using errcode = 'check_violation';
  end if;

  if exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_banned) then
    raise exception 'Hesabin askiya alindigi icin mac teklifi gonderemezsin'
      using errcode = 'insufficient_privilege';
  end if;

  if public.is_hidden_from_me(public.team_captain_id(p_opponent_team_id)) then
    raise exception 'Bu takima mac teklifi gonderilemiyor'
      using errcode = 'insufficient_privilege';
  end if;

  -- Aktif bir mac zaten varsa yonu ne olursa olsun engelle
  if exists (
    select 1 from public.matches m
    where m.status in ('pending','accepted','mutually_agreed','scheduled')
      and least(m.challenger_team_id, m.opponent_team_id)
          = least(p_challenger_team_id, p_opponent_team_id)
      and greatest(m.challenger_team_id, m.opponent_team_id)
          = greatest(p_challenger_team_id, p_opponent_team_id)
  ) then
    raise exception 'Bu takimla aramizda zaten devam eden bir mac var. Once onu sonuclandir ya da iptal et.'
      using errcode = 'unique_violation';
  end if;

  insert into public.matches (pitch_id, challenger_team_id, opponent_team_id, challenge_message)
  select t.pitch_id, p_challenger_team_id, p_opponent_team_id, p_message
  from public.teams t where t.id = p_opponent_team_id
  returning * into v_match;

  return v_match;
end;
$fn$;


-- ---------------------------------------------------------------------
-- 8. PANEL ICIN RAPOR KUTUSU
--    Supabase Dashboard -> Table Editor -> reports_inbox
--    Bekleyen raporlar en ustte. Uygulamadan ERISILEMEZ (yetki yok).
-- ---------------------------------------------------------------------
create or replace view public.reports_inbox as
  select r.id,
         r.created_at,
         r.status,
         r.reason,
         r.context,
         r.description,
         trim(ru.first_name || ' ' || ru.last_name) as reported_name,
         r.reported_user_id,
         ru.is_banned                                as reported_is_banned,
         (select count(*) from public.reports r2
           where r2.reported_user_id = r.reported_user_id) as reports_against_user,
         trim(rp.first_name || ' ' || rp.last_name) as reporter_name,
         r.reporter_id,
         r.reported_match_id,
         r.admin_note,
         r.resolved_at
  from public.reports r
  join public.profiles rp on rp.id = r.reporter_id
  join public.profiles ru on ru.id = r.reported_user_id
  order by (r.status = 'pending') desc, r.created_at desc;

revoke all on public.reports_inbox from anon, authenticated;
