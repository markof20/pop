-- Rimuove la struttura a livelli: torna a un'unica domanda condivisa al giorno per
-- l'intera cerchia (per categoria), come prima di 0016. I prompt che erano "livello 2"
-- restano nella libreria (colonna level rimossa) e rientrano semplicemente nel pool
-- della loro categoria: più varietà, nessun contenuto sprecato.

drop function if exists public.start_my_challenge(uuid, int);
drop function if exists public.compute_challenge_scores(uuid);
drop function if exists public.get_challenge_results(uuid);

alter table public.daily_challenges
  drop column prompt_text_level1,
  drop column prompt_text_level2,
  drop column prompt_points;

alter table public.challenge_participants
  drop column level,
  drop column prompt_text,
  drop column prompt_points;

alter table public.prompts
  drop column level;

create or replace function public.get_active_challenge(p_circle_id uuid)
returns public.daily_challenges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.daily_challenges;
  v_time_window_minutes int;
  v_category text;
  v_prompt_text text;
  v_prev_challenge public.daily_challenges;
  v_winner_user_id uuid;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select time_window_minutes, category into v_time_window_minutes, v_category
  from public.circles where id = p_circle_id;

  -- Proclama il vincitore della sfida passata più recente, se non è già stato fatto.
  select * into v_prev_challenge
  from public.daily_challenges
  where circle_id = p_circle_id and challenge_date < current_date
  order by challenge_date desc
  limit 1;

  if v_prev_challenge.id is not null
     and not exists (select 1 from public.winner_decisions where daily_challenge_id = v_prev_challenge.id)
  then
    select r.user_id into v_winner_user_id
    from public.get_challenge_results(v_prev_challenge.id) r
    order by r.score desc, r.uploaded_at asc
    limit 1;

    if v_winner_user_id is not null then
      insert into public.winner_decisions (daily_challenge_id, winner_user_id, choice, decide_by_at)
      values (v_prev_challenge.id, v_winner_user_id, null, now() + interval '1 hour')
      on conflict (daily_challenge_id) do nothing;
    end if;
  end if;

  -- Sfida di oggi: se esiste già (magari creata dal vincitore con l'Opzione A), restituiscila.
  select * into v_challenge
  from public.daily_challenges
  where circle_id = p_circle_id and challenge_date = current_date;

  if v_challenge.id is not null then
    return v_challenge;
  end if;

  select text into v_prompt_text
  from public.prompts
  where is_seed = true
    and category = v_category
    and text not in (
      select prompt_text from public.daily_challenges where circle_id = p_circle_id
    )
  order by random()
  limit 1;

  if v_prompt_text is null then
    select text into v_prompt_text
    from public.prompts
    where is_seed = true and category = v_category
    order by random()
    limit 1;
  end if;

  insert into public.daily_challenges (
    circle_id, challenge_date, prompt_text, source, activation_at, window_end_at, status
  ) values (
    p_circle_id,
    current_date,
    v_prompt_text,
    'seed',
    now(),
    now() + (v_time_window_minutes || ' minutes')::interval,
    'active'
  )
  returning * into v_challenge;

  return v_challenge;
end;
$$;

create or replace function public.start_my_challenge(p_daily_challenge_id uuid)
returns public.challenge_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.challenge_participants;
  v_circle_id uuid;
  v_time_window_minutes int;
begin
  select circle_id into v_circle_id from public.daily_challenges where id = p_daily_challenge_id;

  if v_circle_id is null or not public.is_circle_member(v_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select time_window_minutes into v_time_window_minutes from public.circles where id = v_circle_id;

  insert into public.challenge_participants (daily_challenge_id, user_id, started_at, window_end_at)
  values (p_daily_challenge_id, auth.uid(), now(), now() + (v_time_window_minutes || ' minutes')::interval)
  on conflict (daily_challenge_id, user_id) do nothing;

  select * into v_row from public.challenge_participants
  where daily_challenge_id = p_daily_challenge_id and user_id = auth.uid();

  return v_row;
end;
$$;

grant execute on function public.start_my_challenge(uuid) to authenticated;

create or replace function public.compute_challenge_scores(p_daily_challenge_id uuid)
returns table (
  photo_id uuid,
  user_id uuid,
  username text,
  storage_path text,
  is_late boolean,
  hours_late int,
  top_pick_count int,
  score int,
  uploaded_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    p.id as photo_id,
    p.user_id,
    pr.username,
    p.storage_path,
    p.is_late,
    greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600))::int as hours_late,
    coalesce(tp.cnt, 0)::int as top_pick_count,
    (coalesce(tp.cnt, 0) - greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600)))::int as score,
    p.uploaded_at
  from public.photos p
  join public.profiles pr on pr.id = p.user_id
  left join public.challenge_participants cp
    on cp.daily_challenge_id = p.daily_challenge_id and cp.user_id = p.user_id
  left join (
    select photo_id, count(*) as cnt
    from public.top_picks
    where daily_challenge_id = p_daily_challenge_id
    group by photo_id
  ) tp on tp.photo_id = p.id
  where p.daily_challenge_id = p_daily_challenge_id
  order by score desc, p.uploaded_at asc;
