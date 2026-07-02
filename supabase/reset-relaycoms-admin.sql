-- ============================================================
-- Reset Relaycoms admin (run in Supabase SQL Editor)
-- Use when you re-ran seed-admin and got relaycoms_0, or want a clean re-seed.
--
-- After this, create admin again from your PC:
--   node scripts/seed-admin.mjs relaycoms@gmail.com "YourPassword" relaycoms
-- ============================================================

-- Remove the admin auth user (profile row cascades via FK).
delete from auth.users
where lower(trim(email)) = 'relaycoms@gmail.com'
   or id = 'aadac3ab-857f-4440-b33a-3f7e5e4b8345';

-- Orphan profile usernames from partial / duplicate seeds (no auth user left).
delete from public.profiles p
where lower(p.username) in ('relaycoms', 'relaycoms_0', 'relaycoms_1')
  and not exists (select 1 from auth.users u where u.id = p.id);

-- Keep a single Relaycoms business for the next seed.
insert into public.businesses (name, slug, description)
values ('Relaycoms', 'relaycoms', 'Official Relaycoms support')
on conflict (slug) do update
set name = excluded.name,
    description = excluded.description;

-- Should return 0 rows:
select u.id, u.email, p.username
from auth.users u
left join public.profiles p on p.id = u.id
where lower(coalesce(u.email, '')) = 'relaycoms@gmail.com'
   or lower(coalesce(p.username, '')) in ('relaycoms', 'relaycoms_0');
