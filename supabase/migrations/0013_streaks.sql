-- Lo streak di gruppo era mostrato in Impostazioni ("Streak di gruppo: N giorni") ma
-- current_streak non veniva mai aggiornato: restava fermo a 0 per sempre. Questa
-- migrazione aggiunge la logica che lo aggiorna quando una sfida viene proclamata
-- (sia per chiusura anticipata che per il cron delle 20:00).
--
-- Una giornata "conta" per lo streak se tutti i partecipanti attesi (tutti i membri
-- tranne l'eventuale Game Master di quel giorno) hanno caricato una foto. Se la
-- giornata precedente valida era esattamente ieri, lo streak continua; altrimenti
-- riparte da 1. Se la giornata non è valida, lo streak si azzera.

create or replace function public.update_group_streak(p_daily_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_challenge_date date;
  v_proposed_by uuid;
  v_total_members int;
  v_expected_participants int;
  v_actual_photos int;
  v_day_valid boolean;
  v_last_valid_date date;
  v_current_streak int;
  v_longest_streak int;
  v_new_streak int;
begin
  select circle_id, challenge_date, proposed_by
    into v_circle_id, v_challenge_date, v_proposed_by
  from public.daily_challenges
  where id = p_daily_challenge_id;

  if v_circle_id is null then
    return;
  end if;

  select count(*) into v_total_members from public.circle_members where circle_id = v_circle_id;
  v_expected_participants := v_total_members - (case when v_proposed_by is not null then 1 else 0 end);

  -- Circle di un solo membro che è anche il Game Master di oggi: niente da contare.
  if v_expected_participants <= 0 then
    return;
  end if;

  select count(distinct user_id) into v_actual_photos
  from public.photos where daily_challenge_id = p_daily_challenge_id;

  v_day_valid := v_actual_photos >= v_expected_participants;

  select current_streak, longest_streak, last_valid_date
    into v_current_streak, v_longest_streak, v_last_valid_date
  from public.group_streaks
  where circle_id = v_circle_id
  for update;

  if not found then
    insert into public.group_streaks (circle_id, current_streak, longest_streak, last_valid_date)
    values (v_circle_id, 0, 0, null);
    v_current_streak := 0;
    v_longest_streak := 0;
    v_last_valid_date := null;
  end if;

  if v_day_valid then
    if v_last_valid_date is not null and v_last_valid_date = v_challenge_date - 1 then
      v_new_streak := v_current_streak + 1;
    else
      v_new_streak := 1;
    end if;

    update public.group_streaks
    set current_streak = v_new_streak,
        longest_streak = greatest(v_longest_streak, v_new_streak),
        last_valid_date = v_challenge_date
    where circle_id = v_circle_id;
  else
    update public.group_streaks
    set current_streak = 0
    where circle_id = v_circle_id;
  end if;
end;
$$;

-- Stesso corpo di 0009, con l'aggiunta della chiamata a update_group_streak dopo la proclamazione.
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

      perform public.update_group_streak(v_challenge.id);
    end if;
  end loop;
end;
$$;

-- Stesso corpo di 0010, con l'aggiunta della chiamata a update_group_streak dopo la proclamazione.
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

      perform public.update_group_streak(p_daily_challenge_id);
    end if;
  end if;
end;
$$;
