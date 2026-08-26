-- =====================================================================
-- HALISAHA APP - IZMIR  |  Supabase / PostgreSQL Şema Kurulumu
-- ---------------------------------------------------------------------
-- Bölüm 1 : Eklentiler ve Enum tipleri
-- Bölüm 2 : Tablolar
-- Bölüm 3 : Index'ler
-- Bölüm 4 : Yardımcı fonksiyonlar (RLS için SECURITY DEFINER helper'lar)
-- Bölüm 5 : Trigger fonksiyonları ve trigger'lar
-- Bölüm 6 : RPC / iş fonksiyonları (popüler sahalar, maç akışı)
-- Bölüm 7 : Zamanlanmış işler (pg_cron) - otomatik iptal & sonuç bildirimi
-- Bölüm 8 : RLS politikaları
-- Bölüm 9 : Seed data (İzmir örnek halı sahalar)
-- =====================================================================

-- =====================================================================
-- BÖLÜM 1 - EKLENTİLER VE ENUM TİPLERİ
-- =====================================================================

create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "pg_cron";       -- zamanlanmış görevler (Supabase Dashboard > Database > Extensions)
create extension if not exists "pg_net";        -- cron içinden Edge Function çağırmak istersen

-- Maç yaşam döngüsü
create type public.match_status as enum (
  'pending',          -- A takımı meydan okudu, B cevap bekliyor
  'rejected',         -- B takımı reddetti
  'accepted',         -- B kabul etti -> "Beklenen Maçlar". 7 günlük sayaç burada başlar
  'mutually_agreed',  -- iki taraf da uygulama içinden "Maç Kabulü" yaptı
  'scheduled',        -- meydan okuyan takım gün/saat girdi
  'completed',        -- sonuç girildi
  'cancelled',        -- taraflardan biri manuel iptal etti
  'auto_cancelled'    -- 7 gün içinde karşılıklı onay gelmedi -> sistem iptal etti
);

-- Sonuç her zaman MEYDAN OKUYAN (challenger) takım perspektifinden tutulur.
create type public.match_result as enum (
  'challenger_won',   -- "Kazandık"
  'draw',             -- "Beraberlik"
  'challenger_lost'   -- "Kaybettik"
);

create type public.notification_type as enum (
  'challenge_received',   -- sana meydan okundu
  'challenge_accepted',
  'challenge_rejected',
  'match_mutually_agreed',
  'match_scheduled',
  'match_result_request', -- maç saatinden 1 saat sonra "Maç nasıl sonlandı?"
  'match_completed',
  'match_auto_cancelled',
  'match_cancelled',
  'goalkeeper_rated',
  'generic'
);


-- =====================================================================
-- BÖLÜM 2 - TABLOLAR
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2.1 PROFILES  (auth.users ile 1-1)
-- ---------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  first_name    text        not null default '',
  last_name     text        not null default '',
  birth_date    date,
  phone         text,
  avatar_url    text,
  district      text,                            -- kullanicinin ikamet ilcesi (opsiyonel)
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint profiles_phone_format_chk
    check (phone is null or phone ~ '^\+?[0-9]{10,15}$'),
  constraint profiles_birth_date_chk
    check (birth_date is null or birth_date > '1930-01-01'::date)
);

comment on table public.profiles is 'auth.users tablosunun uygulama tarafindaki uzantisi. Trigger ile otomatik olusur.';

-- Yas, dogum tarihinden turetilir. current_date IMMUTABLE olmadigi icin
-- generated column yerine fonksiyon + view kullaniyoruz (kolon bayatlamaz).
create or replace function public.calculate_age(p_birth_date date)
returns int
language sql
stable
as $fn$
  select case
    when p_birth_date is null then null
    else extract(year from age(current_date, p_birth_date))::int
  end;
$fn$;

create or replace view public.profiles_with_age
with (security_invoker = true) as
  select p.*, public.calculate_age(p.birth_date) as age
  from public.profiles p;

-- ---------------------------------------------------------------------
-- 2.2 PITCHES (Hali sahalar)
-- ---------------------------------------------------------------------
create table public.pitches (
  id             uuid primary key default gen_random_uuid(),
  name           text        not null,
  district       text        not null,           -- Izmir ilcesi: Bornova, Karsiyaka, Buca...
  address        text,
  latitude       double precision,
  longitude      double precision,
  phone          text,
  description    text,
  image_url      text,
  price_per_hour numeric(10,2),
  has_parking    boolean     not null default false,
  has_shower     boolean     not null default false,
  is_indoor      boolean     not null default false,
  is_active      boolean     not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint pitches_name_district_uniq unique (name, district)
);

comment on table public.pitches is 'Uygulamada listelenen hali sahalar. Varsayilan kayitlar seed ile gelir.';

-- ---------------------------------------------------------------------
-- 2.3 TEAMS (Takimlar) - her takim BIR hali sahaya baglidir
-- ---------------------------------------------------------------------
create table public.teams (
  id             uuid primary key default gen_random_uuid(),
  pitch_id       uuid        not null references public.pitches (id) on delete cascade,
  captain_id     uuid        not null references public.profiles (id) on delete cascade,
  name           text        not null,
  logo_url       text,
  contact_phone  text        not null,           -- takim iletisim numarasi
  description    text,
  wins           integer     not null default 0, -- G (Galibiyet)
  draws          integer     not null default 0, -- B (Beraberlik)
  losses         integer     not null default 0, -- M (Maglubiyet)
  is_active      boolean     not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint teams_stats_non_negative_chk check (wins >= 0 and draws >= 0 and losses >= 0),
  constraint teams_name_pitch_uniq        unique (pitch_id, name),
  constraint teams_contact_phone_chk      check (contact_phone ~ '^\+?[0-9]{10,15}$')
);

comment on column public.teams.wins   is 'Galibiyet (G) - mac sonucu trigger ile guncellenir, elle yazilmaz.';
comment on column public.teams.draws  is 'Beraberlik (B) - trigger ile guncellenir.';
comment on column public.teams.losses is 'Maglubiyet (M) - trigger ile guncellenir.';

-- Oynanan mac / puan gibi turetilmis alanlar icin view
create or replace view public.teams_with_stats
with (security_invoker = true) as
  select t.*,
         (t.wins + t.draws + t.losses) as played,
         (t.wins * 3 + t.draws)        as points,
         case when (t.wins + t.draws + t.losses) = 0 then 0
              else round(t.wins::numeric * 100 / (t.wins + t.draws + t.losses), 1)
         end                           as win_rate
  from public.teams t;

