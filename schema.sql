-- ============================================================
-- Relaycoms full Supabase schema — run once on brand-new database in SQL Editor.
-- For reset use supabase/migrations/000_reset_app_schema.sql first.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1. BUSINESSES
-- ------------------------------------------------------------
create table public.businesses (
  id            uuid primary key default uuid_generate_v4(),
  name          text not null,
  slug          text not null unique,
  description   text,
  logo_url      text,
  created_at    timestamptz default now()
);

create index idx_businesses_slug on public.businesses(slug);

-- ------------------------------------------------------------
-- 2. PROFILES (extends Supabase auth.users 1-to-1)
-- ------------------------------------------------------------
create type public.user_role as enum ('customer', 'business');
create type public.business_role as enum ('admin', 'support');
create type public.account_status as enum ('pending', 'approved', 'rejected', 'blocked', 'suspended');

create table public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  username           text not null unique,
  first_name         text not null,
  last_name          text not null,
  phone              text,
  phone_normalized   text,
  referral_username  text,
  signup_question    text,
  avatar_url         text,
  role               public.user_role not null default 'customer',
  business_id        uuid references public.businesses(id) on delete set null,
  business_role      public.business_role,
  account_status     public.account_status not null default 'pending',
  email_verified     boolean default false,
  deleted_at         timestamptz,
  deleted_by         uuid references auth.users(id) on delete set null,
  created_at         timestamptz default now(),
  constraint business_role_requires_business
    check (
      (role = 'business' and business_id is not null and business_role is not null)
      or role = 'customer'
    )
);

comment on column public.profiles.phone_normalized is 'Digits-only key for duplicate-phone prevention; derived from public.profiles.phone.';
comment on column public.profiles.referral_username is 'Optional @username the customer entered as referrer (not validated as FK).';
comment on column public.profiles.signup_question is 'Optional question the customer entered during signup for staff review.';

create index idx_profiles_business on public.profiles(business_id);
create index idx_profiles_username on public.profiles(username);
create index idx_profiles_status on public.profiles(account_status);
create index idx_profiles_not_deleted on public.profiles (id) where deleted_at is null;

create unique index idx_profiles_phone_norm_active
  on public.profiles (phone_normalized)
  where phone_normalized is not null
    and deleted_at is null
    and account_status in ('pending', 'approved', 'suspended', 'blocked');

create index idx_profiles_phone_norm_lookup
  on public.profiles (phone_normalized)
  where phone_normalized is not null and deleted_at is null;

create index idx_profiles_pending_customers
  on public.profiles (created_at desc)
  where role = 'customer'
    and account_status = 'pending'
    and deleted_at is null;

create index idx_profiles_business_admins
  on public.profiles (business_id)
  where role = 'business'
    and business_role = 'admin'
    and deleted_at is null;

create table public.signup_phone_attempts (
  id uuid primary key default gen_random_uuid(),
  phone_normalized text,
  attempted_email text,
  attempted_username text,
  blocked boolean not null default false,
  block_reason text,
  client_ip text,
  user_agent text,
  created_at timestamptz not null default now()
);

create index idx_signup_phone_attempts_phone_created
  on public.signup_phone_attempts (phone_normalized, created_at desc);

alter table public.signup_phone_attempts enable row level security;

-- ------------------------------------------------------------
-- 3. OTP TOKENS (email verification via Resend)
-- ------------------------------------------------------------
create table public.otp_tokens (
  id          uuid primary key default uuid_generate_v4(),
  email       text not null,
  token       text not null,
  expires_at  timestamptz not null,
  used        boolean default false,
  verified_at timestamptz,
  purpose     text not null default 'signup' check (purpose in ('signup', 'password_reset')),
  created_at  timestamptz default now()
);

create index idx_otp_email on public.otp_tokens(email);
create index idx_otp_tokens_email_purpose_active on public.otp_tokens (email, purpose) where used = false;
create index idx_otp_tokens_signup_verified on public.otp_tokens (email, purpose) where used = false and verified_at is not null;

