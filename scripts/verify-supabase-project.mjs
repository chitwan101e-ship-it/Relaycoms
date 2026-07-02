/**
 * Check which Supabase project .env.local points to and whether admin data exists.
 * Usage: node scripts/verify-supabase-project.mjs
 */
import { createClient } from '@supabase/supabase-js'
import { readFileSync, existsSync } from 'fs'
import { resolve } from 'path'

function loadEnvLocal() {
  const p = resolve(process.cwd(), '.env.local')
  if (!existsSync(p)) return
  for (const line of readFileSync(p, 'utf8').split('\n')) {
    const t = line.trim()
    if (!t || t.startsWith('#')) continue
    const eq = t.indexOf('=')
    if (eq === -1) continue
    const key = t.slice(0, eq).trim()
    let val = t.slice(eq + 1).trim()
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1)
    }
    const force = key === 'NEXT_PUBLIC_SUPABASE_URL' || key === 'SUPABASE_SERVICE_ROLE_KEY'
    if (force || process.env[key] === undefined) process.env[key] = val
  }
}

function jwtRef(token) {
  try {
    const payload = token.split('.')[1]
    const json = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'))
    return json.ref ?? null
  } catch {
    return null
  }
}

// Drop stale shell env so .env.local is the only source for Supabase keys.
delete process.env.NEXT_PUBLIC_SUPABASE_URL
delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
delete process.env.SUPABASE_SERVICE_ROLE_KEY

loadEnvLocal()

const url = process.env.NEXT_PUBLIC_SUPABASE_URL
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!url || !serviceKey?.trim()) {
  console.error('Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env.local')
  process.exit(1)
}

const ref = jwtRef(serviceKey)
console.log('ENV URL:', url)
console.log('JWT project ref:', ref)
console.log('URL matches JWT ref:', url.includes(ref ?? '___'))

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const { data: users, error: uErr } = await admin.auth.admin.listUsers({ perPage: 20 })
if (uErr) {
  console.error('listUsers failed:', uErr.message)
  process.exit(1)
}

console.log('Auth users (first 20):', users.users.length)
for (const u of users.users) {
  console.log(' -', u.id, u.email)
}

const { count: bizCount, error: bErr } = await admin
  .from('businesses')
  .select('*', { count: 'exact', head: true })
if (bErr) console.error('businesses error:', bErr.message)
else console.log('Businesses count:', bizCount)

const { count: profCount, error: pErr } = await admin
  .from('profiles')
  .select('*', { count: 'exact', head: true })
if (pErr) console.error('profiles error:', pErr.message)
else console.log('Profiles count:', profCount)

const hit = users.users.find((u) => (u.email || '').toLowerCase() === 'relaycoms@gmail.com')
console.log('relaycoms@gmail.com present:', Boolean(hit))