$$;

create or replace function public.get_challenge_results(p_daily_challenge_id uuid)
returns table (
  photo_id uuid,
  user_id uuid,
  username text,
  storage_path text,
  is_late boolean,
  hours_late int,
  top_pick_count int,
  score int,
  uploaded_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_circle_id uuid;
begin
  select circle_id into v_circle_id from public.daily_challenges where id = p_daily_challenge_id;
  if v_circle_id is null or not public.is_circle_member(v_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  return query select * from public.compute_challenge_scores(p_daily_challenge_id);
end;
$$;

create or replace function public.get_circle_leaderboard(p_circle_id uuid, p_period text default 'all_time')
returns table (
  user_id uuid,
  username text,
  total_score int,
  wins_count int,
  challenges_participated int
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_since date;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  if p_period not in ('all_time', 'weekly') then
    raise exception 'Periodo non valido';
  end if;

  v_since := case
    when p_period = 'weekly' then date_trunc('week', current_date)::date
    else '0001-01-01'::date
  end;

  return query
  with scored_photos as (
    select
      p.user_id,
      p.id as photo_id,
      (coalesce(tp.cnt, 0) - greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600)))::int as score
    from public.photos p
    join public.daily_challenges dc on dc.id = p.daily_challenge_id
    left join public.challenge_participants cp
      on cp.daily_challenge_id = p.daily_challenge_id and cp.user_id = p.user_id
    left join (
      select photo_id, count(*) as cnt from public.top_picks group by photo_id
    ) tp on tp.photo_id = p.id
    where dc.circle_id = p_circle_id and dc.challenge_date >= v_since
  ),
  wins as (
    select wd.winner_user_id, count(*) as wins_count
    from public.winner_decisions wd
    join public.daily_challenges dc on dc.id = wd.daily_challenge_id
    where dc.circle_id = p_circle_id and dc.challenge_date >= v_since
    group by wd.winner_user_id
  )
  select
    cm.user_id,
    pr.username,
    coalesce(sum(sp.score), 0)::int as total_score,
    coalesce(max(w.wins_count), 0)::int as wins_count,
    count(distinct sp.photo_id)::int as challenges_participated
  from public.circle_members cm
  join public.profiles pr on pr.id = cm.user_id
  left join scored_photos sp on sp.user_id = cm.user_id
  left join wins w on w.winner_user_id = cm.user_id
  where cm.circle_id = p_circle_id
  group by cm.user_id, pr.username
  order by total_score desc, wins_count desc, pr.username asc;
end;
$$;

create or replace function public.get_my_pending_win(p_circle_id uuid)
returns table (
  daily_challenge_id uuid,
  prompt_text text,
  challenge_date date,
  decide_by_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  return query
  select dc.id, dc.prompt_text, dc.challenge_date, wd.decide_by_at
  from public.winner_decisions wd
  join public.daily_challenges dc on dc.id = wd.daily_challenge_id
  where dc.circle_id = p_circle_id
    and wd.winner_user_id = auth.uid()
    and wd.choice is null
    and wd.decide_by_at > now()
  order by dc.challenge_date desc
  limit 1;
end;
$$;