-- ---------------------------------------------------------------------
-- 2.4 GOALKEEPERS (Kaleci profili) - profiles ile 1-1, opsiyonel
-- ---------------------------------------------------------------------
create table public.goalkeepers (
  id             uuid primary key references public.profiles (id) on delete cascade,
  districts      text[]       not null default '{}',  -- oynayabilecegi Izmir ilceleri
  about          text,
  contact_phone  text         not null,
  is_available   boolean      not null default true,
  -- Asagidaki iki alan goalkeeper_ratings trigger'i ile otomatik guncellenir
  rating_avg     numeric(3,2) not null default 0,
  rating_count   integer      not null default 0,
  created_at     timestamptz  not null default now(),
  updated_at     timestamptz  not null default now(),

  constraint goalkeepers_districts_chk     check (array_length(districts, 1) is null or array_length(districts, 1) <= 30),
  constraint goalkeepers_contact_phone_chk check (contact_phone ~ '^\+?[0-9]{10,15}$'),
  constraint goalkeepers_rating_avg_chk    check (rating_avg between 0 and 5),
  constraint goalkeepers_rating_count_chk  check (rating_count >= 0)
);

comment on table public.goalkeepers is 'Kaleci profili. Isim ve yas bilgisi profiles tablosundan gelir (goalkeeper_profiles view).';

-- Kaleci listesi ekrani icin hazir view (isim + yas + ortalama puan)
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
  join public.profiles p on p.id = g.id;

-- ---------------------------------------------------------------------
-- 2.5 GOALKEEPER_RATINGS (Kaleci puanlama 1-5)
-- ---------------------------------------------------------------------
create table public.goalkeeper_ratings (
  id             uuid primary key default gen_random_uuid(),
  goalkeeper_id  uuid        not null references public.goalkeepers (id) on delete cascade,
  rater_id       uuid        not null references public.profiles (id) on delete cascade,
  rating         smallint    not null,
  comment        text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint goalkeeper_ratings_range_chk check (rating between 1 and 5),
  constraint goalkeeper_ratings_self_chk  check (goalkeeper_id <> rater_id),
  -- Bir kullanici bir kaleciye yalnizca bir kez puan verir (guncelleyebilir)
  constraint goalkeeper_ratings_uniq      unique (goalkeeper_id, rater_id)
);

-- ---------------------------------------------------------------------
-- 2.6 MATCHES (Meydan okuma + mac)
-- ---------------------------------------------------------------------
create table public.matches (
  id                      uuid primary key default gen_random_uuid(),
  pitch_id                uuid not null references public.pitches (id) on delete restrict,
  challenger_team_id      uuid not null references public.teams (id) on delete cascade,  -- meydan okuyan (A)
  opponent_team_id        uuid not null references public.teams (id) on delete cascade,  -- meydan okunan (B)
  status                  public.match_status not null default 'pending',

  challenge_message       text,
  responded_at            timestamptz,   -- B'nin kabul/red anı
  -- 'accepted' olduktan sonra iki tarafin uygulama ici "Mac Kabulu" onaylari
  challenger_confirmed_at timestamptz,
  opponent_confirmed_at   timestamptz,
  agreed_at               timestamptz,   -- iki onay tamamlandigi an
  cancel_deadline         timestamptz,   -- kabul + 7 gun; bu tarihe kadar mutabakat yoksa auto_cancelled

  match_date              timestamptz,   -- A takiminin girdigi mac gun/saati
  result                  public.match_result,
  result_reported_by      uuid references public.profiles (id) on delete set null,
  result_reported_at      timestamptz,
  result_prompt_sent_at   timestamptz,   -- "Mac nasil sonlandi?" bildirimi gonderildi mi (cron idempotency)
  cancelled_by            uuid references public.profiles (id) on delete set null,
  cancel_reason           text,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  constraint matches_different_teams_chk check (challenger_team_id <> opponent_team_id),
  -- Sonuc yalnizca completed statusunde olabilir; completed sonucsuz olamaz
  constraint matches_result_status_chk
    check ((status = 'completed' and result is not null)
        or (status <> 'completed' and result is null)),
  -- Mac tarihi ancak mutabakat sonrasi girilebilir
  constraint matches_date_status_chk
    check (match_date is null or status in ('mutually_agreed','scheduled','completed','cancelled'))
);

comment on column public.matches.result is
  'Sonuc her zaman MEYDAN OKUYAN (challenger) takim perspektifinden tutulur.';

-- Ayni iki takim arasinda ayni anda yalnizca bir aktif meydan okuma/mac olabilir
create unique index matches_active_pair_uniq
  on public.matches (least(challenger_team_id, opponent_team_id),
                     greatest(challenger_team_id, opponent_team_id))
  where status in ('pending','accepted','mutually_agreed','scheduled');

-- ---------------------------------------------------------------------
-- 2.7 NOTIFICATIONS
-- ---------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid        not null references public.profiles (id) on delete cascade,
  type       public.notification_type not null default 'generic',
  title      text        not null,
  body       text        not null default '',
  is_read    boolean     not null default false,
  match_id   uuid        references public.matches (id) on delete cascade,
  team_id    uuid        references public.teams (id)   on delete cascade,
  data       jsonb       not null default '{}'::jsonb,   -- deep-link vb. ek veri
  created_at timestamptz not null default now(),
  read_at    timestamptz
);


-- =====================================================================
-- BÖLÜM 3 - INDEX'LER
-- =====================================================================

create index idx_pitches_district          on public.pitches (district) where is_active;
create index idx_teams_pitch                on public.teams (pitch_id) where is_active;
create index idx_teams_captain              on public.teams (captain_id);
create index idx_gk_ratings_goalkeeper      on public.goalkeeper_ratings (goalkeeper_id);
create index idx_goalkeepers_districts      on public.goalkeepers using gin (districts);
create index idx_matches_challenger         on public.matches (challenger_team_id, status);
create index idx_matches_opponent           on public.matches (opponent_team_id, status);
create index idx_matches_pitch              on public.matches (pitch_id);
create index idx_matches_status_deadline    on public.matches (status, cancel_deadline);
-- Mac gecmisi: en yeniden eskiye siralama
create index idx_matches_history            on public.matches (result_reported_at desc) where status = 'completed';
-- Cron: sonuc bildirimi bekleyen maclar
create index idx_matches_result_prompt      on public.matches (match_date)
  where status = 'scheduled' and result_prompt_sent_at is null;
create index idx_notifications_user_unread  on public.notifications (user_id, created_at desc) where not is_read;


