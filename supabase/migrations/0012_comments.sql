-- Commenti sotto ogni foto, visibili/scrivibili solo dai membri della cerchia a cui appartiene la foto.
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.photos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index comments_photo_id_idx on public.comments (photo_id, created_at);

alter table public.comments enable row level security;

create policy comments_select on public.comments
  for select using (
    public.is_circle_member((
      select dc.circle_id from public.daily_challenges dc
      join public.photos p on p.daily_challenge_id = dc.id
      where p.id = photo_id
    ))
  );

create policy comments_insert_self on public.comments
  for insert with check (
    user_id = auth.uid()
    and public.is_circle_member((
      select dc.circle_id from public.daily_challenges dc
      join public.photos p on p.daily_challenge_id = dc.id
      where p.id = photo_id
    ))
  );

create policy comments_delete_self on public.comments
  for delete using (user_id = auth.uid());
