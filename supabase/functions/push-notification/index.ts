// =====================================================================
// push-notification — Supabase Edge Function
//
// `notifications` tablosuna satır eklendiğinde Database Webhook tarafından
// çağrılır ve o kullanıcının kayıtlı cihazlarına FCM push'u gönderir.
//
// Gerekli secret'lar (Supabase → Edge Functions → Secrets):
//   FIREBASE_PROJECT_ID       : japon-kale
//   FIREBASE_CLIENT_EMAIL     : service account e-postası
//   FIREBASE_PRIVATE_KEY      : service account özel anahtarı (PEM)
//   SUPABASE_URL              : otomatik tanımlı
//   SUPABASE_SERVICE_ROLE_KEY : otomatik tanımlı
// =====================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface NotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  match_id: string | null;
}

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: NotificationRow | null;
}

// ---------------------------------------------------------------------
// FCM HTTP v1 için OAuth erişim jetonu (service account ile imzalı JWT)
// ---------------------------------------------------------------------
let cachedToken: { value: string; expiresAt: number } | null = null;

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * PEM gövdesini Web Crypto'nun beklediği ham DER'e çevirir.
 *
 * Panele yapıştırılan anahtar çok farklı biçimlerde gelebiliyor: JSON'dan
 * kopyalanınca kaçışlı satır sonlarıyla, terminalden gelince gerçek satır
 * sonlarıyla, bazen baş/sondaki tırnaklarla birlikte. Bu yüzden BEGIN/END
 * satırlarını attıktan sonra base64 alfabesi dışındaki HER karakteri
 * eliyoruz — böylece tüm biçimler tek sonuca iniyor.
 */
function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    // Kaçışları SIRAYLA çöz. Sıra önemli: önce çift kaçışı teke indir,
    // sonra tek kaçışları gerçek satır sonuna çevir. Bunu yapmadan genel
    // filtreye girersek ters bölü atılır ama arkasındaki "n" harfi base64
    // gövdesinde kalıp veriyi bozar — ilk hatanın sebebi tam olarak buydu.
    .replace(/\\\\/g, '\\')
    .replace(/\\r/g, '')
    .replace(/\\n/g, '\n')
    .replace(/-----[A-Z ]+-----/g, '') // BEGIN/END satırları
    .replace(/[^A-Za-z0-9+/=]/g, ''); // tırnak, boşluk, gerçek satır sonu...

  const raw = atob(body);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // 60 sn pay bırakarak önbellekten dön.
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')!;
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')!;

  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64Url(
    JSON.stringify({
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claim}`),
  );
  const jwt = `${header}.${claim}.${base64Url(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`OAuth jetonu alınamadı: ${await response.text()}`);
  }

  const data = await response.json();
  cachedToken = { value: data.access_token, expiresAt: now + data.expires_in };
  return cachedToken.value;
}

// ---------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  try {
    const payload: WebhookPayload = await req.json();

    if (payload.type !== 'INSERT' || payload.table !== 'notifications') {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const row = payload.record;
    if (!row) return new Response(JSON.stringify({ skipped: true }), { status: 200 });

    // service_role: RLS'i aşarak alıcının token'larını okuyabilmek için.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: devices, error } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', row.user_id);

    if (error) throw error;
    if (!devices || devices.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: 'cihaz yok' }), { status: 200 });
    }

    const accessToken = await getAccessToken();
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!;
    const endpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    let sent = 0;
    const staleTokens: string[] = [];
    const errors: string[] = [];

    for (const device of devices) {
      const message = {
        message: {
          token: device.token,
          notification: { title: row.title, body: row.body },
          // Uygulamanın yönlendirme yapabilmesi için ham veriyi de taşı.
          data: {
            notification_id: row.id,
            type: row.type,
            match_id: row.match_id ?? '',
          },
          android: {
            priority: 'HIGH',
            notification: { channel_id: 'japonkale_matches' },
          },
          // iOS: ses ve rozet olmadan bildirim sessiz gelir. `content-available`
          // uygulama kapalıyken de uyandırılmasını sağlar.
          apns: {
            headers: { 'apns-priority': '10' },
            payload: {
              aps: { sound: 'default', badge: 1, 'content-available': 1 },
            },
          },
        },
      };

      const fcmResponse = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      });

      if (fcmResponse.ok) {
        sent++;
      } else {
        const text = await fcmResponse.text();
        // Uygulama silinmiş/token geçersizse tabloyu temizle.
        if (fcmResponse.status === 404 || text.includes('UNREGISTERED')) {
          staleTokens.push(device.token);
        }
        errors.push(`${fcmResponse.status}: ${text.slice(0, 200)}`);
        console.error(`FCM hatası (${fcmResponse.status}): ${text}`);
      }
    }

    if (staleTokens.length > 0) {
      await supabase.from('device_tokens').delete().in('token', staleTokens);
    }

    return new Response(
      JSON.stringify({ sent, removed: staleTokens.length, errors }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
