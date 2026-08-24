-- Ripensamento della modalità GIF: non è un mini-gioco opzionale come Party,
-- è un tipo di cerchia a sé stante (circle_type 'gif' vs 'photo') che sostituisce
-- l'intero ciclo giornaliero prompt+foto+voto con frase+gif+voto. Di conseguenza
-- il round non lo avvia più a mano l'admin: si genera da solo un round al giorno
-- per cerchia, esattamente come get_active_challenge fa per le foto.

alter table public.circles
  add column circle_type text not null default 'photo' check (circle_type in ('photo', 'gif'));

alter table public.gif_sessions
  add column session_date date not null default current_date;

alter table public.gif_sessions
  add constraint gif_sessions_circle_date_unique unique (circle_id, session_date);

drop function if exists public.start_gif_session(uuid);

-- Round di oggi per la cerchia, creandolo se non esiste ancora (stesso pattern
-- lazy di get_active_challenge). Non più riservato all'admin: chiunque apra
-- per primo la cerchia quel giorno fa scattare la creazione.
create or replace function public.get_active_gif_session(p_circle_id uuid)
returns public.gif_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.gif_sessions;
  v_time_window_minutes int;
  v_prompt_text text;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;

  select * into v_session
  from public.gif_sessions
  where circle_id = p_circle_id and session_date = current_date;

  if v_session.id is not null then
    return v_session;
  end if;

  select time_window_minutes into v_time_window_minutes
  from public.circles where id = p_circle_id;

  select text into v_prompt_text
  from public.gif_prompts
  where is_seed = true
    and text not in (
      select prompt_text from public.gif_sessions where circle_id = p_circle_id
    )
  order by random()
  limit 1;

  if v_prompt_text is null then
    select text into v_prompt_text from public.gif_prompts where is_seed = true order by random() limit 1;
  end if;

  insert into public.gif_sessions (
    circle_id, started_by, prompt_text, session_date, submission_end_at, voting_end_at
  ) values (
    p_circle_id,
    auth.uid(),
    v_prompt_text,
    current_date,
    now() + (v_time_window_minutes || ' minutes')::interval,
    now() + (2 * v_time_window_minutes || ' minutes')::interval
  )
  returning * into v_session;

  return v_session;
end;
$$;

grant execute on function public.get_active_gif_session(uuid) to authenticated;

-- create_circle ora accetta anche il tipo di cerchia fin dalla creazione.
-- Il vecchio create_circle(text, int, text) va rimosso esplicitamente: essendo
-- il numero di parametri diverso, "create or replace" lo lascerebbe come
-- overload separato invece di sostituirlo, creando ambiguità nelle chiamate RPC.
drop function if exists public.create_circle(text, int, text);

create or replace function public.create_circle(
  p_name text,
  p_time_window_minutes int default 120,
  p_category text default 'normal',
  p_circle_type text default 'photo'
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
  if p_circle_type not in ('photo', 'gif') then
    raise exception 'Tipo di cerchia non valido';
  end if;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.circles (name, invite_code, time_window_minutes, category, circle_type, created_by)
  values (p_name, v_code, p_time_window_minutes, p_category, p_circle_type, auth.uid())
  returning * into v_circle;

  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle.id, auth.uid(), 'admin');

  insert into public.group_streaks (circle_id)
  values (v_circle.id);

  return v_circle;
end;
$$;

grant execute on function public.create_circle(text, int, text, text) to authenticated;
