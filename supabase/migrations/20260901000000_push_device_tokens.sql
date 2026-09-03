-- =====================================================================
-- PUSH BILDIRIMI: cihaz token tablosu
--
-- Her kullanicinin birden fazla cihazi olabilir; FCM token'i cihaz basina
-- benzersizdir ve uygulama yeniden kurulunca degisir. Token birincil
-- anahtar oldugu icin ayni token baska bir hesaba gecerse (ortak telefon)
-- upsert ile sahibi guncellenir; boylece eski hesaba bildirim gitmez.
-- =====================================================================

create table if not exists public.device_tokens (
  token       text        primary key,
  user_id     uuid        not null references public.profiles (id) on delete cascade,
  platform    text        not null default 'android'
                check (platform in ('android','ios','web')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_device_tokens_user on public.device_tokens (user_id);

drop trigger if exists trg_device_tokens_updated on public.device_tokens;
create trigger trg_device_tokens_updated
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

alter table public.device_tokens enable row level security;

-- Kullanici yalnizca kendi token'larini gorur ve siler.
drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own"
  on public.device_tokens for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own"
  on public.device_tokens for delete
  to authenticated
  using (user_id = auth.uid());

grant select, delete on public.device_tokens to authenticated;
-- Insert/update yalnizca asagidaki RPC uzerinden yapilir.
revoke insert, update on public.device_tokens from anon, authenticated;

-- ---------------------------------------------------------------------
-- Token kaydi/tazelenmesi
-- ---------------------------------------------------------------------
create or replace function public.register_device_token(
  p_token    text,
  p_platform text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli' using errcode = 'insufficient_privilege';
  end if;
  if p_token is null or length(trim(p_token)) = 0 then
    return;
  end if;

  insert into public.device_tokens (token, user_id, platform)
  values (trim(p_token), auth.uid(), coalesce(p_platform, 'android'))
  on conflict (token) do update
    set user_id  = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$fn$;

-- Cikis yaparken cagrilir: bu cihaza artik bildirim gitmesin.
create or replace function public.unregister_device_token(p_token text)
returns void
language sql
security invoker
set search_path = public, pg_temp
as $fn$
  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
$fn$;

grant execute on function public.register_device_token(text, text)   to authenticated;
grant execute on function public.unregister_device_token(text)       to authenticated;
