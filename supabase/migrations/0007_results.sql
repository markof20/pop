-- Fase 3 (parziale): risultati del giorno precedente e attribuzione dei top pick.
-- Il punteggio di una foto = numero di top pick ricevuti - 1 punto per ogni ora
-- intera di ritardo rispetto al timer personale di chi l'ha caricata.

create or replace function public.get_latest_completed_challenge(p_circle_id uuid)
returns public.daily_challenges
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_row public.daily_challenges;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select * into v_row
  from public.daily_challenges
  where circle_id = p_circle_id and challenge_date < current_date
  order by challenge_date desc
  limit 1;

  if v_row.id is null then
    return null;
  end if;

  return v_row;
end;
$$;

grant execute on function public.get_latest_completed_challenge(uuid) to authenticated;

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

  return query
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
end;
$$;

grant execute on function public.get_challenge_results(uuid) to authenticated;
