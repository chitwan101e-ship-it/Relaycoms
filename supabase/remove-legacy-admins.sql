-- ============================================================
-- Relaycoms — remove legacy admin / staff accounts (JBComs / Juwa / Vatican era)
-- Run in Supabase SQL Editor AFTER schema.sql on a new project.
-- Does NOT create your new admin (passwords belong in Auth API, not SQL).
--
-- After this file succeeds, create the new admin from your machine:
--   node scripts/seed-admin.mjs your@email.com "your-new-password"
-- Or set SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD in .env.local and run:
--   node scripts/seed-admin.mjs
-- ============================================================

-- Known legacy auth user id from the old project (safe to delete if present).
delete from auth.users
where id = '5f6a22b8-88ee-4d77-867f-b82ee35b462b';

-- Legacy login emails (old business admins).
delete from auth.users
where lower(trim(email)) in (
  'juwabros@gmail.com',
  'vaticanbros@gmail.com'
);

-- Synthetic staff inboxes from the old relay-staff.jbcoms domain.
delete from auth.users
where lower(trim(email)) like '%@relay-staff.jbcoms';

-- Any remaining business staff tied to old brand usernames.
delete from auth.users
where id in (
  select p.id
  from public.profiles p
  where lower(p.username) in (
    'juwabros',
    'juwa-bros',
    'juwabro',
    'vaticanbros',
    'vatican-bros',
    'jbcoms',
    'jbcomsadmin'
  )
);

-- Old demo / duplicate businesses (cascades conversations, announcements, etc.).
delete from public.businesses
where slug in (
  'juwa-bros',
  'juwabros',
  'vatican-bros',
  'vaticanbros',
  'jbcoms'
);

-- Ensure the Relaycoms business row exists for the new admin seed script.
insert into public.businesses (name, slug, description)
values (
  'Relaycoms',
  'relaycoms',
  'Official Relaycoms support'
)
on conflict (slug) do update
set name = excluded.name,
    description = excluded.description;
