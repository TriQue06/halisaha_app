-- =====================================================================
-- Ayni iki takim arasinda ikinci bir aktif mac teklifi olusturulmaya
-- calisildiginda ham unique-index hatasi (23505) yerine anlasilir bir
-- mesaj dondurulur. Ayrica takim kendine teklif gonderemez.
-- =====================================================================
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