create or replace function public.relay_auth_user_id_for_email(p_email text)
returns uuid
language sql
security definer
set search_path = auth
stable
as $$
  select u.id
  from auth.users u
  where lower(trim(u.email::text)) = lower(trim(p_email))
  limit 1;
$$;

revoke all on function public.relay_auth_user_id_for_email(text) from public;
grant execute on function public.relay_auth_user_id_for_email(text) to service_role;

-- ------------------------------------------------------------
-- 4. ANNOUNCEMENTS
-- ------------------------------------------------------------
create table public.announcements (
  id          uuid primary key default uuid_generate_v4(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  author_id   uuid not null references public.profiles(id) on delete cascade,
  title       text not null,
  body        text not null,
  image_url   text,
  pinned      boolean default false,
  hidden_at   timestamptz,
  deleted_at  timestamptz,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create index idx_announcements_business on public.announcements(business_id);
create index idx_announcements_created on public.announcements(created_at desc);
create index idx_announcements_feed_visible
  on public.announcements (business_id, created_at desc)
  where deleted_at is null and hidden_at is null;

-- ------------------------------------------------------------
-- 5. REACTIONS
-- ------------------------------------------------------------
create type public.reaction_type as enum ('like', 'helpful', 'love', 'question');

create table public.reactions (
  id              uuid primary key default uuid_generate_v4(),
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  reaction        public.reaction_type not null default 'like',
  created_at      timestamptz default now(),
  unique (announcement_id, user_id)
);

-- ------------------------------------------------------------
-- 6. COMMENTS
-- ------------------------------------------------------------
create table public.comments (
  id                uuid primary key default uuid_generate_v4(),
  announcement_id   uuid not null references public.announcements(id) on delete cascade,
  user_id           uuid not null references public.profiles(id) on delete cascade,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  body              text not null,
  hidden_at         timestamptz,
  deleted_at        timestamptz,
  created_at        timestamptz default now()
);

create index idx_comments_announcement on public.comments(announcement_id);
create index idx_comments_parent on public.comments(parent_comment_id) where parent_comment_id is not null;
create index idx_comments_feed_visible
  on public.comments (announcement_id, created_at)
  where deleted_at is null and hidden_at is null;

create or replace function public.comments_validate_parent()
returns trigger
language plpgsql
as $$
begin
  if new.parent_comment_id is null then
    return new;
  end if;
  if not exists (
    select 1
    from public.comments p
    where p.id = new.parent_comment_id
      and p.announcement_id = new.announcement_id
  ) then
    raise exception 'parent comment must belong to the same announcement';
  end if;
  return new;
end;
$$;

create trigger comments_validate_parent
  before insert or update of parent_comment_id, announcement_id on public.comments
  for each row
  execute function public.comments_validate_parent();

-- ------------------------------------------------------------
-- 7. CONVERSATIONS
-- ------------------------------------------------------------
create table public.conversations (
  id          uuid primary key default uuid_generate_v4(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  assigned_to uuid references public.profiles(id) on delete set null,
  status      text not null default 'open',
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  unique (business_id, customer_id)
);

create index idx_conversations_business on public.conversations(business_id);
create index idx_conversations_customer on public.conversations(customer_id);
create index idx_conversations_assigned on public.conversations(assigned_to);

-- ------------------------------------------------------------
-- 8. MESSAGES
-- ------------------------------------------------------------
create table public.messages (
  id                  uuid primary key default uuid_generate_v4(),
  conversation_id     uuid not null references public.conversations(id) on delete cascade,
  sender_id           uuid not null references public.profiles(id) on delete cascade,
  body                text not null,
  image_url           text,
  read                boolean default false,
  read_at             timestamptz,
  reply_to_message_id uuid references public.messages(id) on delete set null,
  created_at          timestamptz default now()
);

create index idx_messages_conversation on public.messages(conversation_id);
create index idx_messages_created on public.messages(created_at asc);
create index idx_messages_reply_to on public.messages(reply_to_message_id)
  where reply_to_message_id is not null;

create or replace function public.messages_validate_reply_to()
returns trigger
language plpgsql
as $$
begin
  if new.reply_to_message_id is null then
    return new;
  end if;
  if not exists (
    select 1
    from public.messages parent
    where parent.id = new.reply_to_message_id
      and parent.conversation_id = new.conversation_id
  ) then
    raise exception 'reply target must belong to the same conversation';
  end if;
  return new;
end;
$$;

create trigger messages_validate_reply_to
  before insert or update of reply_to_message_id, conversation_id on public.messages
  for each row
  execute function public.messages_validate_reply_to();

-- ------------------------------------------------------------
-- 9. NOTIFICATIONS
-- ------------------------------------------------------------
create table public.notifications (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  business_id     uuid references public.businesses(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  type            text not null default 'announcement',
  title           text not null,
  body            text not null,
  link            text,
  read            boolean not null default false,
  created_at      timestamptz default now()
);

create index idx_notifications_user_created on public.notifications(user_id, created_at desc);
create index idx_notifications_user_unread on public.notifications(user_id, read);
create index idx_notifications_user_conversation_unread
  on public.notifications(user_id, conversation_id)
  where read = false;

-- ------------------------------------------------------------
-- 10. INBOX LABELS
-- ------------------------------------------------------------
create table public.inbox_label_definitions (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  color text,
  is_system boolean not null default false,
  preset_key text,
  created_at timestamptz not null default now(),
  constraint inbox_label_name_nonempty check (char_length(trim(name)) between 1 and 48)
);

create unique index inbox_label_defs_business_name_lower
  on public.inbox_label_definitions (business_id, lower(trim(name)));

create unique index inbox_label_defs_business_preset
  on public.inbox_label_definitions (business_id, preset_key)
  where preset_key is not null;

create index idx_inbox_label_defs_business on public.inbox_label_definitions (business_id);

create table public.conversation_inbox_labels (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  label_id uuid not null references public.inbox_label_definitions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (conversation_id, label_id)
);

create index idx_conversation_inbox_labels_label on public.conversation_inbox_labels (label_id);

create or replace function public.conversation_inbox_labels_same_business()
returns trigger
language plpgsql
as $$
declare
  conv_bid uuid;
  lbl_bid uuid;
begin
  select c.business_id into conv_bid from public.conversations c where c.id = new.conversation_id;
  select d.business_id into lbl_bid from public.inbox_label_definitions d where d.id = new.label_id;
  if conv_bid is null then
    raise exception 'conversation not found';
  end if;
  if lbl_bid is null then
    raise exception 'label not found';
  end if;
  if conv_bid <> lbl_bid then
    raise exception 'label and conversation must belong to the same business';
  end if;
  return new;
end;
$$;

create trigger conversation_inbox_labels_same_business
  before insert or update of conversation_id, label_id on public.conversation_inbox_labels
  for each row
  execute function public.conversation_inbox_labels_same_business();

create or replace function public.seed_inbox_preset_labels_for_business()
returns trigger
language plpgsql
as $$
begin
  insert into public.inbox_label_definitions (business_id, name, color, is_system, preset_key)
  select new.id, x.name, x.color, true, x.preset_key
  from (
    values
      ('vip', 'VIP', '#ca8a04'),
      ('priority', 'Priority', '#ea580c'),
      ('scammer', 'Scammer', '#dc2626'),
      ('follow_up', 'Follow up', '#2563eb'),
      ('newly_approved', 'Newly approved', '#6366f1'),
      ('account_created', 'Account created', '#64748b'),
      ('active_player', 'Active player', '#16a34a')
  ) as x(preset_key, name, color)
  where not exists (
    select 1 from public.inbox_label_definitions d
    where d.business_id = new.id and d.preset_key = x.preset_key
  );
  return new;
end;
$$;

-- ------------------------------------------------------------
-- 11. INBOX CANNED REPLIES
-- ------------------------------------------------------------
create table public.inbox_canned_replies (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  title text not null,
  body text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inbox_canned_title_len check (char_length(trim(title)) between 1 and 100),
  constraint inbox_canned_body_len check (char_length(body) between 1 and 8000)
);

create index idx_inbox_canned_replies_business on public.inbox_canned_replies (business_id, sort_order, title);

-- ------------------------------------------------------------
-- 12. FOLLOWS
-- ------------------------------------------------------------
create table public.follows (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  created_at  timestamptz default now(),
  primary key (user_id, business_id)
);

-- ------------------------------------------------------------
-- 13. ADMIN REPORTS
-- ------------------------------------------------------------
create type public.admin_report_status as enum ('new', 'in_review', 'resolved');

create table public.admin_reports (
  id            uuid primary key default uuid_generate_v4(),
  business_id   uuid not null references public.businesses(id) on delete cascade,
  reporter_id   uuid references public.profiles(id) on delete set null,
  reporter_name text not null,
  category      text not null,
  details       text not null,
  status        public.admin_report_status not null default 'new',
  assigned_to   uuid references public.profiles(id) on delete set null,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index idx_admin_reports_business on public.admin_reports(business_id);
create index idx_admin_reports_status on public.admin_reports(status);

-- ------------------------------------------------------------
-- 14. MODERATION SUSPENSION EVENTS
-- ------------------------------------------------------------
create table public.moderation_suspension_events (
  id          uuid primary key default uuid_generate_v4(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete set null,
  actor_id    uuid not null,
  action      text not null check (action in ('suspend', 'unsuspend')),
  reason      text,
  created_at  timestamptz not null default now()
);

create index idx_moderation_suspension_profile on public.moderation_suspension_events (profile_id);
create index idx_moderation_suspension_created on public.moderation_suspension_events (created_at desc);

comment on table public.moderation_suspension_events is
  'Audit log for staff suspend/unsuspend actions. Hidden from regular clients via RLS.';

-- ------------------------------------------------------------
-- 15. DELETED USERS AUDIT
-- ------------------------------------------------------------
create table public.deleted_users_audit (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null,
  auth_user_id uuid not null,
  business_id uuid references public.businesses(id) on delete set null,
  username text,
  reason text,
  deleted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

create index idx_deleted_users_audit_profile on public.deleted_users_audit(profile_id);
create index idx_deleted_users_audit_created on public.deleted_users_audit(created_at desc);

-- ------------------------------------------------------------
-- 16. HELPER FUNCTIONS
-- ------------------------------------------------------------
create or replace function public.my_profile()
returns public.profiles
language sql security definer stable
as $$
  select * from public.profiles where id = auth.uid();
$$;

create or replace function public.is_business_admin(bid uuid)
returns boolean
language sql security definer stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and business_id = bid
      and business_role = 'admin'
  );
$$;

create or replace function public.is_business_member(bid uuid)
returns boolean
language sql security definer stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and business_id = bid
      and role = 'business'
  );
$$;

create or replace function public.is_approved_user()
returns boolean
language sql security definer stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and account_status = 'approved'
  );
$$;

create or replace function public.is_business_user()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role = 'business'
      and business_id is not null
  );
$$;

create or replace function public.promote_user_to_business_admin(
  user_email text,
  target_business_slug text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user_id uuid;
  target_business_id uuid;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only service role can call promote_user_to_business_admin';
  end if;

  select id into target_user_id
  from auth.users
  where lower(email) = lower(user_email)
  limit 1;

  if target_user_id is null then
    raise exception 'User not found for email: %', user_email;
  end if;

  select id into target_business_id
  from public.businesses
  where slug = target_business_slug
  limit 1;

  if target_business_id is null then
    raise exception 'Business not found for slug: %', target_business_slug;
  end if;

  update public.profiles
  set role = 'business',
      business_id = target_business_id,
      business_role = 'admin',
      account_status = 'approved'
  where id = target_user_id;

  if not found then
    raise exception 'Profile row not found for user: %', user_email;
  end if;

  return target_user_id;
end;
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.touch_conversation_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set updated_at = now()
  where id = new.conversation_id;
  return new;
end;
$$;

create or replace function public.notify_staff_on_customer_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  staff record;
  customer record;
  preview text;
  popup_title text;
begin
  select * into c from public.conversations where id = new.conversation_id;
  if c.id is null then
    return new;
  end if;
  if new.sender_id <> c.customer_id then
    return new;
  end if;

  preview := left(trim(new.body), 160);
  if preview is null or preview = '' then
    preview := '📷 Message';
  end if;

  select first_name, username into customer
  from public.profiles
  where id = c.customer_id;

  popup_title := coalesce(
    nullif(trim(customer.first_name), ''),
    nullif(trim(customer.username), ''),
    'Customer'
  ) || ' message';

  for staff in
    select id
    from public.profiles
    where business_id = c.business_id
      and role = 'business'
      and deleted_at is null
  loop
    insert into public.notifications (user_id, business_id, type, title, body, link, conversation_id)
    values (
      staff.id,
      c.business_id,
      'support_message',
      popup_title,
      preview,
      '/dashboard',
      c.id
    );
  end loop;

  return new;
end;
$$;

create or replace function public.mark_customer_messages_read_for_staff(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_business_id uuid;
  n int;
begin
  select c.customer_id, c.business_id
  into v_customer_id, v_business_id
  from public.conversations c
  where c.id = p_conversation_id;

  if v_customer_id is null or v_business_id is null then
    return 0;
  end if;

  if not public.is_business_member(v_business_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  update public.messages m
  set read = true,
      read_at = now()
  where m.conversation_id = p_conversation_id
    and m.sender_id = v_customer_id
    and m.read is distinct from true;

  get diagnostics n = row_count;
  return coalesce(n, 0);
end;
$$;

revoke all on function public.mark_customer_messages_read_for_staff(uuid) from public;
grant execute on function public.mark_customer_messages_read_for_staff(uuid) to authenticated;

create or replace function public.mark_staff_messages_read_for_customer(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_business_id uuid;
  n int;
begin
  select c.customer_id, c.business_id
  into v_customer_id, v_business_id
  from public.conversations c
  where c.id = p_conversation_id;

  if v_customer_id is null or auth.uid() is distinct from v_customer_id then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  update public.messages m
  set read = true,
      read_at = now()
  where m.conversation_id = p_conversation_id
    and m.sender_id is distinct from v_customer_id
    and m.read is distinct from true;

  get diagnostics n = row_count;
  return coalesce(n, 0);
end;
$$;

revoke all on function public.mark_staff_messages_read_for_customer(uuid) from public;
grant execute on function public.mark_staff_messages_read_for_customer(uuid) to authenticated;

create or replace function public.inbox_latest_previews(p_conversation_ids uuid[])
returns table(conversation_id uuid, body text, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select distinct on (m.conversation_id) m.conversation_id, m.body, m.created_at
  from public.messages m
  inner join public.conversations c on c.id = m.conversation_id
  where m.conversation_id = any(p_conversation_ids)
    and public.is_business_member(c.business_id)
  order by m.conversation_id, m.created_at desc;
$$;

revoke all on function public.inbox_latest_previews(uuid[]) from public;
grant execute on function public.inbox_latest_previews(uuid[]) to authenticated;

-- ------------------------------------------------------------
-- 17. ROW LEVEL SECURITY
-- ------------------------------------------------------------
alter table public.businesses enable row level security;
alter table public.profiles enable row level security;
alter table public.otp_tokens enable row level security;
alter table public.announcements enable row level security;
alter table public.reactions enable row level security;
alter table public.comments enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.inbox_label_definitions enable row level security;
alter table public.conversation_inbox_labels enable row level security;
alter table public.inbox_canned_replies enable row level security;
alter table public.follows enable row level security;
alter table public.admin_reports enable row level security;
alter table public.moderation_suspension_events enable row level security;
alter table public.deleted_users_audit enable row level security;

create policy "businesses_read" on public.businesses for select using (true);
create policy "businesses_insert" on public.businesses for insert with check (false);
create policy "businesses_update_admin"
  on public.businesses for update
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.business_id = businesses.id
        and p.business_role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.business_id = businesses.id
        and p.business_role = 'admin'
    )
  );

grant update on table public.businesses to authenticated;

create policy "profiles_select_own" on public.profiles for select using (id = auth.uid());
create policy "profiles_select_business_team" on public.profiles for select
  using (role = 'business' and business_id is not null and public.is_business_member(business_id));
create policy "profiles_select_business_customers" on public.profiles for select
  using (
    role = 'customer'
    and account_status in ('approved', 'suspended')
    and deleted_at is null
    and (
      exists (
        select 1 from public.conversations c
        where c.customer_id = profiles.id and public.is_business_member(c.business_id)
      )
      or exists (
        select 1 from public.follows f
        where f.user_id = profiles.id and public.is_business_member(f.business_id)
      )
    )
  );
create policy "profiles_select_business_broadcast" on public.profiles for select
  using (
    role = 'customer' and account_status = 'approved' and deleted_at is null and public.is_business_user()
  );
create policy "profiles_select_display" on public.profiles for select
  using (
    auth.uid() is not null
    and deleted_at is null
    and (role = 'business' or (role = 'customer' and account_status = 'approved'))
  );
create policy "profiles_update_avatar_own" on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

revoke all on table public.profiles from anon;
revoke update on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
revoke select (phone, phone_normalized) on table public.profiles from authenticated;
grant update (avatar_url) on table public.profiles to authenticated;

create policy "otp_none" on public.otp_tokens for all using (false);

create policy "announce_read" on public.announcements for select using (
  public.is_business_member(business_id)
  or (deleted_at is null and hidden_at is null)
);
create policy "announce_insert" on public.announcements for insert
  with check (public.is_business_member(business_id));
create policy "announce_update" on public.announcements for update
  using (public.is_business_member(business_id))
  with check (public.is_business_member(business_id));
create policy "announce_delete" on public.announcements for delete
  using (public.is_business_member(business_id));

create policy "reactions_read" on public.reactions for select using (true);
create policy "reactions_own" on public.reactions for all using (user_id = auth.uid());

create policy "comments_read" on public.comments for select using (
  exists (
    select 1 from public.announcements a
    where a.id = comments.announcement_id
      and public.is_business_member(a.business_id)
  )
  or (deleted_at is null and (hidden_at is null or user_id = auth.uid()))
);
create policy "comments_own" on public.comments for all using (user_id = auth.uid());
create policy "comments_staff_update" on public.comments for update using (
  exists (
    select 1 from public.announcements a
    where a.id = comments.announcement_id
      and public.is_business_member(a.business_id)
  )
);
create policy "comments_staff_delete" on public.comments for delete using (
  exists (
    select 1 from public.announcements a
    where a.id = comments.announcement_id
      and public.is_business_member(a.business_id)
  )
);

create policy "convo_customer" on public.conversations for select using (customer_id = auth.uid());
create policy "convo_business" on public.conversations for select using (public.is_business_member(business_id));
create policy "convo_insert" on public.conversations for insert
  with check (customer_id = auth.uid() and public.is_approved_user());
create policy "convo_update_biz" on public.conversations for update using (public.is_business_member(business_id));

create policy "msg_read" on public.messages for select
using (
  sender_id = auth.uid()
  or exists (
    select 1 from public.conversations c
    where c.id = conversation_id
      and (c.customer_id = auth.uid() or public.is_business_member(c.business_id))
  )
);
create policy "msg_insert" on public.messages for insert
  with check (sender_id = auth.uid() and public.is_approved_user());
create policy "msg_update_business_member"
  on public.messages for update
  using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
        and public.is_business_member(c.business_id)
    )
  )
  with check (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
        and public.is_business_member(c.business_id)
    )
  );

create policy "notifications_own_read"
  on public.notifications for select
  using (user_id = auth.uid());
create policy "notifications_own_update"
  on public.notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy "notifications_own_delete"
  on public.notifications for delete
  using (user_id = auth.uid());
create policy "notifications_insert"
  on public.notifications for insert
  with check (
    user_id = auth.uid()
    or (
      business_id is not null
      and public.is_business_member(business_id)
    )
  );

create policy "inbox_label_defs_select"
  on public.inbox_label_definitions for select
  using (public.is_business_member(business_id));
create policy "inbox_label_defs_insert"
  on public.inbox_label_definitions for insert
  with check (
    public.is_business_member(business_id)
    and is_system = false
    and preset_key is null
  );
create policy "inbox_label_defs_update"
  on public.inbox_label_definitions for update
  using (public.is_business_member(business_id) and is_system = false)
  with check (public.is_business_member(business_id) and is_system = false and preset_key is null);
create policy "inbox_label_defs_delete"
  on public.inbox_label_definitions for delete
  using (public.is_business_member(business_id) and is_system = false);

create policy "conversation_inbox_labels_select"
  on public.conversation_inbox_labels for select
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_inbox_labels.conversation_id
        and public.is_business_member(c.business_id)
    )
  );
create policy "conversation_inbox_labels_insert"
  on public.conversation_inbox_labels for insert
  with check (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_inbox_labels.conversation_id
        and public.is_business_member(c.business_id)
    )
    and exists (
      select 1 from public.inbox_label_definitions d
      where d.id = conversation_inbox_labels.label_id
        and public.is_business_member(d.business_id)
    )
  );
