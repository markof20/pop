-- Estende il sistema a livelli, finora esclusivo di "hot", anche ad "amici".
-- Invece di aggiungere una seconda colonna dedicata (amici_level), generalizzo
-- hot_level in circles.level: si applica a qualunque categoria "leveled"
-- (per ora hot e amici), viene ignorata per normal.

alter table public.circles
  add column level int not null default 1 check (level in (1, 2));

update public.circles set level = hot_level;

alter table public.circles
  drop column hot_level;

-- Amici livello 2 (2 punti): stesso spirito del livello 1, ma più profondo/vulnerabile
-- invece che più leggero — resta comunque tutto adatto a qualsiasi cerchia di amici.
insert into public.prompts (text, is_seed, category, level) values
  ('Una foto di qualcosa che non hai mai mostrato a nessuno del gruppo', true, 'amici', 2),
  ('Il tuo posto sicuro quando hai una brutta giornata, fotografato adesso', true, 'amici', 2),
  ('Qualcosa che rappresenta una paura che non hai mai confessato al gruppo', true, 'amici', 2),
  ('Una prova fotografica di quanto sei cambiato/a da quando conosci questa cerchia', true, 'amici', 2),
  ('Il messaggio che non hai mai avuto il coraggio di mandare nella chat, scritto su carta (senza inviarlo)', true, 'amici', 2),
  ('Qualcosa che terresti anche se il gruppo si sciogliesse domani', true, 'amici', 2),
  ('Il tuo momento più imbarazzante vissuto con la cerchia, ricreato con oggetti', true, 'amici', 2),
  ('Una foto di ciò che faresti se uno del gruppo avesse bisogno di te alle 3 di notte', true, 'amici', 2),
  ('L''oggetto che ti ricorda la persona della cerchia che ammiri di più', true, 'amici', 2),
  ('Il tuo "io" di 5 anni fa che reagisce a questa cerchia: ricrea l''espressione', true, 'amici', 2),
  ('Una prova che ti fideresti di questo gruppo con un segreto vero', true, 'amici', 2),
  ('Il ricordo più vulnerabile condiviso con la cerchia, rappresentato con un oggetto', true, 'amici', 2),
  ('Qualcosa che faresti solo se sapessi che nessuno ti giudica', true, 'amici', 2),
  ('Un "grazie" mai detto a qualcuno del gruppo, scritto e fotografato', true, 'amici', 2),
  ('La versione di te che il gruppo non ha mai visto, in un solo oggetto', true, 'amici', 2)
on conflict do nothing;

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
  v_level int;
  v_prompt_points int;
  v_prompt_text text;
  v_prev_challenge public.daily_challenges;
  v_winner_user_id uuid;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select time_window_minutes, category, level
    into v_time_window_minutes, v_category, v_level
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

  v_prompt_points := case when v_category in ('amici', 'hot') then v_level else 1 end;

  select text into v_prompt_text
  from public.prompts
  where is_seed = true
    and category = v_category
    and (v_category not in ('amici', 'hot') or level = v_level)
    and text not in (
      select prompt_text from public.daily_challenges where circle_id = p_circle_id
    )
  order by random()
  limit 1;

  if v_prompt_text is null then
    select text into v_prompt_text
    from public.prompts
    where is_seed = true
      and category = v_category
      and (v_category not in ('amici', 'hot') or level = v_level)
    order by random()
    limit 1;
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
    v_prompt_points
  )
  returning * into v_challenge;

  return v_challenge;
end;
$$;

-- create_circle accetta ora anche il livello iniziale (stesso motivo della categoria:
-- evitare che la prima sfida nasca a livello 1 per poi doverla correggere a mano).
create or replace function public.create_circle(
  p_name text,
  p_time_window_minutes int default 120,
  p_category text default 'normal',
  p_level int default 1
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

  if p_level not in (1, 2) then
    raise exception 'Livello non valido';
  end if;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.circles (name, invite_code, time_window_minutes, category, level, created_by)
  values (p_name, v_code, p_time_window_minutes, p_category, p_level, auth.uid())
  returning * into v_circle;

  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle.id, auth.uid(), 'admin');

  insert into public.group_streaks (circle_id)
  values (v_circle.id);

  return v_circle;
end;
$$;
