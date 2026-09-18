// =====================================================================
// apple-auth — Supabase Edge Function
//
// "Apple ile Giriş" token yönetimi. App Store, Apple ile giriş yapan bir
// kullanıcı hesabını sildiğinde Apple'daki yetkinin de iptal edilmesini
// zorunlu tutuyor. Bunun için refresh token saklanmalı.
//
// Uygulama çağırır (kullanıcının oturum JWT'siyle):
//   { action: 'store',  code: <authorizationCode> }  -> girişten hemen sonra
//   { action: 'revoke' }                              -> hesap silinmeden önce
//
// Gerekli secret'lar (Supabase → Edge Functions → Secrets):
//   APPLE_TEAM_ID      : Apple Developer → Membership → Team ID (10 karakter)
//   APPLE_KEY_ID       : Sign in with Apple için oluşturulan anahtarın Key ID'si
//   APPLE_PRIVATE_KEY  : o anahtarın .p8 dosyasının TAM içeriği
//   APPLE_BUNDLE_ID    : com.japonkale.app
//   SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY : otomatik
//
// Deploy:  supabase functions deploy apple-auth
// (JWT doğrulaması AÇIK kalmalı: yalnızca giriş yapmış kullanıcı çağırabilir.)
// =====================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

const APPLE_AUDIENCE = 'https://appleid.apple.com';

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * .p8 içeriğini Web Crypto'nun beklediği DER'e çevirir.
 * push-notification fonksiyonundaki ile aynı mantık: panele yapıştırılan
 * anahtar kaçışlı ya da gerçek satır sonlarıyla gelebiliyor.
 */
function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/\\\\/g, '\\')
    .replace(/\\r/g, '')
    .replace(/\\n/g, '\n')
    .replace(/-----[A-Z ]+-----/g, '')
    .replace(/[^A-Za-z0-9+/=]/g, '');
  const raw = atob(body);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

/**
 * Apple'a karşı "client_secret": ES256 ile imzalı kısa ömürlü JWT.
 * Web Crypto'nun ECDSA imzası zaten JWS'in beklediği ham r||s biçiminde.
 */
async function appleClientSecret(): Promise<string> {
  const teamId = Deno.env.get('APPLE_TEAM_ID')!;
  const keyId = Deno.env.get('APPLE_KEY_ID')!;
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID')!;
  const now = Math.floor(Date.now() / 1000);

  const header = base64Url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const claims = base64Url(
    JSON.stringify({ iss: teamId, iat: now, exp: now + 300, aud: APPLE_AUDIENCE, sub: bundleId }),
  );

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(Deno.env.get('APPLE_PRIVATE_KEY')!),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;
}

async function applePost(path: string, params: Record<string, string>): Promise<Response> {
  return fetch(`${APPLE_AUDIENCE}/auth/${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: Deno.env.get('APPLE_BUNDLE_ID')!,
      client_secret: await appleClientSecret(),
      ...params,
    }),
  });
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  // Çağıranı doğrula: işlem yalnızca bu kullanıcının kaydı üzerinde yapılır.
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } },
  );
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json({ error: 'Yetkisiz' }, 401);

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  let body: { action?: string; code?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Geçersiz istek gövdesi' }, 400);
  }

  try {
    if (body.action === 'store') {
      if (!body.code) return json({ error: 'code eksik' }, 400);

      const res = await applePost('token', {
        grant_type: 'authorization_code',
        code: body.code,
      });
      const data = await res.json();
      if (!res.ok || !data.refresh_token) {
        return json({ error: 'Apple token alınamadı', detail: data }, 502);
      }

      const { error } = await admin
        .from('apple_tokens')
        .upsert({ user_id: user.id, refresh_token: data.refresh_token });
      if (error) return json({ error: error.message }, 500);
      return json({ stored: true });
    }

    if (body.action === 'revoke') {
      const { data: row } = await admin
        .from('apple_tokens')
        .select('refresh_token')
        .eq('user_id', user.id)
        .maybeSingle();
      if (!row) return json({ revoked: false, reason: 'kayıtlı token yok' });

      const res = await applePost('revoke', {
        token: row.refresh_token,
        token_type_hint: 'refresh_token',
      });
      if (!res.ok) {
        return json({ error: 'Apple iptali başarısız', detail: await res.text() }, 502);
      }

      await admin.from('apple_tokens').delete().eq('user_id', user.id);
      return json({ revoked: true });
    }

    return json({ error: 'Bilinmeyen action' }, 400);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
