-- POP schema: profiles, circles, prompts, daily challenges, photos, votes, streaks
-- All tables use Row Level Security scoped to circle membership.

-- ============================================================
-- ENUMS
-- ============================================================
create type public.circle_role as enum ('admin', 'member');
create type public.challenge_status as enum ('pending', 'active', 'voting', 'completed');
create type public.challenge_source as enum ('seed', 'winner_choice');
create type public.winner_choice as enum ('A', 'B', 'auto_default');

-- ============================================================
-- TABLES
-- ============================================================

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique not null,
  time_window_minutes int not null default 120,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.circle_members (
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.circle_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create table public.prompts (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  is_seed boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.daily_challenges (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  challenge_date date not null,
  prompt_text text not null,
  proposed_by uuid references public.profiles(id),
  source public.challenge_source not null default 'seed',
  activation_at timestamptz not null,
  window_end_at timestamptz not null,
  status public.challenge_status not null default 'pending',
  created_at timestamptz not null default now(),
  unique (circle_id, challenge_date)
);

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  daily_challenge_id uuid not null references public.daily_challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  taken_at timestamptz not null default now(),
  uploaded_at timestamptz not null default now(),
  is_late boolean not null default false,
  retake_count int not null default 0,
  created_at timestamptz not null default now(),
  unique (daily_challenge_id, user_id)
);

create table public.top_picks (
  id uuid primary key default gen_random_uuid(),
  daily_challenge_id uuid not null references public.daily_challenges(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  photo_id uuid not null references public.photos(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (daily_challenge_id, voter_id)
);

create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.photos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now()
);

create table public.winner_decisions (
  daily_challenge_id uuid primary key references public.daily_challenges(id) on delete cascade,
  winner_user_id uuid not null references public.profiles(id),
  choice public.winner_choice,
  decide_by_at timestamptz not null,
  decided_at timestamptz
);

create table public.group_streaks (
  circle_id uuid primary key references public.circles(id) on delete cascade,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  last_valid_date date
);

create table public.circle_month_stats (
  circle_id uuid not null references public.circles(id) on delete cascade,
  year_month text not null, -- format 'YYYY-MM'
  user_id uuid not null references public.profiles(id) on delete cascade,
  wins_count int not null default 0,
  primary key (circle_id, year_month, user_id)
);

create table public.badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  circle_id uuid not null references public.circles(id) on delete cascade,
  badge_type text not null,
  year_month text,
  awarded_at timestamptz not null default now()
);

-- ============================================================
-- HELPER FUNCTIONS (security definer to avoid RLS recursion)
-- ============================================================

create or replace function public.is_circle_member(p_circle_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.circle_members
    where circle_id = p_circle_id and user_id = p_user_id
  );
$$;

create or replace function public.is_circle_admin(p_circle_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.circle_members
    where circle_id = p_circle_id and user_id = p_user_id and role = 'admin'
  );
$$;

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Enforce the 20-member cap per circle.
create or replace function public.enforce_circle_member_limit()
returns trigger
language plpgsql
as $$
declare
  member_count int;
begin
  select count(*) into member_count from public.circle_members where circle_id = new.circle_id;
  if member_count >= 20 then
    raise exception 'Circle has reached the maximum of 20 members';
  end if;
  return new;
end;
$$;

create trigger trg_circle_member_limit
  before insert on public.circle_members
  for each row execute procedure public.enforce_circle_member_limit();

-- Atomically create a circle, make the creator its admin, and init its streak row.
create or replace function public.create_circle(p_name text, p_time_window_minutes int default 120)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle public.circles;
  v_code text;
begin
  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.circles (name, invite_code, time_window_minutes, created_by)
  values (p_name, v_code, p_time_window_minutes, auth.uid())
  returning * into v_circle;

  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle.id, auth.uid(), 'admin');

  insert into public.group_streaks (circle_id)
  values (v_circle.id);

  return v_circle;
end;
$$;

grant execute on function public.create_circle(text, int) to authenticated;

-- Join a circle via its invite code without exposing the circles table to non-members.
create or replace function public.join_circle_by_code(p_invite_code text)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle public.circles;
begin
  select * into v_circle from public.circles where invite_code = upper(p_invite_code);

  if v_circle.id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle.id, auth.uid(), 'member')
  on conflict (circle_id, user_id) do nothing;

  return v_circle;
end;
$$;

