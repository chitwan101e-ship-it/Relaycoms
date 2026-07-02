# JBComs

> Customer support & announcements platform — businesses post, customers engage and message.

---

## Tech Stack

| Layer | Tool |
|-------|------|
| Frontend | Next.js 15 (App Router, TypeScript) |
| Styling | Tailwind CSS |
| Backend / DB | Supabase (Postgres + Auth + Realtime) |
| Email / OTP | Resend |
| Deployment | Vercel |

---

## Architecture

### Subdomain routing

Every business gets a subdomain: `slug.jbcoms.com`

```
ht.jbcoms.com        → Business "HT" public page
acmecorp.jbcoms.com  → Business "Acme Corp" public page
jbcoms.com           → Main platform (sign up, feed, dashboard)
```

The `src/middleware.ts` file intercepts subdomain requests and rewrites them to `/business/[slug]/...` — Next.js handles them as normal App Router pages.

### User roles

| Role | Sub-role | Can do |
|------|----------|--------|
| Customer | — | Browse feed, react, comment, message businesses |
| Business | Admin (1 per biz) | Post announcements, manage team, reply to messages |
| Business | Support (max 4) | Reply to customer messages |

---

## Project Structure

```
src/
├── app/
│   ├── (auth)/
│   │   └── signup/page.tsx          # Multi-step sign-up
│   ├── api/
│   │   └── auth/
│   │       ├── send-otp/route.ts    # POST → sends OTP via Resend
│   │       └── register/route.ts   # POST → verifies OTP + creates user
│   ├── business/[slug]/page.tsx     # Business subdomain landing page
│   ├── feed/                        # Customer feed (TODO)
│   ├── dashboard/                   # Business dashboard (TODO)
│   └── page.tsx                     # Root redirect
├── lib/supabase/
│   ├── client.ts                    # Browser client
│   └── server.ts                    # Server client + service-role client
├── middleware.ts                    # Subdomain routing + session refresh
└── types/database.ts                # Full TypeScript types for DB
schema.sql                           # Full DB schema + RLS (run once in Supabase SQL Editor)
supabase/
├── migrations/                      # Incremental history (superseded by schema.sql for fresh DBs)
└── schema.sql                       # Pointer to ../schema.sql
```

---

## Setup

### 1. Clone & install

```bash
git clone https://github.com/you/jbcoms.git
cd jbcoms
npm install
```

### 2. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → New project
2. Open **Database → SQL Editor**
3. Paste & run the entire contents of `schema.sql`
4. Optional: in **Database → Replication**, also enable Realtime for `conversations` and `announcements` (`messages` and `notifications` are added by `schema.sql`)

### 3. Create a Resend account

1. Go to [resend.com](https://resend.com) → Sign up
2. Add your domain `jbcoms.com` and verify DNS records
3. Create an API key

### 4. Configure environment variables

```bash
cp .env.local.example .env.local
```

Fill in `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

RESEND_API_KEY=re_...
RESEND_FROM_EMAIL=noreply@jbcoms.com

NEXT_PUBLIC_ROOT_DOMAIN=jbcoms.com
NEXT_PUBLIC_APP_URL=https://jbcoms.com
```

### 5. Run locally

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

**Testing subdomains locally:**

Add entries to `/etc/hosts`:
```
127.0.0.1  localhost
127.0.0.1  ht.localhost
127.0.0.1  acmecorp.localhost
```

Then visit `http://ht.localhost:3000` — middleware will detect the subdomain.

---

## Deployment (Vercel)

### 1. Deploy to Vercel

```bash
npx vercel --prod
```

Or connect your GitHub repo in the Vercel dashboard.

### 2. Add environment variables

In Vercel project settings → Environment Variables, add all vars from `.env.local`.

### 3. Configure wildcard subdomain

In Vercel project settings → Domains:
1. Add `jbcoms.com` (root domain)
2. Add `*.jbcoms.com` (wildcard — requires Pro plan or higher)

In your DNS provider (Cloudflare recommended):
```
Type  Name   Value
A     @      76.76.21.21      (Vercel IP)
CNAME *      cname.vercel-dns.com
```

### 4. Update Supabase Auth

In Supabase → Authentication → URL Configuration:
- Site URL: `https://jbcoms.com`
- Redirect URLs: `https://jbcoms.com/**`, `https://*.jbcoms.com/**`

---

## Next features to build

- [ ] `/feed` — Customer home feed (all followed businesses' announcements)
- [ ] `/dashboard` — Business admin dashboard (post announcements, manage team)
- [ ] `/dashboard/inbox` — Support agent conversation queue
- [ ] `/messages/[conversationId]` — Real-time chat (Supabase Realtime)
- [ ] `/login` — Sign in page
- [ ] Profile & avatar upload (Supabase Storage)
- [ ] Push notifications (web push or email via Resend)

---

## Database Schema Summary

```
businesses        — slug (subdomain), name, description
profiles          — extends auth.users; role, business_id, business_role
otp_tokens        — hashed OTPs with expiry (managed via service role)
announcements     — business posts; only admin can insert (RLS)
reactions         — like/helpful/love/question per announcement per user
comments          — on announcements
conversations     — customer ↔ business thread (unique per pair)
messages          — real-time messages within a conversation
follows           — customer follows a business
```

All tables have Row Level Security (RLS) enabled. See `schema.sql` for full policy definitions.
