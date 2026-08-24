-- Modalità GIF BATTLE: asincrona come le sfide giornaliere, non dal vivo come
-- il Party. Una frase viene pescata a caso da una libreria dedicata, ogni
-- membro risponde con una GIF (cercata su Giphy lato client) entro una
-- finestra di tempo, poi si apre una seconda finestra di voto (non si può
-- votare la propria GIF). Niente colonna di stato: la fase si deriva
-- confrontando now() con submission_end_at/voting_end_at, sia lato client
-- che nelle RPC — non serve un'azione "avanza turno" come nel Party.

-- ============================================================
-- TABLES
-- ============================================================

create table public.gif_prompts (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  is_seed boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.gif_sessions (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  started_by uuid not null references public.profiles(id),
  prompt_text text not null,
  submission_end_at timestamptz not null,
  voting_end_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table public.gif_submissions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.gif_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  giphy_id text not null,
  gif_url text not null,
  submitted_at timestamptz not null default now(),
  unique (session_id, user_id)
);

create table public.gif_votes (
  session_id uuid not null references public.gif_sessions(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  submission_id uuid not null references public.gif_submissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (session_id, voter_id)
);

-- ============================================================
-- SEED: libreria di frasi (stesso pattern di prompts/party_prompts)
-- ============================================================

insert into public.gif_prompts (text, is_seed) values
  ('Quando il weekend finisce troppo presto', true),
  ('La tua faccia quando ti dicono "offri tu"', true),
  ('Lunedì mattina alle 7', true),
  ('Quando qualcuno mangia l''ultimo pezzo senza chiedere', true),
  ('Il tuo livello di energia dopo il caffè', true),
  ('Quando il capo scrive "possiamo sentirci 5 minuti?"', true),
  ('La reazione quando scopri che è ancora mercoledì', true),
  ('Quando finalmente esce il sole dopo giorni di pioggia', true),
  ('Il tuo umore prima e dopo aver mangiato', true),
  ('Quando qualcuno rovina il finale di una serie', true),
  ('La faccia che fai quando il wifi cade', true),
  ('Quando trovi un euro dimenticato in tasca', true),
  ('Il tuo stato mentale durante le vacanze', true),
  ('Quando ti chiedono "tutto bene?" e non lo è', true),
  ('La tua reazione al primo sorso di caffè', true),
  ('Quando qualcuno ti copia senza nemmeno cambiare virgola', true),
  ('Il tuo livello di panico prima di una scadenza', true),
  ('Quando finalmente il letto è pronto e ti ci butti', true),
  ('La faccia quando ti accorgi di aver risposto "anche io" a "ti amo"', true),
  ('Quando il gruppo WhatsApp esplode di notifiche', true),
  ('Il tuo entusiasmo il venerdì alle 18', true),
  ('Quando provi a sembrare produttivo davanti al capo', true),
  ('La reazione a "dobbiamo parlare"', true),
  ('Quando qualcuno cammina lentissimo davanti a te', true),
  ('Il tuo livello di sopravvivenza dopo una nottata fuori', true);

-- ============================================================
-- RPC FUNCTIONS (security definer, stesso pattern di party/daily_challenges)
-- ============================================================

-- Avvia un nuovo round: solo admin, solo se non c'è già un round della
-- cerchia ancora in fase di voto o submission (voting_end_at > now()).
create or replace function public.start_gif_session(p_circle_id uuid)
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
  if not public.is_circle_admin(p_circle_id) then
    raise exception 'Solo un admin può avviare un round GIF';
  end if;

  if exists (
    select 1 from public.gif_sessions
    where circle_id = p_circle_id and voting_end_at > now()
  ) then
    raise exception 'C''è già un round GIF in corso per questa cerchia';
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

  insert into public.gif_sessions (circle_id, started_by, prompt_text, submission_end_at, voting_end_at)
  values (
    p_circle_id,
    auth.uid(),
    v_prompt_text,
    now() + (v_time_window_minutes || ' minutes')::interval,
    now() + (2 * v_time_window_minutes || ' minutes')::interval
  )
  returning * into v_session;

  return v_session;
end;
$$;

grant execute on function public.start_gif_session(uuid) to authenticated;

-- Ultimo round della cerchia (in qualunque fase), null se non ce n'è mai stato uno.
create or replace function public.get_active_gif_session(p_circle_id uuid)
returns public.gif_sessions
language sql
security definer
stable
set search_path = public
as $$
  select s.* from public.gif_sessions s
  where s.circle_id = p_circle_id
    and public.is_circle_member(p_circle_id)
  order by s.created_at desc
  limit 1;
$$;

grant execute on function public.get_active_gif_session(uuid) to authenticated;

-- Manda (o cambia, finché la finestra non scade) la propria GIF per il round.
create or replace function public.submit_gif(p_session_id uuid, p_giphy_id text, p_gif_url text)
returns public.gif_submissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_submission_end_at timestamptz;
  v_row public.gif_submissions;
begin
  select circle_id, submission_end_at into v_circle_id, v_submission_end_at
  from public.gif_sessions where id = p_session_id;

  if v_circle_id is null then
    raise exception 'Round non trovato';
  end if;
  if not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;
  if now() >= v_submission_end_at then
    raise exception 'La finestra per mandare la GIF è chiusa';
  end if;

  insert into public.gif_submissions (session_id, user_id, giphy_id, gif_url)
  values (p_session_id, auth.uid(), p_giphy_id, p_gif_url)
  on conflict (session_id, user_id)
    do update set giphy_id = excluded.giphy_id, gif_url = excluded.gif_url, submitted_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.submit_gif(uuid, text, text) to authenticated;

-- Vota una GIF del round (non la propria), modificabile finché il voto è aperto.
create or replace function public.vote_gif(p_session_id uuid, p_submission_id uuid)
returns public.gif_votes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_submission_end_at timestamptz;
  v_voting_end_at timestamptz;
  v_submission_user_id uuid;
  v_row public.gif_votes;
begin
  select circle_id, submission_end_at, voting_end_at into v_circle_id, v_submission_end_at, v_voting_end_at
  from public.gif_sessions where id = p_session_id;

  if v_circle_id is null then
    raise exception 'Round non trovato';
  end if;
  if not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;
  if now() < v_submission_end_at or now() >= v_voting_end_at then
    raise exception 'Il voto non è aperto in questo momento';
  end if;

  select user_id into v_submission_user_id
  from public.gif_submissions
  where id = p_submission_id and session_id = p_session_id;

  if v_submission_user_id is null then
    raise exception 'GIF non trovata in questo round';
  end if;
  if v_submission_user_id = auth.uid() then
    raise exception 'Non puoi votare la tua GIF';
  end if;

  insert into public.gif_votes (session_id, voter_id, submission_id)
  values (p_session_id, auth.uid(), p_submission_id)
  on conflict (session_id, voter_id)
    do update set submission_id = excluded.submission_id, created_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.vote_gif(uuid, uuid) to authenticated;

-- GIF del round con conteggio voti: usata sia in fase di voto (conteggi live)
-- sia per i risultati finali, stessa query.
create or replace function public.get_gif_session_results(p_session_id uuid)
returns table (
  submission_id uuid,
  user_id uuid,
  username text,
  giphy_id text,
  gif_url text,
  vote_count int,
  submitted_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_circle_id uuid;
begin
  select circle_id into v_circle_id from public.gif_sessions where id = p_session_id;
  if v_circle_id is null or not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;

  return query
  select
    s.id as submission_id,
    s.user_id,
    pr.username,
    s.giphy_id,
    s.gif_url,
    count(v.voter_id)::int as vote_count,
    s.submitted_at
  from public.gif_submissions s
  join public.profiles pr on pr.id = s.user_id
  left join public.gif_votes v on v.submission_id = s.id
  where s.session_id = p_session_id
  group by s.id, s.user_id, pr.username, s.giphy_id, s.gif_url, s.submitted_at
  order by vote_count desc, s.submitted_at asc;
end;
$$;

grant execute on function public.get_gif_session_results(uuid) to authenticated;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.gif_prompts enable row level security;
alter table public.gif_sessions enable row level security;
alter table public.gif_submissions enable row level security;
alter table public.gif_votes enable row level security;

-- Nessuna policy di insert/update/delete: tutte le scritture passano dalle
-- funzioni security definer sopra (stesso pattern di party/daily_challenges).

create policy gif_prompts_select on public.gif_prompts
  for select using (auth.role() = 'authenticated');

create policy gif_sessions_select on public.gif_sessions
  for select using (public.is_circle_member(circle_id));

-- Le GIF altrui restano nascoste finché la finestra di submission non è
-- scaduta (stesso principio di party_tasks_select per i task "pending"):
-- solo così nessuno può copiare l'idea di un altro prima di mandare la sua.
create policy gif_submissions_select on public.gif_submissions
  for select using (
    public.is_circle_member((select circle_id from public.gif_sessions where id = session_id))
    and (
      user_id = auth.uid()
      or now() >= (select submission_end_at from public.gif_sessions where id = session_id)
    )
  );

create policy gif_votes_select on public.gif_votes
  for select using (
    public.is_circle_member((select circle_id from public.gif_sessions where id = session_id))
  );
