-- Se tutti i membri (attesi) hanno caricato la foto e tutti hanno dato il loro
-- top pick, la sfida termina subito con i risultati, senza aspettare le 20:00.
-- Approfitto per accorpare in una funzione condivisa il calcolo del punteggio
-- (finora duplicato tra get_challenge_results e proclaim_winners_for_date).

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

create or replace function public.proclaim_winners_for_date(p_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge record;
  v_winner_user_id uuid;
begin
  for v_challenge in
    select dc.id
    from public.daily_challenges dc
    where dc.challenge_date = p_date
      and not exists (select 1 from public.winner_decisions wd where wd.daily_challenge_id = dc.id)
  loop
    select user_id into v_winner_user_id
    from public.compute_challenge_scores(v_challenge.id)
    order by score desc, uploaded_at asc
    limit 1;

    if v_winner_user_id is not null then
      insert into public.winner_decisions (daily_challenge_id, winner_user_id, choice, decide_by_at)
      values (v_challenge.id, v_winner_user_id, null, now() + interval '1 hour')
      on conflict (daily_challenge_id) do nothing;
    end if;
  end loop;
end;
$$;

-- Chiude una sfida subito se tutti i partecipanti attesi hanno caricato la foto
-- e tutti i membri hanno dato il loro top pick. Chi ha proposto il prompt
-- (Game Master) non conta tra i partecipanti attesi ma conta tra i votanti.
create or replace function public.finalize_challenge_if_ready(p_daily_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_proposed_by uuid;
  v_total_members int;
  v_expected_participants int;
  v_actual_photos int;
  v_actual_voters int;
  v_winner_user_id uuid;
begin
  if exists (select 1 from public.winner_decisions where daily_challenge_id = p_daily_challenge_id) then
    return;
  end if;

  select circle_id, proposed_by into v_circle_id, v_proposed_by
  from public.daily_challenges where id = p_daily_challenge_id;

  if v_circle_id is null then
    return;
  end if;

  select count(*) into v_total_members from public.circle_members where circle_id = v_circle_id;
  v_expected_participants := v_total_members - (case when v_proposed_by is not null then 1 else 0 end);

  select count(distinct user_id) into v_actual_photos
  from public.photos where daily_challenge_id = p_daily_challenge_id;

  select count(distinct voter_id) into v_actual_voters
  from public.top_picks where daily_challenge_id = p_daily_challenge_id;

  if v_expected_participants > 0
     and v_actual_photos >= v_expected_participants
     and v_total_members > 0
     and v_actual_voters >= v_total_members
  then
    select user_id into v_winner_user_id
    from public.compute_challenge_scores(p_daily_challenge_id)
    order by score desc, uploaded_at asc
    limit 1;

    if v_winner_user_id is not null then
      insert into public.winner_decisions (daily_challenge_id, winner_user_id, choice, decide_by_at)
      values (p_daily_challenge_id, v_winner_user_id, null, now() + interval '1 hour')
      on conflict (daily_challenge_id) do nothing;
    end if;
  end if;
end;
$$;

create or replace function public.trg_finalize_on_photo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.finalize_challenge_if_ready(new.daily_challenge_id);
  return new;
end;
$$;

drop trigger if exists trg_photos_finalize on public.photos;
create trigger trg_photos_finalize
  after insert on public.photos
  for each row execute procedure public.trg_finalize_on_photo();

create or replace function public.trg_finalize_on_top_pick()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.finalize_challenge_if_ready(new.daily_challenge_id);
  return new;
end;
$$;

drop trigger if exists trg_top_picks_finalize on public.top_picks;
create trigger trg_top_picks_finalize
  after insert or update on public.top_picks
  for each row execute procedure public.trg_finalize_on_top_pick();
