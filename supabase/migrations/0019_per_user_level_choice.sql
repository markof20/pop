-- Il livello (e quindi il prompt esatto) diventa una scelta personale, non della
-- cerchia: ogni membro lo sceglie quando apre la sfida del giorno, vede in anteprima
-- le domande di entrambi i livelli, e riceve un prompt personale da quel livello.
-- La griglia e la votazione restano condivise: si vota una foto anche se risponde a
-- una domanda diversa dalla propria.

alter table public.circles
  drop column level;

alter table public.challenge_participants
  add column level int check (level in (1, 2)),
  add column prompt_text text,
  add column prompt_points int not null default 1;

-- start_my_challenge ora accetta il livello scelto (richiesto solo la prima volta,
-- solo per categorie "leveled" con prompt di sistema — non per winner_choice, dove
-- il prompt è unico e già fissato dal Game Master).
-- La firma cambia (era solo uuid): drop esplicito per non lasciare in giro la
-- vecchia versione a 1 argomento come overload separato.
drop function if exists public.start_my_challenge(uuid);

create or replace function public.start_my_challenge(p_daily_challenge_id uuid, p_level int default null)
returns public.challenge_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.challenge_participants;
  v_circle_id uuid;
  v_source text;
  v_category text;
  v_time_window_minutes int;
  v_prompt_text text;
  v_prompt_points int;
  v_level int;
begin
  select circle_id, source into v_circle_id, v_source
  from public.daily_challenges where id = p_daily_challenge_id;

  if v_circle_id is null or not public.is_circle_member(v_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select * into v_row from public.challenge_participants
  where daily_challenge_id = p_daily_challenge_id and user_id = auth.uid();

  if v_row.user_id is not null then
    return v_row;
  end if;

  select time_window_minutes, category into v_time_window_minutes, v_category
  from public.circles where id = v_circle_id;

  if v_category in ('amici', 'hot') and v_source = 'seed' then
    if p_level is null or p_level not in (1, 2) then
      raise exception 'Devi scegliere un livello';
    end if;

    select text into v_prompt_text
    from public.prompts
    where is_seed = true
      and category = v_category
      and level = p_level
      and text not in (
        select coalesce(cp.prompt_text, '')
        from public.challenge_participants cp
        join public.daily_challenges dc2 on dc2.id = cp.daily_challenge_id
        where dc2.circle_id = v_circle_id and cp.user_id = auth.uid()
      )
    order by random()
    limit 1;

    if v_prompt_text is null then
      select text into v_prompt_text
      from public.prompts
      where is_seed = true and category = v_category and level = p_level
      order by random()
      limit 1;
    end if;

    v_level := p_level;
    v_prompt_points := p_level;
  else
    select prompt_text, prompt_points into v_prompt_text, v_prompt_points
    from public.daily_challenges where id = p_daily_challenge_id;
    v_level := null;
  end if;

  insert into public.challenge_participants (
    daily_challenge_id, user_id, started_at, window_end_at, level, prompt_text, prompt_points
  ) values (
    p_daily_challenge_id,
    auth.uid(),
    now(),
    now() + (v_time_window_minutes || ' minutes')::interval,
    v_level,
    v_prompt_text,
    coalesce(v_prompt_points, 1)
  )
  on conflict (daily_challenge_id, user_id) do nothing;

  select * into v_row from public.challenge_participants
  where daily_challenge_id = p_daily_challenge_id and user_id = auth.uid();

  return v_row;
end;
$$;

grant execute on function public.start_my_challenge(uuid, int) to authenticated;

-- get_active_challenge non sceglie più un prompt fisso per le categorie a livelli:
-- resta un testo segnaposto finché ciascun membro non sceglie il proprio livello.
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

  if v_category in ('amici', 'hot') then
    v_prompt_text := 'Scegli il tuo livello per vedere il prompt di oggi';
  else
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
  end if;

  insert into public.daily_challenges (
    circle_id, challenge_date, prompt_text, source, activation_at, window_end_at, status, prompt_points
  ) values (
    p_circle_id,
    current_date,
    v_prompt_text,
    'seed',
    now(),
    now() + (v_time_window_minutes || ' minutes')::interval,
    'active',
    1
  )
  returning * into v_challenge;

  return v_challenge;
end;
$$;

-- create_circle torna a non occuparsi del livello: non è più una scelta della cerchia.
-- La firma cambia (0018 aveva anche p_level): drop esplicito per non lasciare in
-- giro il vecchio overload a 4 argomenti.
drop function if exists public.create_circle(text, int, text, int);

create or replace function public.create_circle(
  p_name text,
  p_time_window_minutes int default 120,
  p_category text default 'normal'
)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle public.circles;
  v_code text;
begin
  if p_category not in ('amici', 'normal', 'hot') then
    raise exception 'Categoria non valida';
  end if;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.circles (name, invite_code, time_window_minutes, category, created_by)
  values (p_name, v_code, p_time_window_minutes, p_category, auth.uid())
  returning * into v_circle;

  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle.id, auth.uid(), 'admin');

  insert into public.group_streaks (circle_id)
  values (v_circle.id);

  return v_circle;
end;
$$;

-- Il punteggio e i risultati ora leggono il prompt/punti personali dal partecipante
-- quando esistono (categorie a livelli), altrimenti quelli condivisi della sfida.
-- Aggiungere una colonna al "returns table" richiede il drop esplicito (Postgres non
-- permette di cambiare la forma delle OUT-parameter con un semplice create or replace).
drop function if exists public.compute_challenge_scores(uuid);

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
  uploaded_at timestamptz,
  prompt_text text
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
    (coalesce(tp.cnt, 0) * coalesce(cp.prompt_points, dc.prompt_points, 1) - greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600)))::int as score,
    p.uploaded_at,
    coalesce(cp.prompt_text, dc.prompt_text) as prompt_text
  from public.photos p
  join public.profiles pr on pr.id = p.user_id
  join public.daily_challenges dc on dc.id = p.daily_challenge_id
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

drop function if exists public.get_challenge_results(uuid);

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
  uploaded_at timestamptz,
  prompt_text text
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
      (coalesce(tp.cnt, 0) * coalesce(cp.prompt_points, dc.prompt_points, 1) - greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600)))::int as score
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

-- Il banner "hai vinto ieri" deve mostrare il prompt che il vincitore ha davvero
-- fotografato (personale nelle categorie a livelli), non il segnaposto della sfida.
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
  select dc.id, coalesce(cp.prompt_text, dc.prompt_text), dc.challenge_date, wd.decide_by_at
  from public.winner_decisions wd
  join public.daily_challenges dc on dc.id = wd.daily_challenge_id
  left join public.challenge_participants cp
    on cp.daily_challenge_id = dc.id and cp.user_id = wd.winner_user_id
  where dc.circle_id = p_circle_id
    and wd.winner_user_id = auth.uid()
    and wd.choice is null
    and wd.decide_by_at > now()
  order by dc.challenge_date desc
  limit 1;
end;
$$;
