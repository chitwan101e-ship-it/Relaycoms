-- ============================================================
-- Relaycoms — post-cleanup checks (optional)
-- Run AFTER remove-legacy-admins.sql if you want to verify state.
--
-- This file does NOT set passwords. Supabase stores auth passwords hashed
-- in auth.users; use the Node seed script instead:
--
--   node scripts/seed-admin.mjs admin@relaycoms.com "YourSecurePassword"
--
-- Optional .env.local (not committed):
--   SEED_ADMIN_EMAIL=admin@relaycoms.com
--   SEED_ADMIN_PASSWORD=YourSecurePassword
--   SEED_BUSINESS_SLUG=relaycoms
--   SEED_BUSINESS_NAME=Relaycoms
-- ============================================================

-- Business row (idempotent; same as remove-legacy-admins.sql tail).
insert into public.businesses (name, slug, description)
values (
  'Relaycoms',
  'relaycoms',
  'Official Relaycoms support'
)
on conflict (slug) do update
set name = excluded.name,
    description = excluded.description;

-- Sanity check: no legacy admins left.
select
  u.id,
  u.email,
  p.username,
  p.role,
  p.business_role,
  b.slug as business_slug
from auth.users u
left join public.profiles p on p.id = u.id
left join public.businesses b on b.id = p.business_id
where lower(coalesce(u.email, '')) in ('juwabros@gmail.com', 'vaticanbros@gmail.com')
   or lower(coalesce(p.username, '')) in ('juwabros', 'juwa-bros', 'vaticanbros', 'vatican-bros')
   or u.id = '5f6a22b8-88ee-4d77-867f-b82ee35b462b';
-- Expect 0 rows. If any appear, re-run remove-legacy-admins.sql.

select id, name, slug from public.businesses where slug = 'relaycoms';
-- Expect one Relaycoms row.
