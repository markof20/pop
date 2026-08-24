-- Nuovo sistema punteggio: prima un ritardo di molte ore poteva portare il punteggio
-- sotto zero (voti - ore di ritardo, senza limite). Ora:
--   - caricare la foto in orario vale 1 punto, subito;
--   - caricarla in ritardo non vale niente (né bonus né penalità) ma si può comunque
--     partecipare alla votazione;
--   - chi vince la votazione del giorno (più top pick, a parità vince chi ha scattato
--     prima) guadagna altri 2 punti, indipendentemente dal ritardo.
-- Ogni componente è >= 0, quindi il totale non può più andare in negativo: non serve
-- un azzeramento esplicito dei punteggi negativi, spariscono da soli cambiando formula
-- perché total_score non è un valore salvato ma ricalcolato ogni volta da qui.

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
  with ranked as (
    select
      p.id as photo_id,
      p.user_id,
      pr.username,
      p.storage_path,
      p.is_late,
      greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600))::int as hours_late,
      coalesce(tp.cnt, 0)::int as top_pick_count,
      p.uploaded_at,
      row_number() over (order by coalesce(tp.cnt, 0) desc, p.uploaded_at asc) as rnk
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
  )
  select
    photo_id,
    user_id,
    username,
    storage_path,
    is_late,
    hours_late,
    top_pick_count,
    ((case when is_late then 0 else 1 end) + (case when rnk = 1 then 2 else 0 end))::int as score,
    uploaded_at
  from ranked
  order by rnk asc;
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
  with ranked as (
    select
      p.user_id,
      p.id as photo_id,
      p.is_late,
      row_number() over (
        partition by p.daily_challenge_id
        order by coalesce(tp.cnt, 0) desc, p.uploaded_at asc
      ) as rnk
    from public.photos p
    join public.daily_challenges dc on dc.id = p.daily_challenge_id
    left join (
      select photo_id, count(*) as cnt from public.top_picks group by photo_id
    ) tp on tp.photo_id = p.id
    where dc.circle_id = p_circle_id and dc.challenge_date >= v_since
  ),
  scored_photos as (
    select
      user_id,
      photo_id,
      ((case when is_late then 0 else 1 end) + (case when rnk = 1 then 2 else 0 end))::int as score
    from ranked
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