create policy "conversation_inbox_labels_delete"
  on public.conversation_inbox_labels for delete
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_inbox_labels.conversation_id
        and public.is_business_member(c.business_id)
    )
  );

create policy "inbox_canned_replies_select"
  on public.inbox_canned_replies for select
  using (public.is_business_member(business_id));
create policy "inbox_canned_replies_insert"
  on public.inbox_canned_replies for insert
  with check (public.is_business_member(business_id));
create policy "inbox_canned_replies_update"
  on public.inbox_canned_replies for update
  using (public.is_business_member(business_id))
  with check (public.is_business_member(business_id));
create policy "inbox_canned_replies_delete"
  on public.inbox_canned_replies for delete
  using (public.is_business_member(business_id));

create policy "follows_read" on public.follows for select using (true);
create policy "follows_insert_approved" on public.follows for insert
  with check (user_id = auth.uid() and public.is_approved_user());
create policy "follows_delete_own" on public.follows for delete
  using (user_id = auth.uid());

create policy "admin_reports_select" on public.admin_reports for select
  using (public.is_business_member(business_id) or reporter_id = auth.uid());
create policy "admin_reports_insert" on public.admin_reports for insert
  with check (reporter_id = auth.uid());
create policy "admin_reports_update" on public.admin_reports for update
  using (public.is_business_member(business_id));

