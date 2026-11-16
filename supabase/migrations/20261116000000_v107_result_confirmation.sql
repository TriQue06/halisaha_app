-- =====================================================================
-- 1.0.7
--  1) Maç sonucu onayı / itiraz
--  2) Uygulama ayarları (zorunlu güncelleme için en düşük sürüm)
--  3) Uygulama hata kaydı (çökme / beklenmeyen hata takibi)
-- =====================================================================


-- =====================================================================
-- 1) MAÇ SONUCU ONAYI / İTİRAZ
-- ---------------------------------------------------------------------
-- Akış:
--  * Bir takım skoru girer -> sonuç 'pending' (onay bekliyor).
--  * Diğer takımın kaptanı "Onayla" ya da "İtiraz et" der.
--      onay  -> 'confirmed' : G/B/M ve oyuncu istatistiklerine işlenir.
--      itiraz-> 'disputed'  : hiçbir istatistiğe sayılmaz.
--  * 48 saat içinde yanıt gelmezse sonuç otomatik onaylanır (cron).
-- Eski (bu sürümden önce tamamlanmış) maçlar 'confirmed' kabul edilir.
-- =====================================================================

alter table public.matches
  add column if not exists result_status           text,
  add column if not exists result_reported_team_id uuid references public.teams (id) on delete set null,
  add column if not exists result_responded_at     timestamptz,
  add column if not exists result_dispute_reason   text;

alter table public.matches drop constraint if exists matches_result_status_value_chk;
alter table public.matches add constraint matches_result_status_value_chk
  check (result_status is null or result_status in ('pending', 'confirmed', 'disputed'));

alter table public.matches drop constraint if exists matches_dispute_reason_len_chk;
alter table public.matches add constraint matches_dispute_reason_len_chk
  check (result_dispute_reason is null or char_length(result_dispute_reason) <= 300);

-- Mevcut tamamlanmış maçlar zaten istatistiklere işlendi: onaylı say.
-- (Bu güncelleme durum/sonuç değiştirmediği için hiçbir trigger istatistik
-- ya da bildirim üretmez.)
update public.matches
   set result_status       = 'confirmed',
       result_responded_at = coalesce(result_reported_at, now())
 where status = 'completed'
   and result is not null
   and result_status is null;

create index if not exists idx_matches_result_pending
  on public.matches (result_reported_at)
  where result_status = 'pending';


-- ---------------------------------------------------------------------
-- 1.1 Sonuç girilince/değişince 'pending'e çek; onay alanlarını koru
-- ---------------------------------------------------------------------
-- BEFORE trigger'lar isim sırasıyla çalışır; bu trigger
-- trg_match_transition'dan önce çalışır ama yalnızca sonuca bakar.
create or replace function public.handle_match_result_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_rpc boolean := coalesce(current_setting('app.result_confirm_rpc', true), 'off') = 'on';
begin
  -- Yeni sonuç girildi ya da sonuç değişti: rakibin onayı beklenir.
  if new.result is not null and new.result is distinct from old.result then
    new.result_status         := 'pending';
    new.result_responded_at   := null;
    new.result_dispute_reason := null;
    new.result_reported_team_id :=
      case when v_uid is not null and public.is_team_captain(new.opponent_team_id, v_uid)
           then new.opponent_team_id
           else new.challenger_team_id end;
    return new;
  end if;

  -- Sonuç silindiyse onay bilgisi de gider.
  if new.result is null then
    new.result_status           := null;
    new.result_reported_team_id := null;
    new.result_responded_at     := null;
    new.result_dispute_reason   := null;
    return new;
  end if;

  -- Onay alanları yalnızca respond_match_result RPC'si ya da sunucu
  -- (cron / SQL Editor) tarafından değiştirilebilir.
  if v_uid is not null and not v_rpc and (
       new.result_status           is distinct from old.result_status
    or new.result_reported_team_id is distinct from old.result_reported_team_id
    or new.result_responded_at     is distinct from old.result_responded_at
    or new.result_dispute_reason   is distinct from old.result_dispute_reason) then
    raise exception 'Mac sonucu onayi yalnizca uygulama uzerinden verilebilir'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_match_result_confirmation on public.matches;
