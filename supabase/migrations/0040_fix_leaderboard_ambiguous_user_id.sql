-- Bugfix di 0026: get_circle_leaderboard è plpgsql con "returns table(user_id uuid, ...)",
-- quindi user_id è anche una variabile di output implicita della funzione, visibile in
-- tutto il corpo. La CTE scored_photos faceva "select user_id, ... from ranked" senza
-- qualificare la tabella: Postgres non riesce a decidere se intendi ranked.user_id o la
-- variabile di output, da cui "column reference "user_id" is ambiguous" a ogni chiamata
-- (la classifica risultava quindi sempre vuota per errore RPC silenzioso). Stesso corpo
-- di 0026, solo con la colonna qualificata come ranked.user_id.

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
      ranked.user_id,
      ranked.photo_id,
      ((case when ranked.is_late then 0 else 1 end) + (case when ranked.rnk = 1 then 2 else 0 end))::int as score
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

grant execute on function public.get_circle_leaderboard(uuid, text) to authenticated;
