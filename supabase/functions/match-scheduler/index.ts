// =====================================================================
// Alternatif / tamamlayici kurgu: Supabase Edge Function
// ---------------------------------------------------------------------
// pg_cron kullanmak istemiyorsan (veya push bildirimi de gondermek
// istiyorsan) bu fonksiyonu bir cron ile tetikle:
//
//   supabase functions deploy match-scheduler --no-verify-jwt
//   -- ve pg_cron'dan pg_net ile cagir (asagida SQL ornegi) ya da
//   -- GitHub Actions / cron-job.org gibi harici bir zamanlayici kullan.
//
// pg_cron -> Edge Function tetikleme ornegi (SQL Editor'de calistir):
//   select cron.schedule(
//     'halisaha-edge-scheduler', '*/15 * * * *',
//     $$
--     select net.http_post(
--       url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/match-scheduler',
--       headers := jsonb_build_object(
--                    'Content-Type','application/json',
--                    'Authorization','Bearer <SERVICE_ROLE_KEY>')
--     );
//     $$
//   );
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  // Sadece service_role ile cagrilabilsin
  const auth = req.headers.get("Authorization") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  if (auth !== `Bearer ${serviceKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey);

  // 1) 1 hafta icinde karsilikli onaylanmayan maclari otomatik iptal et
  const { data: cancelled, error: cancelErr } = await supabase.rpc(
    "auto_cancel_stale_matches",
  );

  // 2) Mac saatinden 1 saat sonra "Mac nasil sonlandi?" bildirimi
  const { data: prompted, error: promptErr } = await supabase.rpc(
    "send_match_result_prompts",
  );

  // 3) (Opsiyonel) Burada olusan yeni notifications kayitlarini okuyup
  //    FCM / OneSignal uzerinden push bildirimi de gonderebilirsin.
  //    Ornek: profiles tablosuna bir `fcm_token` kolonu ekleyip
  //    okunmamis 'match_result_request' bildirimlerini push'la.

  const error = cancelErr ?? promptErr;
  return new Response(
    JSON.stringify({
      auto_cancelled: cancelled ?? 0,
      result_prompts_sent: prompted ?? 0,
      error: error?.message ?? null,
    }),
    {
      status: error ? 500 : 200,
      headers: { "Content-Type": "application/json" },
    },
  );
});