create trigger trg_match_result_confirmation
  before update on public.matches
  for each row execute function public.handle_match_result_confirmation();

-- Yeni maç kaydında onay alanları boş başlar.
create or replace function public.clear_match_result_confirmation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $fn$
begin
  if new.result is null then
    new.result_status           := null;
    new.result_reported_team_id := null;
    new.result_responded_at     := null;
    new.result_dispute_reason   := null;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_match_result_confirmation_insert on public.matches;
create trigger trg_match_result_confirmation_insert
  before insert on public.matches
  for each row execute function public.clear_match_result_confirmation();


-- ---------------------------------------------------------------------
-- 1.2 G/B/M istatistikleri: yalnızca ONAYLI sonuçlar sayılır
-- ---------------------------------------------------------------------
create or replace function public.handle_match_result_stats()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_old boolean := false;  -- eski satır istatistiğe sayılıyor muydu?
  v_new boolean := false;  -- yeni satır sayılmalı mı?
begin
  if tg_op in ('UPDATE', 'DELETE') then
    v_old := old.status = 'completed' and old.result is not null
             and coalesce(old.result_status, 'confirmed') = 'confirmed';
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    v_new := new.status = 'completed' and new.result is not null
             and coalesce(new.result_status, 'confirmed') = 'confirmed';
  end if;

  if tg_op = 'DELETE' then
    if v_old then
      perform public.apply_match_result_to_stats(old.challenger_team_id, old.opponent_team_id, old.result, -1);
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and v_old and (not v_new or new.result is distinct from old.result) then
    perform public.apply_match_result_to_stats(old.challenger_team_id, old.opponent_team_id, old.result, -1);
  end if;

  if v_new and (tg_op = 'INSERT' or not v_old or new.result is distinct from old.result) then
    perform public.apply_match_result_to_stats(new.challenger_team_id, new.opponent_team_id, new.result, 1);
  end if;

  return new;
end;
$fn$;

