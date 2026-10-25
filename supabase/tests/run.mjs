// Tum migration'lari Supabase taklitli bir PGlite uzerinde calistirir,
// sonra testler.sql'deki senaryolari kosar.
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import fs from 'node:fs';
import path from 'node:path';

const repo = process.argv[2];
const testsFile = process.argv[3];
const db = new PGlite({ extensions: { pgcrypto } });

const stubs = `
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  phone text,
  raw_user_meta_data jsonb default '{}'::jsonb,
  raw_app_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create function auth.role() returns text language sql stable as
  $$ select current_setting('request.jwt.claim.role', true) $$;
create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;
grant usage on schema auth to anon, authenticated, service_role;
create schema extensions;
create schema cron;
create function cron.schedule(text, text, text) returns bigint language sql as 'select 1::bigint';
create function cron.unschedule(text) returns boolean language sql as 'select true';
create schema net;
create function net.http_post(url text, headers jsonb default '{}', body jsonb default '{}') returns bigint language sql as 'select 1::bigint';
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid default gen_random_uuid(), bucket_id text, name text, owner uuid);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql as
  $$ select string_to_array(name, '/') $$;
create publication supabase_realtime;
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`;

async function run(label, sql) {
  try {
    await db.exec(sql);
    console.log('OK   ', label);
    return true;
  } catch (e) {
    console.log('FAIL ', label, '->', e.message, e.where ? `\n      where: ${e.where}` : '');
    return false;
  }
}

await run('stubs', stubs);
const dir = path.join(repo, 'supabase', 'migrations');
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.sql')).sort()) {
  const ok = await run(f, fs.readFileSync(path.join(dir, f), 'utf8').replace(/create extension if not exists "pg_(cron|net)";/g, ''));
  if (!ok) process.exit(1);
}

if (testsFile) {
  // Testler "-- TEST: ad" satirlariyla ayrilir. "-- EXPECT ERROR: metin"
  // iceren test hata vermeli (metni icermeli); digerleri hatasiz bitmeli.
  const parts = fs.readFileSync(testsFile, 'utf8').split(/^-- TEST: /m);
  if (!(await run('test setup', parts[0]))) process.exit(1);
  await db.exec('reset role;');
  const blocks = parts.slice(1);
  let failed = 0;
  for (const block of blocks) {
    const name = block.split('\n')[0].trim();
    const expect = (block.match(/^-- EXPECT ERROR: (.*)$/m) || [])[1];
    try {
      await db.exec('begin;');
      const res = await db.exec('-- ' + block);
      await db.exec('rollback;').catch(() => {});
      if (expect) {
        failed++;
        console.log('FAIL ', name, '-> hata bekleniyordu:', expect);
      } else {
        const last = res[res.length - 1];
        const rows = last && last.rows && last.rows.length ? JSON.stringify(last.rows) : '';
        if (rows.includes('"ok":false')) {
          failed++;
          console.log('FAIL ', name, rows);
        } else console.log('PASS ', name, rows.slice(0, 160));
      }
    } catch (e) {
      await db.exec('rollback;').catch(() => {});
      if (expect && !/syntax error/i.test(e.message) && e.message.toLowerCase().includes(expect.toLowerCase())) {
        console.log('PASS ', name, '(beklenen hata:', e.message + ')');
      } else {
        failed++;
        console.log('FAIL ', name, '->', e.message);
      }
    }
  }
  console.log(failed ? `\n${failed} test BASARISIZ` : '\nTum testler gecti');
  process.exit(failed ? 1 : 0);
}
