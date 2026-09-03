-- =====================================================================
-- Bildirim metinlerinde "meydan okuma" ifadesi "mac teklifi" olarak
-- guncellendi. Fonksiyon govdesi disinda bir degisiklik yok; trigger
-- tanimi aynen gecerli kalir.
-- =====================================================================
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