create policy "moderation_suspension_events_none"
  on public.moderation_suspension_events for all using (false);

create policy "deleted_users_audit_none" on public.deleted_users_audit for all using (false);

-- ------------------------------------------------------------
-- 18. TRIGGERS
-- ------------------------------------------------------------
create trigger set_announcements_updated_at
  before update on public.announcements
  for each row execute function public.set_updated_at();

create trigger set_conversations_updated_at
  before update on public.conversations
  for each row execute function public.set_updated_at();

create trigger set_admin_reports_updated_at
  before update on public.admin_reports
  for each row execute function public.set_updated_at();

create trigger set_inbox_canned_replies_updated_at
  before update on public.inbox_canned_replies
  for each row execute function public.set_updated_at();

create trigger businesses_seed_inbox_labels
  after insert on public.businesses
  for each row
  execute function public.seed_inbox_preset_labels_for_business();

create trigger messages_touch_conversation
  after insert on public.messages
  for each row execute function public.touch_conversation_on_message();

create trigger messages_notify_staff_after_insert
  after insert on public.messages
  for each row execute function public.notify_staff_on_customer_message();

-- Customer support_reply notifications are created by the app (POST /api/staff/notify-customer-reply).
-- messages_notify_customer_after_insert is intentionally not created (migration 012).

-- ------------------------------------------------------------
-- 19. STORAGE (message-images + profile-images)
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('message-images', 'message-images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do nothing;

create policy "message_images_select"
  on storage.objects for select
  using (bucket_id = 'message-images');

create policy "message_images_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'message-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "message_images_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'message-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "message_images_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'message-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "profile_images_select"
  on storage.objects for select
  using (bucket_id = 'profile-images');

create policy "profile_images_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "profile_images_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "profile_images_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ------------------------------------------------------------
-- 20. REALTIME PUBLICATION
-- ------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    return;
  end if;
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    return;
  end if;
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
