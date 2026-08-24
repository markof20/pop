-- Classifica per cerchia: punteggio totale (top pick ricevuti - penalità ritardo,
-- lo stesso usato per determinare il vincitore giornaliero), sommato su due
-- periodi: 'all_time' (da sempre) e 'weekly' (settimana corrente, lunedì-oggi).
-- Include anche il numero di vittorie nello stesso periodo come contesto extra.

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

grant execute on function public.get_circle_leaderboard(uuid, text) to authenticated;
