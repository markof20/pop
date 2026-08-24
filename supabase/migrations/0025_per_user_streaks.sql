-- Lo streak di gruppo azzerava tutti quando anche un solo membro non caricava la foto,
-- il che penalizzava chi partecipava regolarmente per colpa di altri. Sostituito con
-- uno streak per singolo utente per cerchia: ogni membro ha il proprio streak, valido
-- nei giorni in cui carica una foto in quella cerchia (indipendentemente dagli altri).

create table public.user_streaks (
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  last_valid_date date,
  primary key (circle_id, user_id)
);

alter table public.user_streaks enable row level security;

create policy user_streaks_select on public.user_streaks
  for select using (public.is_circle_member(circle_id));

-- Backfill: una riga per ogni membership già esistente.
insert into public.user_streaks (circle_id, user_id)
select circle_id, user_id from public.circle_members
on conflict (circle_id, user_id) do nothing;

drop function public.update_group_streak(uuid);
drop table public.group_streaks;

create or replace function public.update_user_streaks(p_daily_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_challenge_date date;
  v_member record;
  v_current_streak int;
  v_longest_streak int;
  v_last_valid_date date;
  v_new_streak int;
begin
  select circle_id, challenge_date into v_circle_id, v_challenge_date
  from public.daily_challenges
  where id = p_daily_challenge_id;

  if v_circle_id is null then
    return;
  end if;

  for v_member in
    select
      cm.user_id,
      exists (
        select 1 from public.photos p
        where p.daily_challenge_id = p_daily_challenge_id and p.user_id = cm.user_id
      ) as uploaded
    from public.circle_members cm
    where cm.circle_id = v_circle_id
  loop
    select current_streak, longest_streak, last_valid_date
      into v_current_streak, v_longest_streak, v_last_valid_date
    from public.user_streaks
    where circle_id = v_circle_id and user_id = v_member.user_id
    for update;

    if not found then
      insert into public.user_streaks (circle_id, user_id, current_streak, longest_streak, last_valid_date)
      values (v_circle_id, v_member.user_id, 0, 0, null);
      v_current_streak := 0;
      v_longest_streak := 0;
      v_last_valid_date := null;
    end if;

    if v_member.uploaded then
      if v_last_valid_date is not null and v_last_valid_date = v_challenge_date - 1 then
        v_new_streak := v_current_streak + 1;
      else
        v_new_streak := 1;
      end if;

      update public.user_streaks
      set current_streak = v_new_streak,
          longest_streak = greatest(v_longest_streak, v_new_streak),
          last_valid_date = v_challenge_date
      where circle_id = v_circle_id and user_id = v_member.user_id;
    else
      update public.user_streaks
      set current_streak = 0
      where circle_id = v_circle_id and user_id = v_member.user_id;
    end if;
  end loop;
end;
$$;

-- create_circle: crea la riga user_streaks per il fondatore invece di group_streaks.
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

  insert into public.user_streaks (circle_id, user_id)
  values (v_circle.id, auth.uid());

  return v_circle;
end;
$$;

-- join_circle_by_code: crea la riga user_streaks anche per chi entra via invito.
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

  insert into public.user_streaks (circle_id, user_id)
  values (v_circle.id, auth.uid())
  on conflict (circle_id, user_id) do nothing;

  return v_circle;
end;
$$;

-- Stesso corpo di 0024, con update_user_streaks al posto di update_group_streak:
-- chiamata sempre (non solo se c'è un vincitore) così ogni membro che non ha caricato
-- foto quel giorno vede il proprio streak azzerato, senza penalizzare gli altri.
create or replace function public.proclaim_winners_for_date(p_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge record;
  v_winner_user_id uuid;
  v_circle record;
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

    perform public.update_user_streaks(v_challenge.id);
  end loop;

  -- Cerchie senza nessuna sfida per questa data: nessuno ha partecipato, streak di tutti azzerato.
  for v_circle in
    select c.id
    from public.circles c
    where not exists (
      select 1 from public.daily_challenges dc
      where dc.circle_id = c.id and dc.challenge_date = p_date
    )
  loop
    update public.user_streaks
    set current_streak = 0
    where circle_id = v_circle.id
      and current_streak <> 0;
  end loop;
end;
$$;

-- Stesso corpo di 0013, con update_user_streaks al posto di update_group_streak.
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

      perform public.update_user_streaks(p_daily_challenge_id);
    end if;
  end if;
end;
$$;
