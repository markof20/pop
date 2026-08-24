-- Il prompt di ogni livello torna a essere unico e condiviso per l'intera cerchia
-- nel giorno: "il livello 1 di oggi è questa domanda, il livello 2 è quest'altra",
-- non più un pescaggio casuale personale per ciascun membro. Chiunque scelga lo
-- stesso livello lo stesso giorno vede la stessa identica domanda.

alter table public.daily_challenges
  add column prompt_text_level1 text,
  add column prompt_text_level2 text;

-- get_active_challenge ora sceglie (una volta sola, alla creazione della sfida del
-- giorno) sia il prompt di livello 1 sia quello di livello 2 per le categorie a
-- livelli, evitando ripetizioni rispetto ai giorni precedenti della stessa cerchia.
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
  v_prompt_l1 text;
  v_prompt_l2 text;
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

    select text into v_prompt_l1
    from public.prompts
    where is_seed = true and category = v_category and level = 1
      and text not in (
        select prompt_text_level1 from public.daily_challenges
        where circle_id = p_circle_id and prompt_text_level1 is not null
      )
    order by random()
    limit 1;

    if v_prompt_l1 is null then
      select text into v_prompt_l1
      from public.prompts
      where is_seed = true and category = v_category and level = 1
      order by random()
      limit 1;
    end if;

    select text into v_prompt_l2
    from public.prompts
    where is_seed = true and category = v_category and level = 2
      and text not in (
        select prompt_text_level2 from public.daily_challenges
        where circle_id = p_circle_id and prompt_text_level2 is not null
      )
    order by random()
    limit 1;

    if v_prompt_l2 is null then
      select text into v_prompt_l2
      from public.prompts
      where is_seed = true and category = v_category and level = 2
      order by random()
      limit 1;
    end if;
  else
    v_prompt_l1 := null;
    v_prompt_l2 := null;

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
    circle_id, challenge_date, prompt_text, source, activation_at, window_end_at, status, prompt_points,
    prompt_text_level1, prompt_text_level2
  ) values (
    p_circle_id,
    current_date,
    v_prompt_text,
    'seed',
    now(),
    now() + (v_time_window_minutes || ' minutes')::interval,
    'active',
    1,
    v_prompt_l1,
    v_prompt_l2
  )
  returning * into v_challenge;

  return v_challenge;
end;
$$;

-- start_my_challenge non pesca più a caso: legge il prompt del livello scelto già
-- deciso per la sfida di oggi (uguale per tutti quelli che scelgono quel livello).
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
  v_challenge public.daily_challenges;
begin
  select * into v_challenge from public.daily_challenges where id = p_daily_challenge_id;
  v_circle_id := v_challenge.circle_id;
  v_source := v_challenge.source;

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

    v_prompt_text := case when p_level = 1 then v_challenge.prompt_text_level1 else v_challenge.prompt_text_level2 end;
    v_level := p_level;
    v_prompt_points := p_level;
  else
    v_prompt_text := v_challenge.prompt_text;
    v_prompt_points := v_challenge.prompt_points;
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
