-- =====================================================================
-- Push bildirimi teşhis kaydı
--
-- iOS cihazlar device_tokens tablosuna hiç kaydolmuyordu ve uygulama bunun
-- sebebini sessizce yutuyordu. Uygulama artık kayıt adımlarının sonucunu
-- (ok / apns_null / fcm_token_null / fcm_token_error / save_failed /
-- init_failed) buraya yazıyor. Sadece yöneticiler / SQL Editor okur.
-- =====================================================================

create table if not exists public.push_diagnostics (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  platform    text not null check (platform in ('ios', 'android')),
  stage       text not null check (length(stage) <= 40),
  detail      text check (length(detail) <= 500),
  created_at  timestamptz not null default now()
);

create index if not exists push_diagnostics_created_idx
  on public.push_diagnostics (created_at desc);

alter table public.push_diagnostics enable row level security;
-- Politika yok: istemci doğrudan okuyamaz/yazamaz; yalnızca aşağıdaki RPC.

create or replace function public.log_push_diagnostic(
  p_platform text,
  p_stage    text,
  p_detail   text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  insert into public.push_diagnostics (user_id, platform, stage, detail)
  values (auth.uid(), p_platform, left(p_stage, 40), left(p_detail, 500));
end;
$$;

revoke all on function public.log_push_diagnostic(text, text, text) from public, anon;
grant execute on function public.log_push_diagnostic(text, text, text) to authenticated;

notify pgrst, 'reload schema';