grant execute on function public.join_circle_by_code(text) to authenticated;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.prompts enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.photos enable row level security;
alter table public.top_picks enable row level security;
alter table public.reactions enable row level security;
alter table public.winner_decisions enable row level security;
alter table public.group_streaks enable row level security;
alter table public.circle_month_stats enable row level security;
alter table public.badges enable row level security;

-- profiles: visible to yourself and anyone who shares a circle with you
create policy profiles_select on public.profiles
  for select using (
    id = auth.uid()
    or exists (
      select 1 from public.circle_members cm1
      join public.circle_members cm2 on cm1.circle_id = cm2.circle_id
      where cm1.user_id = auth.uid() and cm2.user_id = profiles.id
    )
  );

create policy profiles_insert_self on public.profiles
  for insert with check (id = auth.uid());

create policy profiles_update_self on public.profiles
  for update using (id = auth.uid());

-- circles: visible only to members; created via create_circle() RPC
create policy circles_select on public.circles
  for select using (public.is_circle_member(id));

create policy circles_update_admin on public.circles
  for update using (public.is_circle_admin(id));

-- circle_members: visible to fellow members; self-join/leave, admin can manage
create policy circle_members_select on public.circle_members
  for select using (public.is_circle_member(circle_id));

create policy circle_members_insert_self on public.circle_members
  for insert with check (user_id = auth.uid());

create policy circle_members_delete on public.circle_members
  for delete using (user_id = auth.uid() or public.is_circle_admin(circle_id));

create policy circle_members_update_admin on public.circle_members
  for update using (public.is_circle_admin(circle_id));

-- prompts: readable seed library, writable only via migrations/service role
create policy prompts_select on public.prompts
  for select using (auth.role() = 'authenticated');

-- daily_challenges: readable by circle members (writes come from Edge Functions later)
create policy daily_challenges_select on public.daily_challenges
  for select using (public.is_circle_member(circle_id));

-- photos: readable/insertable by circle members, only your own photo
create policy photos_select on public.photos
  for select using (
    public.is_circle_member((select circle_id from public.daily_challenges where id = daily_challenge_id))
  );

create policy photos_insert_self on public.photos
  for insert with check (
    user_id = auth.uid()
    and public.is_circle_member((select circle_id from public.daily_challenges where id = daily_challenge_id))
  );

-- top_picks: 1 per user per day, cannot vote for your own photo
create policy top_picks_select on public.top_picks
  for select using (
    public.is_circle_member((select circle_id from public.daily_challenges where id = daily_challenge_id))
  );

create policy top_picks_insert_self on public.top_picks
  for insert with check (
    voter_id = auth.uid()
    and public.is_circle_member((select circle_id from public.daily_challenges where id = daily_challenge_id))
    and voter_id <> (select user_id from public.photos where id = photo_id)
  );

-- reactions: unlimited, but only within your circles
create policy reactions_select on public.reactions
  for select using (
    public.is_circle_member((
      select dc.circle_id from public.daily_challenges dc
      join public.photos p on p.daily_challenge_id = dc.id
      where p.id = photo_id
    ))
  );

create policy reactions_insert_self on public.reactions
  for insert with check (
    user_id = auth.uid()
    and public.is_circle_member((
      select dc.circle_id from public.daily_challenges dc
      join public.photos p on p.daily_challenge_id = dc.id
      where p.id = photo_id
    ))
  );

-- winner_decisions: circle can read, only the winner can record their choice
create policy winner_decisions_select on public.winner_decisions
  for select using (
    public.is_circle_member((select circle_id from public.daily_challenges where id = daily_challenge_id))
  );

create policy winner_decisions_update_winner on public.winner_decisions
  for update using (winner_user_id = auth.uid());

-- group_streaks / circle_month_stats / badges: read-only for circle members
create policy group_streaks_select on public.group_streaks
  for select using (public.is_circle_member(circle_id));

create policy circle_month_stats_select on public.circle_month_stats
  for select using (public.is_circle_member(circle_id));

create policy badges_select on public.badges
  for select using (public.is_circle_member(circle_id));

-- ============================================================
-- STORAGE (private "photos" bucket, path convention: {circle_id}/{daily_challenge_id}/{user_id}.jpg)
-- ============================================================

insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

create policy storage_photos_select on storage.objects
  for select using (
    bucket_id = 'photos'
    and public.is_circle_member((storage.foldername(name))[1]::uuid)
  );

create policy storage_photos_insert on storage.objects
  for insert with check (
    bucket_id = 'photos'
    and public.is_circle_member((storage.foldername(name))[1]::uuid)
  );
