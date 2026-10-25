-- SETUP (geri alinmaz)
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'a@x.com', '{"first_name":"Ali","last_name":"Kaptan"}'),
  ('22222222-2222-2222-2222-222222222222', 'b@x.com', '{"first_name":"Bora","last_name":"Rakip"}'),
  ('33333333-3333-3333-3333-333333333333', 'c@x.com', '{"first_name":"Cem","last_name":"Baska"}'),
  ('44444444-4444-4444-4444-444444444444', 'd@x.com', '{"first_name":"Deniz","last_name":"Banli"}'),
  ('55555555-5555-5555-5555-555555555555', 'e@x.com', '{"full_name":"Ece Yildiz"}');
delete from public.profiles where id = '55555555-5555-5555-5555-555555555555';
update public.profiles set phone = '+905551112233' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set phone = '+905554445566' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set phone = '+905557778899', is_banned = true where id = '44444444-4444-4444-4444-444444444444';

create function pg_temp.as_user(u text) returns void language sql as
  $$ select set_config('request.jwt.claim.sub', u, false) $$;

create table public._ids (k text primary key, v uuid);
insert into public._ids select 'pitch', id from public.pitches order by name limit 1;

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set role authenticated;
insert into public._ids select 'teamA', (public.create_team_with_roster(
  (select v from public._ids where k = 'pitch'), 'Kartallar',
  '[{"first_name":"Ali","last_name":"Veli"},{"first_name":"Can"},{"first_name":"Ege"},
    {"first_name":"Efe"},{"first_name":"Arda"},{"first_name":"Mert"},{"first_name":"Kaan"}]'::jsonb)).id;
reset role;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
set role authenticated;
insert into public._ids select 'teamB', (public.create_team_with_roster(
  (select v from public._ids where k = 'pitch'), 'Aslanlar',
  '[{"first_name":"Bir"},{"first_name":"Iki"},{"first_name":"Uc"},{"first_name":"Dort"},
    {"first_name":"Bes"},{"first_name":"Alti"},{"first_name":"Yedi"}]'::jsonb)).id;
reset role;
grant all on public._ids to authenticated;

-- TEST: istatistik fonksiyonu disaridan cagrilamaz
-- EXPECT ERROR: permission denied
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select public.apply_match_result_to_stats((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'), 'challenger_won', 100);

-- TEST: bakim fonksiyonu disaridan cagrilamaz
-- EXPECT ERROR: permission denied
set local role authenticated;
select public.send_match_result_prompts();

-- TEST: baskasinin telefonu okunamaz
-- EXPECT ERROR: permission denied
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select phone from public.profiles where id = '11111111-1111-1111-1111-111111111111';

-- TEST: baskasinin dogum tarihi okunamaz
-- EXPECT ERROR: permission denied
set local role authenticated;
select birth_date from public.profiles limit 1;

-- TEST: ad soyad okunabilir
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select (count(*) = 1) as ok from public.profiles
 where id = '11111111-1111-1111-1111-111111111111' and first_name = 'Ali';

-- TEST: takim telefonu okunamaz
-- EXPECT ERROR: permission denied
set local role authenticated;
select contact_phone from public.teams;

-- TEST: teams_with_stats yildizla okunur ve telefon icermez
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select (count(*) = 2 and bool_and(to_jsonb(t) ? 'contact_phone' = false)) as ok
  from public.teams_with_stats t;

-- TEST: kendi profili telefonla gelir
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select ((public.get_my_profile()).phone = '+905551112233') as ok;

-- TEST: profili olmayan kullanici icin profil olusturulur
select pg_temp.as_user('55555555-5555-5555-5555-555555555555');
set local role authenticated;
select ((p).first_name = 'Ece' and (p).last_name = 'Yildiz') as ok from (select public.get_my_profile() as p) s;

-- TEST: kaleci listesi yasla okunur
reset role;
update public.profiles set birth_date = '1995-05-05' where id = '11111111-1111-1111-1111-111111111111';
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public.goalkeepers (id, districts, about, contact_phone) values (auth.uid(), '{Bornova}', 'Refleksli', '');
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select (count(*) = 1 and min(age) >= 30) as ok from public.goalkeeper_profiles;

-- TEST: maclara dogrudan yazilamaz
-- EXPECT ERROR: permission denied
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
update public.matches set status = 'completed';

-- TEST: mac akisi uctan uca (teklif, kabul, hazir, tarih, kadro, skor, istatistik)
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select public.respond_to_challenge((select v from public._ids where k='m'), true);
select public.confirm_match((select v from public._ids where k='m'));
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.confirm_match((select v from public._ids where k='m'));
select public.schedule_match((select v from public._ids where k='m'), now() + interval '2 days', 5::smallint);
select public.set_match_lineup((select v from public._ids where k='m'),
  (select array_agg(id order by created_at) from (select id, created_at from public.team_players
    where team_id = (select v from public._ids where k='teamA') order by created_at limit 5) s));
reset role;
update public.matches set match_date = now() - interval '2 hours' where id = (select v from public._ids where k='m');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select public.report_match_score((select v from public._ids where k='m'), 3, 1,
  jsonb_build_array(jsonb_build_object('player_id',
    (select player_id from public.match_lineups where match_id = (select v from public._ids where k='m') and slot = 1),
    'goals', 2, 'assists', 1)));
select (t.wins = 1 and m.status = 'completed' and m.challenger_score = 3
        and (select goals from public.team_player_stats where display_name = 'Ali V.') = 2) as ok
  from public.teams_with_stats t, public.matches m
 where t.id = (select v from public._ids where k='teamA') and m.id = (select v from public._ids where k='m');

-- TEST: rakip kaptan skoru teklif sahibinden once giremez
-- EXPECT ERROR: 24 saat
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm2', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select public.respond_to_challenge((select v from public._ids where k='m2'), true);
select public.confirm_match((select v from public._ids where k='m2'));
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.confirm_match((select v from public._ids where k='m2'));
select public.schedule_match((select v from public._ids where k='m2'), now() + interval '1 day', 7::smallint);
reset role;
update public.matches set match_date = now() - interval '3 hours' where id = (select v from public._ids where k='m2');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select public.report_match_score((select v from public._ids where k='m2'), 2, 2);

-- TEST: rakip kaptan 24 saat sonra skoru girebilir
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm3', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select public.respond_to_challenge((select v from public._ids where k='m3'), true);
select public.confirm_match((select v from public._ids where k='m3'));
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.confirm_match((select v from public._ids where k='m3'));
select public.schedule_match((select v from public._ids where k='m3'), now() + interval '1 day', 7::smallint);
reset role;
update public.matches set match_date = now() - interval '30 hours' where id = (select v from public._ids where k='m3');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select public.report_match_score((select v from public._ids where k='m3'), 4, 0);
select (m.result = 'challenger_lost' and m.challenger_score = 0 and m.opponent_score = 4) as ok
  from public.matches m where id = (select v from public._ids where k='m3');

-- TEST: mac tarafi olmayan iptal edemez
-- EXPECT ERROR: tarafi degilsiniz
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm4', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select public.cancel_match((select v from public._ids where k='m4'));

-- TEST: telefon kabul asamasinda acilmaz
-- EXPECT ERROR: bu asamada
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm5', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select public.respond_to_challenge((select v from public._ids where k='m5'), true);
select * from public.get_opponent_contact((select v from public._ids where k='m5'));

-- TEST: telefon karsilikli onaydan sonra acilir
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm6', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select public.respond_to_challenge((select v from public._ids where k='m6'), true);
select public.confirm_match((select v from public._ids where k='m6'));
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.confirm_match((select v from public._ids where k='m6'));
select (contact_phone = '+905554445566') as ok from public.get_opponent_contact((select v from public._ids where k='m6'));

-- TEST: banli hesap takim kuramaz
-- EXPECT ERROR: askiya
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select public.create_team_with_roster((select v from public._ids where k='pitch'), 'Yeni Takim',
  '[{"first_name":"a"},{"first_name":"b"},{"first_name":"c"},{"first_name":"d"},{"first_name":"e"},{"first_name":"f"},{"first_name":"g"}]'::jsonb);

-- TEST: banli hesap kaleci profili acamaz
-- EXPECT ERROR: askiya
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
set local role authenticated;
insert into public.goalkeepers (id, districts, about, contact_phone) values (auth.uid(), '{Buca}', 'x', '');

-- TEST: uygunsuz takim adi reddedilir
-- EXPECT ERROR: Uygunsuz
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
reset role;
update public.profiles set phone = '+905550000000' where id = auth.uid();
set local role authenticated;
select public.create_team_with_roster((select v from public._ids where k='pitch'), 'Amk FC',
  '[{"first_name":"a"},{"first_name":"b"},{"first_name":"c"},{"first_name":"d"},{"first_name":"e"},{"first_name":"f"},{"first_name":"g"}]'::jsonb);

-- TEST: masum kelimeler filtreye takilmaz (Siki, Sikke, Pickup, Gotik)
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
reset role;
update public.profiles set phone = '+905550000000' where id = auth.uid();
set local role authenticated;
select public.create_team_with_roster((select v from public._ids where k='pitch'), 'Sıkı Sikke Pickup Gotik',
  '[{"first_name":"Amir"},{"first_name":"Sıla"},{"first_name":"Pıçak"},{"first_name":"Orhan"},{"first_name":"Göktuğ"},{"first_name":"Seksen"},{"first_name":"Dicle"}]'::jsonb);
select true as ok;

-- TEST: uygunsuz oyuncu adi reddedilir
-- EXPECT ERROR: Uygunsuz
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select public.save_team_roster((select v from public._ids where k='teamA'),
  '[{"first_name":"orospu"},{"first_name":"b"},{"first_name":"c"},{"first_name":"d"},{"first_name":"e"},{"first_name":"f"},{"first_name":"g"}]'::jsonb);

-- TEST: oyuncunun soyadi baskalarina kapali
-- EXPECT ERROR: permission denied
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select last_name from public.team_players;

-- TEST: oyuncu gorunen adi bas harfle
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select (count(*) = 1) as ok from public.team_players where display_name = 'Ali V.';

-- TEST: kadronun tam hali yalnizca kaptana
-- EXPECT ERROR: yalnizca kaptan
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select * from public.get_team_roster_full((select v from public._ids where k='teamA'));

-- TEST: kaptan kadroyu tam adla gorur
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select (count(*) filter (where last_name = 'Veli') = 1) as ok
  from public.get_team_roster_full((select v from public._ids where k='teamA'));

-- TEST: rapor gelince yoneticiye bildirim gider
reset role;
insert into public.app_admins (user_id) values ('33333333-3333-3333-3333-333333333333');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public.reports (reported_user_id, context, reason) values
  ('22222222-2222-2222-2222-222222222222', 'team', 'abusive');
reset role;
select (count(*) = 1) as ok from public.notifications
 where user_id = '33333333-3333-3333-3333-333333333333' and title = 'Yeni rapor';

-- TEST: engellenen kisinin takimi temel tabloda da gorunmez
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select public.block_user('22222222-2222-2222-2222-222222222222');
select (count(*) = 0) as ok from public.teams where captain_id = '22222222-2222-2222-2222-222222222222';

-- TEST: 18 yas alti dogum tarihi reddedilir
-- EXPECT ERROR: 18 yas
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
update public.profiles set birth_date = current_date - interval '15 years' where id = auth.uid();

-- TEST: bildirim tercihi ve kosul kabulu kaydedilir
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select public.set_notification_prefs(false, null);
select public.accept_terms('2026-10');
select ((p).notify_challenges = false and (p).notify_matches and (p).terms_version = '2026-10'
        and (p).terms_accepted_at is not null) as ok from (select public.get_my_profile() p) s;

-- TEST: yanitlanmayan teklif 7 gunde duser
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm7', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
reset role;
select set_config('request.jwt.claim.sub', '', false);
update public.matches set created_at = now() - interval '8 days' where id = (select v from public._ids where k='m7');
select public.auto_cancel_stale_matches();
select (status = 'auto_cancelled') as ok from public.matches where id = (select v from public._ids where k='m7');

-- TEST: mac skoru dogrudan degistirilemez ve takimlar sonradan degistirilemez
-- EXPECT ERROR: degistirilemez
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public._ids select 'm8', (public.challenge_team((select v from public._ids where k='teamA'),
  (select v from public._ids where k='teamB'))).id;
reset role;
update public.matches set opponent_team_id = (select v from public._ids where k='teamA'),
  challenger_team_id = (select v from public._ids where k='teamB')
 where id = (select v from public._ids where k='m8');

-- TEST: kaptan kadro duzenleyebilir (soyadsiz oyuncu)
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select public.save_team_roster((select v from public._ids where k='teamA'),
  '[{"first_name":"A"},{"first_name":"B"},{"first_name":"C"},{"first_name":"D"},{"first_name":"E"},{"first_name":"F"},{"first_name":"G","last_name":"Han"}]'::jsonb);
select (count(*) = 7) as ok from public.team_player_stats
 where team_id = (select v from public._ids where k='teamA') and is_active;

-- TEST: hesap silme calisir (takimi ve maclari ile)
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select public.delete_my_account();
reset role;
select (count(*) = 0) as ok from auth.users where id = '22222222-2222-2222-2222-222222222222';

-- TEST: banli hesap da kendi hesabini silebilir
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select public.delete_my_account();
reset role;
select (count(*) = 0) as ok from auth.users where id = '44444444-4444-4444-4444-444444444444';
