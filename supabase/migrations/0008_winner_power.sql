-- Fase 3: potere del vincitore.
-- Quando qualcuno apre la cerchia in un nuovo giorno, la sfida più recente del
-- passato senza un vincitore proclamato viene chiusa: si calcola il punteggio
-- migliore e si apre una finestra di 1 ora in cui il vincitore può scegliere
-- se proporre lui il prompt di oggi (Opzione A) o lasciare scegliere l'app
-- (Opzione B, anche di default se il tempo scade).

create or replace function public.get_active_challenge(p_circle_id uuid)
returns public.daily_challenges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.daily_challenges;
  v_time_window_minutes int;
  v_prompt_text text;
  v_prev_challenge public.daily_challenges;
  v_winner_user_id uuid;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select time_window_minutes into v_time_window_minutes
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
    and text not in (
      select prompt_text from public.daily_challenges where circle_id = p_circle_id
    )
  order by random()
  limit 1;

  if v_prompt_text is null then
    select text into v_prompt_text from public.prompts where is_seed = true order by random() limit 1;
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

-- Restituisce l'eventuale vittoria non ancora decisa dall'utente in questa cerchia
-- (vuoto se non ha vinto nulla o la finestra di 1 ora è scaduta).
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

grant execute on function public.get_my_pending_win(uuid) to authenticated;

-- Il vincitore sceglie: 'A' (propone il prompt di oggi, non partecipa) o 'B' (lascia scegliere l'app).
create or replace function public.submit_winner_choice(
  p_won_challenge_id uuid,
  p_choice text,
  p_custom_prompt text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_decision public.winner_decisions;
  v_won_challenge public.daily_challenges;
  v_next_date date;
  v_next_challenge public.daily_challenges;
  v_time_window_minutes int;
  v_existing_photo_count int;
begin
  select * into v_decision from public.winner_decisions where daily_challenge_id = p_won_challenge_id;

  if v_decision.daily_challenge_id is null then
    raise exception 'Nessuna decisione da prendere per questa sfida';
  end if;

  if v_decision.winner_user_id <> auth.uid() then
    raise exception 'Solo il vincitore può decidere';
  end if;

  if v_decision.choice is not null then
    raise exception 'Hai già deciso';
  end if;

  if now() > v_decision.decide_by_at then
    raise exception 'Il tempo per decidere è scaduto';
  end if;

  if p_choice not in ('A', 'B') then
    raise exception 'Scelta non valida';
  end if;

  if p_choice = 'B' then
    update public.winner_decisions
    set choice = 'B', decided_at = now()
    where daily_challenge_id = p_won_challenge_id;
    return;
  end if;

  if p_custom_prompt is null or length(trim(p_custom_prompt)) = 0 then
    raise exception 'Devi scrivere un prompt';
  end if;

  select * into v_won_challenge from public.daily_challenges where id = p_won_challenge_id;
  v_next_date := v_won_challenge.challenge_date + 1;

  select * into v_next_challenge
  from public.daily_challenges
  where circle_id = v_won_challenge.circle_id and challenge_date = v_next_date;

  if v_next_challenge.id is not null then
    select count(*) into v_existing_photo_count
    from public.photos where daily_challenge_id = v_next_challenge.id;

    if v_existing_photo_count > 0 then
      raise exception 'Troppo tardi: qualcuno ha già partecipato al prompt di oggi';
    end if;

    update public.daily_challenges
    set prompt_text = p_custom_prompt, source = 'winner_choice', proposed_by = auth.uid()
    where id = v_next_challenge.id;
  else
    select time_window_minutes into v_time_window_minutes
    from public.circles where id = v_won_challenge.circle_id;

    insert into public.daily_challenges (
      circle_id, challenge_date, prompt_text, source, proposed_by, activation_at, window_end_at, status
    ) values (
      v_won_challenge.circle_id,
      v_next_date,
      p_custom_prompt,
      'winner_choice',
      auth.uid(),
      now(),
      now() + (v_time_window_minutes || ' minutes')::interval,
      'active'
    );
  end if;

  update public.winner_decisions
  set choice = 'A', decided_at = now()
  where daily_challenge_id = p_won_challenge_id;

  insert into public.badges (user_id, circle_id, badge_type, year_month)
  values (auth.uid(), v_won_challenge.circle_id, 'game_master', to_char(now(), 'YYYY-MM'));
end;
$$;

grant execute on function public.submit_winner_choice(uuid, text, text) to authenticated;

-- Chi ha proposto il prompt del giorno (Opzione A) non può partecipare quel giorno.
drop policy if exists photos_insert_self on public.photos;

create policy photos_insert_self on public.photos
  for insert with check (
    user_id = auth.uid()
    and public.is_circle_member((select circle_id from public.daily_challenges where id = daily_challenge_id))
    and (select proposed_by from public.daily_challenges where id = daily_challenge_id) is distinct from user_id
  );
