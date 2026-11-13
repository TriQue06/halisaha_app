-- =====================================================================
-- Rakip iletişim bilgisi: teklif anında açılır (1.0.5)
--
-- Önceden telefon yalnızca iki taraf "Maça Hazırım" dedikten sonra
-- (mutually_agreed / scheduled) görünüyordu. Kaptanlar gün/saat
-- konuşamadan karar vermek zorunda kalıyordu.
--
-- Yeni kural:
--   * pending  : teklifi ALAN kaptan, teklifi GÖNDEREN takımın numarasını
--                görür. (Gönderen, teklif ekranında numarasının
--                paylaşılacağı konusunda bilgilendirilir.) Gönderen ise
--                rakibin numarasını henüz GÖREMEZ — böylece kimse sadece
--                teklif atarak başkasının numarasını toplayamaz.
--   * accepted / mutually_agreed / scheduled : iki taraf da birbirini görür.
--   * reddedilen / iptal / tamamlanan maçlarda numara kapanır.
--   * Engellenen veya banlı kullanıcıya hiçbir aşamada gösterilmez.
-- =====================================================================

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

  if v_match.id is null
     or v_match.status not in ('pending', 'accepted', 'mutually_agreed', 'scheduled') then
    raise exception 'Iletisim bilgisi bu asamada goruntulenemez';
  end if;

  if public.is_team_captain(v_match.challenger_team_id, v_uid) then
    -- Teklifi gönderen: rakibin numarasını ancak rakip kabul edince görür.
    if v_match.status = 'pending' then
      raise exception 'Iletisim bilgisi bu asamada goruntulenemez';
    end if;
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
    where t.id = v_opp
      and not public.is_hidden_from_me(t.captain_id);
end;
$fn$;

revoke all on function public.get_opponent_contact(uuid) from public, anon;
grant execute on function public.get_opponent_contact(uuid) to authenticated;

notify pgrst, 'reload schema';