-- =====================================================================
-- BÖLÜM 4 - YARDIMCI FONKSİYONLAR (RLS icin SECURITY DEFINER helper'lar)
-- ---------------------------------------------------------------------
-- Not: RLS politikasi icinde ayni tabloyu sorgulamak sonsuz dongu (recursion)
-- yaratabilir. Bu yuzden helper'lar SECURITY DEFINER + row_security = off ile
-- yazildi ve search_path sabitlendi (guvenlik icin zorunlu).
-- =====================================================================

-- Kullanici verilen takimin kaptani mi?
create or replace function public.is_team_captain(p_team_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $fn$
  select exists (
    select 1 from public.teams t
    where t.id = p_team_id and t.captain_id = p_user_id
  );
$fn$;

-- Kullanici bu macin taraflarindan birinin kaptani mi?
create or replace function public.is_match_participant(p_match_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $fn$
  select exists (
    select 1
    from public.matches m
    join public.teams t
      on t.id in (m.challenger_team_id, m.opponent_team_id)
    where m.id = p_match_id
      and t.captain_id = p_user_id
  );
$fn$;

-- Bir takimin kaptaninin user id'si
create or replace function public.team_captain_id(p_team_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $fn$
  select captain_id from public.teams where id = p_team_id;
$fn$;

-- Bildirim olusturmak icin ortak yardimci (trigger'lar ve RPC'ler kullanir)
create or replace function public.create_notification(
  p_user_id  uuid,
  p_type     public.notification_type,
  p_title    text,
  p_body     text default '',
  p_match_id uuid default null,
  p_team_id  uuid default null,
  p_data     jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_id uuid;
begin
  if p_user_id is null then
    return null;
  end if;

  insert into public.notifications (user_id, type, title, body, match_id, team_id, data)
  values (p_user_id, p_type, p_title, p_body, p_match_id, p_team_id, p_data)
  returning id into v_id;

  return v_id;
end;
$fn$;


-- =====================================================================
-- BÖLÜM 5 - TRIGGER FONKSİYONLARI VE TRIGGER'LAR
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.0 Ortak: updated_at otomatik guncelleme
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

create trigger trg_profiles_updated_at            before update on public.profiles           for each row execute function public.set_updated_at();
create trigger trg_pitches_updated_at             before update on public.pitches            for each row execute function public.set_updated_at();
create trigger trg_teams_updated_at               before update on public.teams              for each row execute function public.set_updated_at();
create trigger trg_goalkeepers_updated_at         before update on public.goalkeepers        for each row execute function public.set_updated_at();
create trigger trg_goalkeeper_ratings_updated_at  before update on public.goalkeeper_ratings for each row execute function public.set_updated_at();
create trigger trg_matches_updated_at             before update on public.matches            for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 5.1 Yeni auth.users -> otomatik profiles kaydi
-- ---------------------------------------------------------------------
-- Kayit sirasinda Flutter/JS tarafinda:
--   supabase.auth.signUp(email/phone, password, data: {
--     first_name: 'Baris', last_name: 'Tanlik', birth_date: '1995-04-12', phone: '+905321112233'
--   })
-- gonderilen "data" alani raw_user_meta_data icine dusuyor; asagida oradan okuyoruz.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_birth date;
begin
  begin
    v_birth := nullif(v_meta ->> 'birth_date', '')::date;
  exception when others then
    v_birth := null;   -- hatali tarih formati kayit islemini bozmasin
  end;

  insert into public.profiles (id, first_name, last_name, birth_date, phone, avatar_url, district)
  values (
    new.id,
    coalesce(nullif(v_meta ->> 'first_name', ''), ''),
    coalesce(nullif(v_meta ->> 'last_name',  ''), ''),
    v_birth,
    coalesce(nullif(v_meta ->> 'phone', ''), new.phone),
    nullif(v_meta ->> 'avatar_url', ''),
    nullif(v_meta ->> 'district', '')
  )
  on conflict (id) do nothing;   -- idempotent

  return new;
end;
$fn$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Kullanici e-posta/telefonunu degistirirse profildeki telefonu senkron tut
create or replace function public.handle_user_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if new.phone is distinct from old.phone and new.phone is not null then
    update public.profiles set phone = new.phone where id = new.id and phone is null;
  end if;
  return new;
end;
$fn$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update on auth.users
  for each row execute function public.handle_user_update();

-- ---------------------------------------------------------------------
-- 5.2 Kaleci puan ortalamasi (insert / update / delete hepsinde)
-- ---------------------------------------------------------------------
create or replace function public.refresh_goalkeeper_rating()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_gk uuid := coalesce(new.goalkeeper_id, old.goalkeeper_id);
begin
  -- protect_goalkeeper_rating_fields trigger'ini bu islem icin devre disi birak
  perform set_config('app.bypass_guards', 'on', true);

  update public.goalkeepers g
  set rating_avg = coalesce(s.avg_rating, 0),
      rating_count = coalesce(s.cnt, 0),
      updated_at = now()
  from (
    select round(avg(r.rating)::numeric, 2) as avg_rating,
           count(*)                          as cnt
    from public.goalkeeper_ratings r
    where r.goalkeeper_id = v_gk
  ) s
  where g.id = v_gk;

  -- Kaleciye puan verildiginde bildirim (yalnizca yeni puanda)
  if tg_op = 'INSERT' then
    perform public.create_notification(
      v_gk,
      'goalkeeper_rated',
      'Yeni puan aldiniz',
      format('Kaleci profiliniz %s puan aldi.', new.rating),
      null, null,
      jsonb_build_object('rating', new.rating, 'rater_id', new.rater_id)
    );
  end if;

  perform set_config('app.bypass_guards', 'off', true);

  return coalesce(new, old);
end;
$fn$;

create trigger trg_goalkeeper_rating_refresh
  after insert or update of rating or delete on public.goalkeeper_ratings
  for each row execute function public.refresh_goalkeeper_rating();

-- ---------------------------------------------------------------------
-- 5.3 (KRITIK) Mac sonucu -> iki takimin G/B/M istatistiklerini guncelle
-- ---------------------------------------------------------------------
-- Yardimci: bir sonuc icin takim istatistiklerine +1 / -1 uygula
create or replace function public.apply_match_result_to_stats(
  p_challenger_team_id uuid,
  p_opponent_team_id   uuid,
  p_result             public.match_result,
  p_sign               int          -- +1 ekle, -1 geri al
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if p_result is null then
    return;
  end if;

  -- protect_team_stats trigger'ina "bu guncelleme sistem kaynakli" sinyali
  -- (true => yalnizca mevcut transaction icin gecerli)
  perform set_config('app.bypass_guards', 'on', true);

  if p_result = 'challenger_won' then
    -- Meydan okuyan kazandi: A +1 G, B +1 M
    update public.teams set wins   = greatest(wins   + p_sign, 0), updated_at = now() where id = p_challenger_team_id;
    update public.teams set losses = greatest(losses + p_sign, 0), updated_at = now() where id = p_opponent_team_id;

  elsif p_result = 'challenger_lost' then
    -- Meydan okuyan kaybetti: A +1 M, B +1 G
    update public.teams set losses = greatest(losses + p_sign, 0), updated_at = now() where id = p_challenger_team_id;
    update public.teams set wins   = greatest(wins   + p_sign, 0), updated_at = now() where id = p_opponent_team_id;

  else -- 'draw' : iki takima da +1 B
    update public.teams set draws  = greatest(draws  + p_sign, 0), updated_at = now()
      where id in (p_challenger_team_id, p_opponent_team_id);
  end if;

  perform set_config('app.bypass_guards', 'off', true);
end;
$fn$;

-- Sonuc girildiginde / duzeltildiginde / mac silindiginde istatistikleri senkron tut
create or replace function public.handle_match_result_stats()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if tg_op = 'DELETE' then
    -- Tamamlanmis bir mac silinirse istatistigi geri al
    if old.status = 'completed' and old.result is not null then
      perform public.apply_match_result_to_stats(old.challenger_team_id, old.opponent_team_id, old.result, -1);
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    -- Onceki sonucu geri al (sonuc degistiyse veya mac completed'dan cikarildiysa)
    if old.status = 'completed' and old.result is not null
       and (new.result is distinct from old.result or new.status <> 'completed') then
      perform public.apply_match_result_to_stats(old.challenger_team_id, old.opponent_team_id, old.result, -1);
    end if;
  end if;

  -- Yeni sonucu uygula
  if new.status = 'completed' and new.result is not null
     and (tg_op = 'INSERT'
          or old.status <> 'completed'
          or new.result is distinct from old.result) then
    perform public.apply_match_result_to_stats(new.challenger_team_id, new.opponent_team_id, new.result, 1);
  end if;

  return new;
end;
$fn$;

-- Not: "update of status, result" yazmiyoruz; cunku BEFORE trigger'i status'u
-- kendisi degistirebiliyor ve "OF" filtresi UPDATE'in SET listesine bakar.
create trigger trg_match_result_stats
  after insert or update or delete on public.matches
  for each row execute function public.handle_match_result_stats();

-- ---------------------------------------------------------------------
-- 5.4 Mac akisi kurallari (status gecisleri + otomatik alan doldurma)
-- ---------------------------------------------------------------------
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
begin
  v_is_challenger := v_uid is not null and public.is_team_captain(new.challenger_team_id, v_uid);
  v_is_opponent   := v_uid is not null and public.is_team_captain(new.opponent_team_id,  v_uid);

  -- ---- Statu gecis matrisi -------------------------------------------------
  if new.status is distinct from old.status then
    if not (
         (old.status = 'pending'         and new.status in ('accepted','rejected','cancelled'))
      or (old.status = 'accepted'        and new.status in ('mutually_agreed','cancelled','auto_cancelled'))
      or (old.status = 'mutually_agreed' and new.status in ('scheduled','cancelled'))
      or (old.status = 'scheduled'       and new.status in ('completed','cancelled'))
    ) then
      raise exception 'Gecersiz mac statu gecisi: % -> %', old.status, new.status
        using errcode = 'check_violation';
    end if;
  end if;

  -- ---- Yetki kontrolleri (auth.uid() null ise cron/service_role calisiyordur) ----
  if v_uid is not null then
    -- Meydan okumayi yalnizca rakip takim kaptani kabul/red eder
    if old.status = 'pending' and new.status in ('accepted','rejected') and not v_is_opponent then
      raise exception 'Meydan okumayi yalnizca rakip takim kaptani yanitlayabilir'
        using errcode = 'insufficient_privilege';
    end if;

    -- Mac gun/saatini yalnizca meydan okuyan takim girer
    if new.match_date is distinct from old.match_date and not v_is_challenger then
      raise exception 'Mac gun/saatini yalnizca meydan okuyan takim girebilir'
        using errcode = 'insufficient_privilege';
    end if;

    -- Sonucu yalnizca meydan okuyan takim bildirir
    if new.result is distinct from old.result and not v_is_challenger then
      raise exception 'Mac sonucunu yalnizca meydan okuyan takim bildirebilir'
        using errcode = 'insufficient_privilege';
    end if;

    -- Onay damgalarini kimse baskasi adina atamaz
    if new.challenger_confirmed_at is distinct from old.challenger_confirmed_at and not v_is_challenger then
      raise exception 'Baska takim adina mac kabulu verilemez' using errcode = 'insufficient_privilege';
    end if;
    if new.opponent_confirmed_at is distinct from old.opponent_confirmed_at and not v_is_opponent then
      raise exception 'Baska takim adina mac kabulu verilemez' using errcode = 'insufficient_privilege';
    end if;
  end if;

  -- ---- Otomatik alan doldurma ---------------------------------------------
  -- Kabul edildi -> 7 gunluk mutabakat sayaci baslar
  if old.status = 'pending' and new.status in ('accepted','rejected') then
    new.responded_at := coalesce(new.responded_at, now());
    if new.status = 'accepted' then
      new.cancel_deadline := coalesce(new.cancel_deadline, now() + interval '7 days');
    end if;
  end if;

  -- Iki taraf da "Mac Kabulu" verdiyse otomatik mutually_agreed
  if new.status = 'accepted'
     and new.challenger_confirmed_at is not null
     and new.opponent_confirmed_at   is not null then
    new.status   := 'mutually_agreed';
    new.agreed_at := now();
  end if;

  -- Mac tarihi girildi -> scheduled
  if new.status = 'mutually_agreed' and new.match_date is not null then
    new.status := 'scheduled';
  end if;

  -- Sonuc girildi -> completed
  if new.result is not null and old.result is null then
    new.status             := 'completed';
    new.result_reported_at := coalesce(new.result_reported_at, now());
    new.result_reported_by := coalesce(new.result_reported_by, v_uid);
  end if;

  return new;
end;
$fn$;

create trigger trg_match_transition
  before update on public.matches
  for each row execute function public.handle_match_transition();

-- Meydan okuma olusturulurken tutarlilik: her iki takim da ayni sahaya bagli olmali
create or replace function public.handle_match_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_challenger_pitch uuid;
  v_opponent_pitch   uuid;
begin
  select pitch_id into v_challenger_pitch from public.teams where id = new.challenger_team_id;
  select pitch_id into v_opponent_pitch   from public.teams where id = new.opponent_team_id;

  if v_challenger_pitch is null or v_opponent_pitch is null then
    raise exception 'Takim bulunamadi' using errcode = 'foreign_key_violation';
  end if;

  -- Meydan okuma hali saha detay sayfasindan yapilir: saha rakip takimin sahasidir
  new.pitch_id := coalesce(new.pitch_id, v_opponent_pitch);
  new.status   := 'pending';
  new.result   := null;

  return new;
end;
$fn$;

create trigger trg_match_insert
  before insert on public.matches
  for each row execute function public.handle_match_insert();

-- ---------------------------------------------------------------------
-- 5.5 Mac olaylarinda bildirim uretimi
-- ---------------------------------------------------------------------
create or replace function public.notify_match_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_challenger_captain uuid := public.team_captain_id(new.challenger_team_id);
  v_opponent_captain   uuid := public.team_captain_id(new.opponent_team_id);
  v_challenger_name    text;
  v_opponent_name      text;
begin
  select name into v_challenger_name from public.teams where id = new.challenger_team_id;
  select name into v_opponent_name   from public.teams where id = new.opponent_team_id;

  if tg_op = 'INSERT' then
    perform public.create_notification(
      v_opponent_captain, 'challenge_received',
      'Yeni meydan okuma!',
      format('%s takimi size meydan okudu.', v_challenger_name),
      new.id, new.opponent_team_id);
    return new;
  end if;

  if new.status is distinct from old.status then
    case new.status
      when 'accepted' then
        perform public.create_notification(
          v_challenger_captain, 'challenge_accepted',
          'Meydan okuma kabul edildi',
          format('%s takimi meydan okumanizi kabul etti. Iletisime gecip mac kabulu verin.', v_opponent_name),
          new.id, new.challenger_team_id);

      when 'rejected' then
        perform public.create_notification(
          v_challenger_captain, 'challenge_rejected',
          'Meydan okuma reddedildi',
          format('%s takimi meydan okumanizi reddetti.', v_opponent_name),
          new.id, new.challenger_team_id);

      when 'mutually_agreed' then
        perform public.create_notification(
          v_challenger_captain, 'match_mutually_agreed',
          'Mac mutabakati tamam',
          format('%s ile mac mutabakati saglandi. Mac gun ve saatini girin.', v_opponent_name),
          new.id, new.challenger_team_id);
        perform public.create_notification(
          v_opponent_captain, 'match_mutually_agreed',
          'Mac mutabakati tamam',
          format('%s ile mac mutabakati saglandi. Rakip gun/saat girecek.', v_challenger_name),
          new.id, new.opponent_team_id);

      when 'scheduled' then
        perform public.create_notification(
          v_challenger_captain, 'match_scheduled', 'Mac programlandi',
          format('%s maci %s tarihinde.', v_opponent_name,
                 to_char(new.match_date at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')),
          new.id, new.challenger_team_id);
        perform public.create_notification(
          v_opponent_captain, 'match_scheduled', 'Mac programlandi',
          format('%s maci %s tarihinde.', v_challenger_name,
                 to_char(new.match_date at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')),
          new.id, new.opponent_team_id);

      when 'completed' then
        perform public.create_notification(
          v_opponent_captain, 'match_completed', 'Mac sonucu girildi',
          format('%s maci sonuclandi, istatistikleriniz guncellendi.', v_challenger_name),
          new.id, new.opponent_team_id);
        perform public.create_notification(
          v_challenger_captain, 'match_completed', 'Mac sonucu kaydedildi',
          format('%s maci sonuclandi, istatistikleriniz guncellendi.', v_opponent_name),
          new.id, new.challenger_team_id);

      when 'auto_cancelled' then
        perform public.create_notification(
          v_challenger_captain, 'match_auto_cancelled', 'Mac otomatik iptal edildi',
          '1 hafta icinde iki taraf da mac kabulu vermedigi icin mac iptal edildi.',
          new.id, new.challenger_team_id);
        perform public.create_notification(
          v_opponent_captain, 'match_auto_cancelled', 'Mac otomatik iptal edildi',
          '1 hafta icinde iki taraf da mac kabulu vermedigi icin mac iptal edildi.',
          new.id, new.opponent_team_id);

      when 'cancelled' then
        perform public.create_notification(
          case when new.cancelled_by = v_challenger_captain then v_opponent_captain else v_challenger_captain end,
          'match_cancelled', 'Mac iptal edildi',
          coalesce(new.cancel_reason, 'Rakip taraf maci iptal etti.'),
          new.id, null);

      else
        null;
    end case;
  end if;

  return new;
end;
$fn$;

create trigger trg_match_notifications
  after insert or update on public.matches
  for each row execute function public.notify_match_event();

-- Bildirim okundugunda read_at damgasi
create or replace function public.handle_notification_read()
returns trigger
language plpgsql
as $fn$
begin
  if new.is_read and not old.is_read then
    new.read_at := now();
  elsif not new.is_read then
    new.read_at := null;
  end if;
  return new;
end;
$fn$;

create trigger trg_notification_read
  before update of is_read on public.notifications
  for each row execute function public.handle_notification_read();


-- =====================================================================
-- BÖLÜM 6 - RPC / İŞ FONKSİYONLARI
-- ---------------------------------------------------------------------
-- Uygulama bu fonksiyonlari supabase.rpc('...') ile cagirir. Boylece
-- is kurallari tek yerde toplanir, istemci sadece niyeti bildirir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6.1 Ana sayfa: en populer 3 hali saha (en cok takim kayitli olan)
-- ---------------------------------------------------------------------
create or replace function public.get_popular_pitches(p_limit int default 3)
returns table (
  id          uuid,
  name        text,
  district    text,
  address     text,
  image_url   text,
  team_count  bigint
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $fn$
  select p.id, p.name, p.district, p.address, p.image_url,
         count(t.id) as team_count
  from public.pitches p
  left join public.teams t on t.pitch_id = p.id and t.is_active
  where p.is_active
  group by p.id
  order by team_count desc, p.name asc
  limit greatest(p_limit, 1);
$fn$;

-- Alternatif: liste ekranlarinda kullanmak icin hazir view
create or replace view public.pitches_with_team_count
with (security_invoker = true) as
  select p.*, coalesce(tc.team_count, 0) as team_count
  from public.pitches p
  left join (
    select pitch_id, count(*) as team_count
    from public.teams where is_active group by pitch_id
  ) tc on tc.pitch_id = p.id;

-- ---------------------------------------------------------------------
-- 6.2 Meydan okuma olustur (A -> B)
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
    raise exception 'Yalnizca kendi takiminiz adina meydan okuyabilirsiniz'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.matches (pitch_id, challenger_team_id, opponent_team_id, challenge_message)
  select t.pitch_id, p_challenger_team_id, p_opponent_team_id, p_message
  from public.teams t where t.id = p_opponent_team_id
  returning * into v_match;

  return v_match;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6.3 Meydan okumaya yanit (kabul / red)  -- yalnizca rakip kaptan
-- ---------------------------------------------------------------------
create or replace function public.respond_to_challenge(
  p_match_id uuid,
  p_accept   boolean
)
returns public.matches
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
begin
  update public.matches
  set status = case when p_accept then 'accepted'::public.match_status
                    else 'rejected'::public.match_status end
  where id = p_match_id and status = 'pending'
  returning * into v_match;

  if v_match.id is null then
    raise exception 'Yanitlanabilir bir meydan okuma bulunamadi';
  end if;

  return v_match;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6.4 "Mac Kabulu" butonu - iki taraf da basinca mutually_agreed olur
-- ---------------------------------------------------------------------
create or replace function public.confirm_match(p_match_id uuid)
returns public.matches
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
  v_uid uuid := auth.uid();
begin
  select * into v_match from public.matches where id = p_match_id;

  if v_match.id is null then
    raise exception 'Mac bulunamadi';
  end if;
  if v_match.status <> 'accepted' then
    raise exception 'Bu mac icin kabul asamasi gecerli degil (mevcut durum: %)', v_match.status;
  end if;

  if public.is_team_captain(v_match.challenger_team_id, v_uid) then
    update public.matches set challenger_confirmed_at = coalesce(challenger_confirmed_at, now())
    where id = p_match_id returning * into v_match;
  elsif public.is_team_captain(v_match.opponent_team_id, v_uid) then
    update public.matches set opponent_confirmed_at = coalesce(opponent_confirmed_at, now())
    where id = p_match_id returning * into v_match;
  else
    raise exception 'Bu macin tarafi degilsiniz' using errcode = 'insufficient_privilege';
  end if;

  return v_match;   -- iki onay tamamlandiysa trigger status'u mutually_agreed yapar
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6.5 Mac gun/saati girisi (yalnizca meydan okuyan takim)
-- ---------------------------------------------------------------------
create or replace function public.schedule_match(
  p_match_id   uuid,
  p_match_date timestamptz
)
returns public.matches
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
begin
  if p_match_date <= now() then
    raise exception 'Mac tarihi gelecekte olmalidir';
  end if;

  update public.matches
  set match_date = p_match_date
  where id = p_match_id and status in ('mutually_agreed','scheduled')
  returning * into v_match;

  if v_match.id is null then
    raise exception 'Mutabakati tamamlanmis bir mac bulunamadi';
  end if;

  return v_match;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6.6 Mac sonucu bildirimi (yalnizca meydan okuyan takim)
--     p_outcome: 'won' | 'draw' | 'lost'  (A takiminin perspektifi)
-- ---------------------------------------------------------------------
create or replace function public.report_match_result(
  p_match_id uuid,
  p_outcome  text
)
returns public.matches
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_match  public.matches;
  v_result public.match_result;
begin
  v_result := case lower(p_outcome)
                when 'won'  then 'challenger_won'::public.match_result
                when 'win'  then 'challenger_won'::public.match_result
                when 'draw' then 'draw'::public.match_result
                when 'lost' then 'challenger_lost'::public.match_result
                when 'loss' then 'challenger_lost'::public.match_result
                else null
              end;

  if v_result is null then
    raise exception 'Gecersiz sonuc degeri: % (won | draw | lost bekleniyor)', p_outcome;
  end if;

  update public.matches
  set result = v_result
  where id = p_match_id and status = 'scheduled' and result is null
  returning * into v_match;

  if v_match.id is null then
    raise exception 'Sonuc girilebilecek bir mac bulunamadi';
  end if;

  return v_match;   -- trigger: status=completed + iki takimin G/B/M guncellenir
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6.7 Mac iptali (taraflardan biri)
-- ---------------------------------------------------------------------
create or replace function public.cancel_match(p_match_id uuid, p_reason text default null)
returns public.matches
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_match public.matches;
begin
  update public.matches
  set status = 'cancelled', cancelled_by = auth.uid(), cancel_reason = p_reason
  where id = p_match_id
    and status in ('pending','accepted','mutually_agreed','scheduled')
  returning * into v_match;

  if v_match.id is null then
    raise exception 'Iptal edilebilecek bir mac bulunamadi';
  end if;

  return v_match;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6.8 Takim mac gecmisi (en yeniden eskiye)
-- ---------------------------------------------------------------------
create or replace function public.get_team_match_history(p_team_id uuid, p_limit int default 50)
returns table (
  match_id       uuid,
  played_at      timestamptz,
  opponent_id    uuid,
  opponent_name  text,
  pitch_name     text,
  outcome        text          -- 'win' | 'draw' | 'loss' (p_team_id perspektifi)
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
         end
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

-- ---------------------------------------------------------------------
-- 6.9 Kaleci puanlama (upsert)
-- ---------------------------------------------------------------------
create or replace function public.rate_goalkeeper(
  p_goalkeeper_id uuid,
  p_rating        smallint,
  p_comment       text default null
)
returns public.goalkeepers
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
declare
  v_gk public.goalkeepers;
begin
  insert into public.goalkeeper_ratings (goalkeeper_id, rater_id, rating, comment)
  values (p_goalkeeper_id, auth.uid(), p_rating, p_comment)
  on conflict (goalkeeper_id, rater_id)
  do update set rating = excluded.rating, comment = excluded.comment, updated_at = now();

  select * into v_gk from public.goalkeepers where id = p_goalkeeper_id;
  return v_gk;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6.10 Rakip iletisim bilgisi - yalnizca kabul edilmis maclarda goruntulenir
-- ---------------------------------------------------------------------
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

  if v_match.id is null or v_match.status not in ('accepted','mutually_agreed','scheduled','completed') then
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
-- 6.11 Bildirimleri okundu isaretle
-- ---------------------------------------------------------------------
create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns int
language sql
security invoker
set search_path = public, pg_temp
as $fn$
  with upd as (
    update public.notifications
    set is_read = true
    where user_id = auth.uid()
      and not is_read
      and (p_ids is null or id = any(p_ids))
    returning 1
  )
  select count(*)::int from upd;
$fn$;


-- =====================================================================
-- BÖLÜM 7 - ZAMANLANMIŞ İŞLER (pg_cron)
-- ---------------------------------------------------------------------
-- 7.a  1 hafta icinde karsilikli onaylanmayan maclarin otomatik iptali
-- 7.b  Mac saatinden 1 saat sonra "Mac nasil sonlandi?" bildirimi
-- =====================================================================

-- 7.a --------------------------------------------------------------------
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
        cancel_reason = '1 hafta icinde karsilikli mac kabulu verilmedi'
    where status = 'accepted'
      and cancel_deadline is not null
      and cancel_deadline < now()
    returning id
  )
  select count(*) into v_count from stale;

  return v_count;   -- bildirimler trg_match_notifications tarafindan atilir
end;
$fn$;

-- 7.b --------------------------------------------------------------------
create or replace function public.send_match_result_prompts()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_count int := 0;
  r record;
begin
  for r in
    select m.id, m.challenger_team_id, m.opponent_team_id
    from public.matches m
    where m.status = 'scheduled'
      and m.result_prompt_sent_at is null
      and m.match_date is not null
      and m.match_date + interval '1 hour' <= now()
    for update skip locked
  loop
    -- Sonucu meydan okuyan takim girer -> bildirim A takiminin kaptanina
    perform public.create_notification(
      public.team_captain_id(r.challenger_team_id),
      'match_result_request',
      'Mac nasil sonlandi?',
      'Maciniz tamamlandi. Sonucu girerek takim istatistiklerinizi guncelleyin.',
      r.id, r.challenger_team_id,
      jsonb_build_object('action', 'report_result')
    );

    update public.matches set result_prompt_sent_at = now() where id = r.id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$fn$;

-- Cron kayitlari (Supabase: Database > Extensions > pg_cron aktif olmali) -----
-- Not: Ayni isimle tekrar kurulumda hata almamak icin once unschedule ediyoruz.
do $cron$
begin
  perform cron.unschedule('halisaha-auto-cancel-matches');
exception when others then null;
end;
$cron$;

do $cron$
begin
  perform cron.unschedule('halisaha-match-result-prompts');
exception when others then null;
end;
$cron$;

-- Her saat basi: suresi dolmus mutabakatsiz maclari iptal et
select cron.schedule(
  'halisaha-auto-cancel-matches',
  '0 * * * *',
  $job$ select public.auto_cancel_stale_matches(); $job$
);

-- Her 15 dakikada: mac saati + 1 saat gecmis maclar icin sonuc bildirimi
select cron.schedule(
  'halisaha-match-result-prompts',
  '*/15 * * * *',
  $job$ select public.send_match_result_prompts(); $job$
);


-- =====================================================================
-- BÖLÜM 8 - ROW LEVEL SECURITY (RLS)
-- ---------------------------------------------------------------------
-- Kural ozeti:
--  * pitches           : herkes okur, kimse yazamaz (yonetim service_role ile)
--  * profiles          : giris yapan herkes okur, herkes YALNIZCA kendi profilini yazar
--  * teams             : giris yapan herkes okur, yalnizca kaptan kendi takimini duzenler
--  * goalkeepers       : herkes okur, kullanici yalnizca kendi kaleci profilini yonetir
--  * goalkeeper_ratings: herkes okur, kullanici yalnizca kendi verdigi puani yazar
--  * matches           : giris yapan herkes okur (mac gecmisi), yalnizca taraflar yazar
--  * notifications     : yalnizca sahibi okur/gunceller; olusturma trigger/RPC ile
-- =====================================================================

alter table public.profiles           enable row level security;
alter table public.pitches            enable row level security;
alter table public.teams              enable row level security;
alter table public.goalkeepers        enable row level security;
alter table public.goalkeeper_ratings enable row level security;
alter table public.matches            enable row level security;
alter table public.notifications      enable row level security;

-- ---------------------------------------------------------------------
-- 8.1 PROFILES
-- ---------------------------------------------------------------------
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_insert_self"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- 8.2 PITCHES - herkese acik okuma, yazma yok (service_role RLS'i baypas eder)
-- ---------------------------------------------------------------------
create policy "pitches_select_all"
  on public.pitches for select
  to anon, authenticated
  using (is_active);

-- ---------------------------------------------------------------------
-- 8.3 TEAMS
-- ---------------------------------------------------------------------
create policy "teams_select_authenticated"
  on public.teams for select
  to authenticated
  using (true);

-- Kullanici yalnizca kendisini kaptan yaparak takim kurabilir
create policy "teams_insert_own_captain"
  on public.teams for insert
  to authenticated
  with check (captain_id = auth.uid());

create policy "teams_update_captain"
  on public.teams for update
  to authenticated
  using (captain_id = auth.uid())
  with check (captain_id = auth.uid());

create policy "teams_delete_captain"
  on public.teams for delete
  to authenticated
  using (captain_id = auth.uid());

-- G/B/M istatistikleri yalnizca mac sonucu trigger'i ile degisir.
-- Kaptan bunlari elle degistirmeye calisirsa engelle (auth.uid() null ise
-- islem trigger/cron/service_role kaynaklidir, izin verilir).
create or replace function public.protect_team_stats()
returns trigger
language plpgsql
as $fn$
begin
  -- Sistem kaynakli guncelleme (mac sonucu trigger'i) ise dokunma
  if coalesce(current_setting('app.bypass_guards', true), 'off') = 'on' then
    return new;
  end if;

  if auth.uid() is not null and (
       new.wins   is distinct from old.wins
    or new.draws  is distinct from old.draws
    or new.losses is distinct from old.losses
  ) then
    raise exception 'Takim istatistikleri elle degistirilemez; yalnizca mac sonuclari ile guncellenir'
      using errcode = 'insufficient_privilege';
  end if;

  -- Takim baska bir kullaniciya devredilemez
  if auth.uid() is not null and new.captain_id is distinct from old.captain_id then
    raise exception 'Takim kaptanligi bu ekrandan degistirilemez'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$fn$;

create trigger trg_protect_team_stats
  before update on public.teams
  for each row execute function public.protect_team_stats();

-- ---------------------------------------------------------------------
-- 8.4 GOALKEEPERS
-- ---------------------------------------------------------------------
create policy "goalkeepers_select_authenticated"
  on public.goalkeepers for select
  to authenticated
  using (true);

create policy "goalkeepers_insert_self"
  on public.goalkeepers for insert
  to authenticated
  with check (id = auth.uid());

create policy "goalkeepers_update_self"
  on public.goalkeepers for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "goalkeepers_delete_self"
  on public.goalkeepers for delete
  to authenticated
  using (id = auth.uid());

-- rating_avg / rating_count yalnizca puanlama trigger'i ile degisir
create or replace function public.protect_goalkeeper_rating_fields()
returns trigger
language plpgsql
as $fn$
begin
  -- Sistem kaynakli guncelleme (puanlama trigger'i) ise dokunma
  if coalesce(current_setting('app.bypass_guards', true), 'off') = 'on' then
    return new;
  end if;

  if auth.uid() is not null and (
       new.rating_avg   is distinct from old.rating_avg
    or new.rating_count is distinct from old.rating_count
  ) then
    raise exception 'Kaleci puan ortalamasi elle degistirilemez'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$fn$;

create trigger trg_protect_goalkeeper_rating_fields
  before update on public.goalkeepers
  for each row execute function public.protect_goalkeeper_rating_fields();

-- ---------------------------------------------------------------------
-- 8.5 GOALKEEPER_RATINGS
-- ---------------------------------------------------------------------
create policy "gk_ratings_select_authenticated"
  on public.goalkeeper_ratings for select
  to authenticated
  using (true);

create policy "gk_ratings_insert_self"
  on public.goalkeeper_ratings for insert
  to authenticated
  with check (rater_id = auth.uid() and goalkeeper_id <> auth.uid());

create policy "gk_ratings_update_self"
  on public.goalkeeper_ratings for update
  to authenticated
  using (rater_id = auth.uid())
  with check (rater_id = auth.uid());

create policy "gk_ratings_delete_self"
  on public.goalkeeper_ratings for delete
  to authenticated
  using (rater_id = auth.uid());

-- ---------------------------------------------------------------------
-- 8.6 MATCHES
-- ---------------------------------------------------------------------
-- Okuma: mac gecmisi ve rakip istatistikleri herkese acik olmali.
-- Iletisim bilgisi teams.contact_phone'da; hassas kabul ediliyorsa
-- get_opponent_contact() RPC'si ile sinirlandirilmis erisim kullanin.
create policy "matches_select_authenticated"
  on public.matches for select
  to authenticated
  using (true);

-- Meydan okumayi yalnizca meydan okuyan takimin kaptani olusturur
create policy "matches_insert_challenger_captain"
  on public.matches for insert
  to authenticated
  with check (
    public.is_team_captain(challenger_team_id)
    and challenger_team_id <> opponent_team_id
  );

-- Guncellemeyi yalnizca iki taraftan birinin kaptani yapar.
-- Hangi alani kimin degistirebilecegi trg_match_transition icinde denetlenir.
create policy "matches_update_participants"
  on public.matches for update
  to authenticated
  using (
    public.is_team_captain(challenger_team_id)
    or public.is_team_captain(opponent_team_id)
  )
  with check (
    public.is_team_captain(challenger_team_id)
    or public.is_team_captain(opponent_team_id)
  );

-- Silme: yalnizca henuz yanitlanmamis kendi meydan okumasi
create policy "matches_delete_pending_challenger"
  on public.matches for delete
  to authenticated
  using (status = 'pending' and public.is_team_captain(challenger_team_id));

-- ---------------------------------------------------------------------
-- 8.7 NOTIFICATIONS - yalnizca sahibi
-- ---------------------------------------------------------------------
create policy "notifications_select_own"
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid());

create policy "notifications_update_own"
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "notifications_delete_own"
  on public.notifications for delete
  to authenticated
  using (user_id = auth.uid());
-- INSERT politikasi bilincli olarak YOK: bildirimler yalnizca
-- SECURITY DEFINER trigger/fonksiyonlar tarafindan uretilir.

-- ---------------------------------------------------------------------
-- 8.8 GRANT'LER (Supabase varsayilanlarini acikca tekrar ediyoruz)
-- ---------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant select on public.pitches, public.pitches_with_team_count to anon, authenticated;

grant select, insert, update on public.profiles           to authenticated;
grant select, insert, update, delete on public.teams       to authenticated;
grant select, insert, update, delete on public.goalkeepers to authenticated;
grant select, insert, update, delete on public.goalkeeper_ratings to authenticated;
grant select, insert, update, delete on public.matches     to authenticated;
grant select, update, delete on public.notifications       to authenticated;

grant select on public.profiles_with_age, public.teams_with_stats,
                public.goalkeeper_profiles to authenticated;

-- notifications tablosuna dogrudan INSERT yetkisi verilmiyor
revoke insert on public.notifications from anon, authenticated;

-- RPC'ler
grant execute on function public.get_popular_pitches(int)            to anon, authenticated;
grant execute on function public.calculate_age(date)                 to anon, authenticated;
grant execute on function public.challenge_team(uuid, uuid, text)    to authenticated;
grant execute on function public.respond_to_challenge(uuid, boolean) to authenticated;
grant execute on function public.confirm_match(uuid)                 to authenticated;
grant execute on function public.schedule_match(uuid, timestamptz)   to authenticated;
grant execute on function public.report_match_result(uuid, text)     to authenticated;
grant execute on function public.cancel_match(uuid, text)            to authenticated;
grant execute on function public.get_team_match_history(uuid, int)   to authenticated;
grant execute on function public.rate_goalkeeper(uuid, smallint, text) to authenticated;
grant execute on function public.get_opponent_contact(uuid)          to authenticated;
grant execute on function public.mark_notifications_read(uuid[])     to authenticated;
grant execute on function public.is_team_captain(uuid, uuid)         to authenticated;
grant execute on function public.is_match_participant(uuid, uuid)    to authenticated;

-- Bakim fonksiyonlari yalnizca sunucu tarafinda cagrilir
revoke execute on function public.auto_cancel_stale_matches()  from anon, authenticated;
revoke execute on function public.send_match_result_prompts()  from anon, authenticated;
revoke execute on function public.create_notification(uuid, public.notification_type, text, text, uuid, uuid, jsonb)
  from anon, authenticated;
grant execute on function public.auto_cancel_stale_matches() to service_role;
grant execute on function public.send_match_result_prompts() to service_role;

-- Realtime: bildirim ve mac guncellemelerini canli dinlemek icin
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.matches;


-- =====================================================================
-- BÖLÜM 9 - SEED: İzmir varsayilan hali sahalari (ornek)
-- =====================================================================
insert into public.pitches (name, district, address, phone, is_indoor, has_parking, has_shower, description)
values
  ('Bornova Spor Kompleksi', 'Bornova',   'Kazimdirik Mah. Bornova/Izmir',      '+902323330001', false, true,  true,  'Iki adet 7v7 sahasi, gece aydinlatmali.'),
  ('Karsiyaka Arena',        'Karsiyaka', 'Bostanli Mah. Karsiyaka/Izmir',      '+902323330002', true,  true,  true,  'Kapali saha, suni cim, kafeterya mevcut.'),
  ('Buca Halisaha',          'Buca',      'Sirinyer Mah. Buca/Izmir',           '+902323330003', false, false, true,  'Tek saha, hafta ici indirimli.'),
  ('Gaziemir Yildiz Saha',   'Gaziemir',  'Ataturk Mah. Gaziemir/Izmir',        '+902323330004', false, true,  false, 'Otoparkli, 8v8 saha.'),
  ('Konak Sahil Spor',       'Konak',     'Goztepe Mah. Konak/Izmir',           '+902323330005', false, false, true,  'Sahil kenari, manzarali saha.'),
  ('Cigli Futbol Park',      'Cigli',     'Ataşehir Mah. Cigli/Izmir',          '+902323330006', true,  true,  true,  'Iki kapali saha, dus ve soyunma odasi.')
on conflict (name, district) do nothing;
