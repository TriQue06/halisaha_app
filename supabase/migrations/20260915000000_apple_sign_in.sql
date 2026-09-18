-- =====================================================================
-- APPLE ILE GIRIS: token saklama (hesap silmede iptal icin)
--
-- App Store kurali: "Apple ile Giris" kullanan uygulama, kullanici
-- hesabini sildiginde Apple'daki yetkiyi de REST API ile iptal etmeli
-- (https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens).
--
-- Iptal icin Apple'in refresh token'i gerekiyor. Uygulama giriste aldigi
-- authorization code'u "apple-auth" Edge Function'ina gonderiyor; fonksiyon
-- kodu refresh token'a cevirip buraya yaziyor. Hesap silinirken ayni
-- fonksiyon token'i Apple'da iptal edip satiri siliyor.
--
-- Tabloya istemciden hic erisilemez: RLS acik ve hicbir politika yok.
-- Yalnizca service_role anahtariyla calisan Edge Function okuyup yazar.
-- =====================================================================

create table if not exists public.apple_tokens (
  user_id       uuid        primary key references public.profiles (id) on delete cascade,
  refresh_token text        not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

drop trigger if exists trg_apple_tokens_updated on public.apple_tokens;
create trigger trg_apple_tokens_updated
  before update on public.apple_tokens
  for each row execute function public.set_updated_at();

alter table public.apple_tokens enable row level security;

-- Kasitli olarak politika YOK: authenticated/anon hicbir satiri goremez.
revoke all on public.apple_tokens from anon, authenticated;
