-- =====================================================================
-- 1.0.6 - Maç hatırlatma bildirimleri
-- ---------------------------------------------------------------------
-- Planlanmış (scheduled) maçlar için iki takımın kaptanına iki hatırlatma:
--   * Gün hatırlatması : maça 24 saatten az kaldığında (2 saatten fazla varken)
--   * Yakın hatırlatma : maça 2 saatten az kaldığında
-- Cron her 15 dakikada çalışır; her hatırlatma bir kez gider.
-- Maç saati değişirse hatırlatmalar sıfırlanır ve yeni saate göre tekrar gider.
-- Bildirim tipi 'match_scheduled' (push'ta "Maç bildirimleri" ayarına bağlı).
-- =====================================================================

alter table public.matches
  add column if not exists reminder_day_sent_at timestamptz,
  add column if not exists reminder_2h_sent_at  timestamptz;

-- Maç saati değişince hatırlatma bayraklarını sıfırla -----------------
create or replace function public.reset_match_reminders()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $fn$
begin
  if new.match_date is distinct from old.match_date then
    new.reminder_day_sent_at := null;
    new.reminder_2h_sent_at  := null;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_matches_reset_reminders on public.matches;
create trigger trg_matches_reset_reminders
  before update of match_date on public.matches
  for each row execute function public.reset_match_reminders();

-- Hatırlatmaları gönder ------------------------------------------------
create or replace function public.send_match_reminders()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_count int := 0;
  r record;
  v_when  text;
  v_title text;
  v_body  text;
  v_kind  text;
begin
  for r in
    select m.id, m.match_date, m.challenger_team_id, m.opponent_team_id,
           m.reminder_day_sent_at, m.reminder_2h_sent_at,
           ct.name as challenger_name, ot.name as opponent_name,
           p.name  as pitch_name
    from public.matches m
    join public.teams   ct on ct.id = m.challenger_team_id
    join public.teams   ot on ot.id = m.opponent_team_id
    left join public.pitches p on p.id = m.pitch_id
    where m.status = 'scheduled'
      and m.match_date is not null
      and m.match_date > now()
      and m.match_date <= now() + interval '24 hours'
      and (
            (m.reminder_2h_sent_at is null and m.match_date <= now() + interval '2 hours')
         or (m.reminder_day_sent_at is null and m.reminder_2h_sent_at is null
             and m.match_date > now() + interval '2 hours')
      )
    for update of m skip locked
  loop
    v_when := to_char(r.match_date at time zone 'Europe/Istanbul', 'HH24:MI');

    if r.match_date <= now() + interval '2 hours' then
      v_kind  := '2h';
      v_title := 'Maçın yaklaşıyor ⚽';
      v_body  := format('%s - %s maçı bugün saat %s%s. Hazır mısınız?',
                        r.challenger_name, r.opponent_name, v_when,
                        coalesce(', ' || r.pitch_name, ''));
    else
      v_kind  := 'day';
      v_title := 'Maç hatırlatması';
      v_body  := format('%s - %s maçı %s saat %s%s.',
                        r.challenger_name, r.opponent_name,
                        case when (r.match_date at time zone 'Europe/Istanbul')::date
                                  = (now() at time zone 'Europe/Istanbul')::date
                             then 'bugün' else 'yarın' end,
                        v_when,
                        coalesce(', ' || r.pitch_name, ''));
    end if;

    perform public.create_notification(
      public.team_captain_id(r.challenger_team_id),
      'match_scheduled', v_title, v_body,
      r.id, r.challenger_team_id,
      jsonb_build_object('action', 'match_reminder', 'reminder', v_kind)
    );
    perform public.create_notification(
      public.team_captain_id(r.opponent_team_id),
      'match_scheduled', v_title, v_body,
      r.id, r.opponent_team_id,
      jsonb_build_object('action', 'match_reminder', 'reminder', v_kind)
    );

    if v_kind = '2h' then
      -- 2 saat hatırlatması gittiyse gün hatırlatmasına gerek kalmaz.
      update public.matches
         set reminder_2h_sent_at  = now(),
             reminder_day_sent_at = coalesce(reminder_day_sent_at, now())
       where id = r.id;
    else
      update public.matches set reminder_day_sent_at = now() where id = r.id;
    end if;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$fn$;

revoke all on function public.send_match_reminders() from public, anon, authenticated;
grant execute on function public.send_match_reminders() to service_role;
revoke all on function public.reset_match_reminders() from public, anon, authenticated;

-- Cron: her 15 dakikada ----------------------------------------------
do $cron$
begin
  perform cron.unschedule('halisaha-match-reminders');
exception when others then null;
end;
$cron$;

select cron.schedule(
  'halisaha-match-reminders',
  '*/15 * * * *',
  $job$ select public.send_match_reminders(); $job$
);
