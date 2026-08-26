# Halısaha App — Supabase Veritabanı

## Kurulum

1. Supabase Dashboard → **Database → Extensions**: `pgcrypto`, `pg_cron`, `pg_net` aktif et.
2. **SQL Editor**'de `migrations/20260826000000_init_schema.sql` dosyasını çalıştır.
   (Supabase CLI kullanıyorsan: `supabase db push`)
3. Edge Function alternatifi için: `supabase functions deploy match-scheduler --no-verify-jwt`

> `pg_cron` sadece `postgres` veritabanında çalışır ve superuser gerektirir.
> Eğer Bölüm 7'deki `cron.schedule` satırları hata verirse, önce eklentiyi
> Dashboard'dan aktif edip yalnızca o bölümü tekrar çalıştır.

## Maç akışı (status makinesi)

```
pending ──kabul──► accepted ──iki taraf da confirm──► mutually_agreed
   │                  │                                     │
   │reddet            │7 gün doldu                          │A gün/saat girer
   ▼                  ▼                                     ▼
rejected         auto_cancelled                         scheduled
                                                            │ A sonucu girer
                                                            ▼
                                                        completed  → G/B/M trigger
```

Her aşamadan `cancelled`'a manuel iptal mümkündür.

## İstemci tarafı kullanım (RPC)

```dart
// 1. Kayıt — profil trigger ile otomatik oluşur
await supabase.auth.signUp(
  email: 'a@b.com', password: '...',
  data: {
    'first_name': 'Barış', 'last_name': 'Tanlık',
    'birth_date': '1995-04-12', 'phone': '+905321112233',
  },
);

// 2. Ana sayfa — en popüler 3 saha
await supabase.rpc('get_popular_pitches', params: {'p_limit': 3});

// 3. Meydan oku
await supabase.rpc('challenge_team', params: {
  'p_challenger_team_id': myTeamId,
  'p_opponent_team_id': rivalTeamId,
  'p_message': 'Cumartesi 21:00 uygun mu?',
});

// 4. Rakip kabul/red
await supabase.rpc('respond_to_challenge', params: {'p_match_id': id, 'p_accept': true});

// 5. "Maç Kabulü" (iki taraf da basar → mutually_agreed)
await supabase.rpc('confirm_match', params: {'p_match_id': id});

// 6. Rakip iletişim bilgisi (yalnızca kabul sonrası)
await supabase.rpc('get_opponent_contact', params: {'p_match_id': id});

// 7. A takımı gün/saat girer
await supabase.rpc('schedule_match', params: {
  'p_match_id': id, 'p_match_date': '2026-09-05T21:00:00+03:00',
});

// 8. Sonuç: 'won' | 'draw' | 'lost'  → G/B/M otomatik güncellenir
await supabase.rpc('report_match_result', params: {'p_match_id': id, 'p_outcome': 'won'});

// 9. Maç geçmişi (en yeniden eskiye)
await supabase.rpc('get_team_match_history', params: {'p_team_id': myTeamId});

// 10. Kaleci puanlama (1-5, upsert)
await supabase.rpc('rate_goalkeeper', params: {'p_goalkeeper_id': gkId, 'p_rating': 5});
```

## Hazır view'lar

| View | Kullanım |
|---|---|
| `pitches_with_team_count` | Saha listesi + kayıtlı takım sayısı |
| `teams_with_stats` | G/B/M + oynanan, puan, galibiyet yüzdesi |
| `goalkeeper_profiles` | Kaleci listesi (isim, yaş, ortalama puan) |
| `profiles_with_age` | Profil + doğum tarihinden hesaplanan yaş |

## Realtime

`notifications` ve `matches` tabloları `supabase_realtime` publication'ına eklidir:

```dart
supabase.channel('notif')
  .onPostgresChanges(
     event: PostgresChangeEvent.insert, schema: 'public', table: 'notifications',
     filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
     callback: (payload) { /* bildirim göster */ })
  .subscribe();
```