-- Oyuncu maç/gol/asist sayıları da yalnızca onaylı maçlardan.
-- (Kolonlar aynı kaldığı için view yerinde güncellenir; pitch_player_stats
-- bu view'u kullandığı için o da otomatik olarak aynı kurala uyar.)
create or replace view public.team_player_stats
with (security_invoker = true) as
  select tp.id         as player_id,
         tp.team_id,
         tp.display_name,
         tp.is_active,
         count(l.id) filter (where m.status = 'completed'
                               and coalesce(m.result_status, 'confirmed') = 'confirmed')::int as appearances,
         coalesce(sum(l.goals)   filter (where m.status = 'completed'
                               and coalesce(m.result_status, 'confirmed') = 'confirmed'), 0)::int as goals,
         coalesce(sum(l.assists) filter (where m.status = 'completed'
                               and coalesce(m.result_status, 'confirmed') = 'confirmed'), 0)::int as assists
  from public.team_players tp
  left join public.match_lineups l on l.player_id = tp.id
  left join public.matches m       on m.id = l.match_id
  group by tp.id;


-- ---------------------------------------------------------------------
-- 1.3 Onay / itiraz RPC'si
-- ---------------------------------------------------------------------
create or replace function public.respond_match_result(
  p_match_id uuid,
  p_accept   boolean,
  p_reason   text default null
)
returns public.matches
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_match        public.matches;
  v_confirm_team uuid;
  v_report_team  uuid;
  v_confirm_name text;
  v_reason       text := nullif(left(btrim(coalesce(p_reason, '')), 300), '');
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match.id is null or v_match.status <> 'completed'
     or v_match.result_status is distinct from 'pending' then
    raise exception 'Onay bekleyen bir mac sonucu bulunamadi';
  end if;

  v_report_team  := coalesce(v_match.result_reported_team_id, v_match.challenger_team_id);
  v_confirm_team := case when v_report_team = v_match.challenger_team_id
                         then v_match.opponent_team_id else v_match.challenger_team_id end;

  if not public.is_team_captain(v_confirm_team) then
    raise exception 'Sonucu yalnizca rakip takimin kaptani onaylayabilir'
      using errcode = 'insufficient_privilege';
  end if;

  perform set_config('app.result_confirm_rpc', 'on', true);
  update public.matches
     set result_status         = case when p_accept then 'confirmed' else 'disputed' end,
         result_responded_at   = now(),
         result_dispute_reason = case when p_accept then null else v_reason end
   where id = p_match_id
  returning * into v_match;
  perform set_config('app.result_confirm_rpc', 'off', true);

  select name into v_confirm_name from public.teams where id = v_confirm_team;

  if p_accept then
    perform public.create_notification(
      public.team_captain_id(v_report_team), 'match_completed',
      'Sonuç onaylandı ✅',
      format('%s maç sonucunu onayladı. İstatistikler güncellendi.', v_confirm_name),
      v_match.id, v_report_team,
      jsonb_build_object('action', 'result_confirmed'));
  else
    perform public.create_notification(
      public.team_captain_id(v_report_team), 'match_completed',
      'Sonuca itiraz edildi',
      format('%s girdiğin sonuca itiraz etti%s. Maç istatistiklere sayılmayacak.',
             v_confirm_name,
             coalesce(': "' || v_reason || '"', '')),
      v_match.id, v_report_team,
      jsonb_build_object('action', 'result_disputed'));
  end if;

  return v_match;
end;
$fn$;

revoke all on function public.respond_match_result(uuid, boolean, text) from public, anon;
grant execute on function public.respond_match_result(uuid, boolean, text) to authenticated;


-- ---------------------------------------------------------------------
-- 1.4 48 saatte yanıtlanmayan sonuçları otomatik onayla (cron)
-- ---------------------------------------------------------------------
create or replace function public.auto_confirm_match_results()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_count int := 0;
  r record;
  v_body text;
begin
  for r in
    update public.matches m
       set result_status       = 'confirmed',
           result_responded_at = now()
     where m.status = 'completed'
       and m.result_status = 'pending'
       and m.result_reported_at < now() - interval '48 hours'
    returning m.id, m.challenger_team_id, m.opponent_team_id
  loop
    v_body := 'Sonuca 48 saat içinde itiraz edilmediği için onaylandı. İstatistikler güncellendi.';
    perform public.create_notification(
      public.team_captain_id(r.challenger_team_id), 'match_completed',
      'Maç sonucu onaylandı', v_body, r.id, r.challenger_team_id,
      jsonb_build_object('action', 'result_auto_confirmed'));
    perform public.create_notification(
      public.team_captain_id(r.opponent_team_id), 'match_completed',
      'Maç sonucu onaylandı', v_body, r.id, r.opponent_team_id,
      jsonb_build_object('action', 'result_auto_confirmed'));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$fn$;

revoke all on function public.auto_confirm_match_results() from public, anon, authenticated;
grant execute on function public.auto_confirm_match_results() to service_role;

do $cron$
begin
  perform cron.unschedule('halisaha-auto-confirm-results');
exception when others then null;
end;
$cron$;

select cron.schedule(
  'halisaha-auto-confirm-results',
  '*/15 * * * *',
  $job$ select public.auto_confirm_match_results(); $job$
);


-- ---------------------------------------------------------------------
-- 1.5 Bildirimler: sonuç girilince rakipten onay iste
-- ---------------------------------------------------------------------
-- 20260831010000 sürümünün aynısı; yalnızca 'completed' dalı değişti.
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
  v_report_team        uuid;
  v_confirm_team       uuid;
  v_report_name        text;
  v_confirm_name       text;
  v_score              text;
begin
  select name into v_challenger_name from public.teams where id = new.challenger_team_id;
  select name into v_opponent_name   from public.teams where id = new.opponent_team_id;

  if tg_op = 'INSERT' then
    perform public.create_notification(
      v_opponent_captain, 'challenge_received',
      'Yeni mac teklifi!',
      format('%s takimi size mac teklifi gonderdi.', v_challenger_name),
      new.id, new.opponent_team_id);
    return new;
  end if;

  if new.status is distinct from old.status then
    case new.status
      when 'accepted' then
        perform public.create_notification(
          v_challenger_captain, 'challenge_accepted',
          'Mac teklifi kabul edildi',
          format('%s takimi mac teklifinizi kabul etti. Iletisime gecip mac kabulu verin.', v_opponent_name),
          new.id, new.challenger_team_id);

      when 'rejected' then
        perform public.create_notification(
          v_challenger_captain, 'challenge_rejected',
          'Mac teklifi reddedildi',
          format('%s takimi mac teklifinizi reddetti.', v_opponent_name),
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
        v_report_team  := coalesce(new.result_reported_team_id, new.challenger_team_id);
        v_confirm_team := case when v_report_team = new.challenger_team_id
                               then new.opponent_team_id else new.challenger_team_id end;
        select name into v_report_name  from public.teams where id = v_report_team;
        select name into v_confirm_name from public.teams where id = v_confirm_team;

        v_score := case
          when new.challenger_score is not null and new.opponent_score is not null then
            format('%s %s - %s %s', v_challenger_name, new.challenger_score,
                   new.opponent_score, v_opponent_name)
          when new.result = 'draw' then 'Berabere'
          when new.result = 'challenger_won' then format('%s kazandı', v_challenger_name)
          else format('%s kazandı', v_opponent_name)
        end;

        perform public.create_notification(
          public.team_captain_id(v_confirm_team), 'match_completed',
          'Sonuç doğru mu?',
          format('%s maç sonucunu girdi: %s. Doğruysa onayla, değilse itiraz et. '
                 || '48 saat içinde yanıt vermezsen sonuç onaylanır.', v_report_name, v_score),
          new.id, v_confirm_team,
          jsonb_build_object('action', 'confirm_result'));
        perform public.create_notification(
          public.team_captain_id(v_report_team), 'match_completed',
          'Sonuç kaydedildi',
          format('%s. %s takımının onayı bekleniyor; onaylanınca istatistiklere işlenecek.',
                 v_score, v_confirm_name),
          new.id, v_report_team,
          jsonb_build_object('action', 'result_waiting'));

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


-- ---------------------------------------------------------------------
-- 1.6 Maç geçmişi: onay durumu + "onayını bekliyor" bayrağı
-- ---------------------------------------------------------------------
-- Dönüş kolonları değiştiği için fonksiyon silinip yeniden kuruluyor.
drop function if exists public.get_team_match_history(uuid, int);

create function public.get_team_match_history(p_team_id uuid, p_limit int default 50)
returns table (
  match_id                 uuid,
  played_at                timestamptz,
  opponent_id              uuid,
  opponent_name            text,
  pitch_name               text,
  outcome                  text,       -- 'win' | 'draw' | 'loss' (p_team_id perspektifi)
  team_score               smallint,   -- eski maclarda null (yalnizca G/B/M girilmisti)
  opponent_score           smallint,
  team_size                smallint,
  reported_at              timestamptz,
  result_status            text,       -- 'pending' | 'confirmed' | 'disputed'
  awaiting_my_confirmation boolean     -- bu takimin kaptani onay vermeli mi?
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
         m.result_reported_at,
         coalesce(m.result_status, 'confirmed'),
         coalesce(m.result_status = 'pending'
           and coalesce(m.result_reported_team_id, m.challenger_team_id) <> p_team_id
           and exists (select 1 from public.teams t
                        where t.id = p_team_id and t.captain_id = auth.uid()), false)
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

revoke all on function public.get_team_match_history(uuid, int) from public, anon;
grant execute on function public.get_team_match_history(uuid, int) to authenticated;


-- =====================================================================
-- 2) UYGULAMA AYARLARI (zorunlu güncelleme)
-- ---------------------------------------------------------------------
-- min_version_android / min_version_ios: bu sürümden eski uygulamalar
-- açılışta "Güncelleme gerekli" ekranı gösterir. '1.0.0' = kimse
-- zorlanmaz. Yükseltmek için:
--   update public.app_config set value = '1.0.7' where key = 'min_version_android';
-- =====================================================================
create table if not exists public.app_config (
  key        text primary key check (char_length(key) <= 60),
  value      text not null check (char_length(value) <= 500),
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists app_config_read on public.app_config;
create policy app_config_read on public.app_config
  for select to anon, authenticated using (true);

revoke all on public.app_config from anon, authenticated;
grant select on public.app_config to anon, authenticated;

insert into public.app_config (key, value) values
  ('min_version_android', '1.0.0'),
  ('min_version_ios',     '1.0.0'),
  ('store_url_android',   'https://play.google.com/store/apps/details?id=com.japonkale.app'),
  ('store_url_ios',       '')
on conflict (key) do nothing;


-- =====================================================================
-- 3) UYGULAMA HATA KAYDI
-- ---------------------------------------------------------------------
-- Uygulamada yakalanmayan hatalar buraya düşer (yalnızca SQL Editor'den
-- okunur). Bakmak için:
--   select created_at, platform, app_version, message, stack
--   from public.client_errors order by created_at desc limit 50;
-- =====================================================================
create table if not exists public.client_errors (
  id          bigint generated always as identity primary key,
  user_id     uuid references auth.users (id) on delete cascade,
  platform    text not null check (char_length(platform) <= 20),
  app_version text check (char_length(app_version) <= 40),
  message     text not null check (char_length(message) <= 1000),
  stack       text check (char_length(stack) <= 4000),
  fatal       boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists client_errors_created_idx
  on public.client_errors (created_at desc);

alter table public.client_errors enable row level security;
-- Politika yok: istemci doğrudan okuyamaz/yazamaz; yalnızca aşağıdaki RPC.

create or replace function public.log_client_error(
  p_platform    text,
  p_app_version text,
  p_message     text,
  p_stack       text default null,
  p_fatal       boolean default false
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if auth.uid() is null then
    return;
  end if;
  -- Kötüye kullanım / hata döngüsü sınırı: kullanıcı başına saatte 30 kayıt.
  if (select count(*) from public.client_errors
       where user_id = auth.uid() and created_at > now() - interval '1 hour') >= 30 then
    return;
  end if;
  insert into public.client_errors (user_id, platform, app_version, message, stack, fatal)
  values (auth.uid(), left(coalesce(p_platform, '?'), 20), left(p_app_version, 40),
          left(coalesce(p_message, '?'), 1000), left(p_stack, 4000), coalesce(p_fatal, false));
end;
$fn$;

revoke all on function public.log_client_error(text, text, text, text, boolean) from public, anon;
grant execute on function public.log_client_error(text, text, text, text, boolean) to authenticated;

-- Eski hata kayıtlarını 30 günde temizle.
do $cron$
begin
  perform cron.unschedule('halisaha-client-errors-cleanup');
exception when others then null;
end;
$cron$;

select cron.schedule(
  'halisaha-client-errors-cleanup',
  '17 4 * * *',
  $job$ delete from public.client_errors where created_at < now() - interval '30 days'; $job$
);

notify pgrst, 'reload schema';
