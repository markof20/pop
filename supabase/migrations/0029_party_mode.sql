-- Modalità PARTY: sessione dal vivo, in presenza. Un admin la avvia, i membri
-- fisicamente presenti fanno check-in, poi a ciascuno viene assegnato un task
-- diverso (pescato senza ripetizioni dalla libreria party_prompts). I task
-- vengono rivelati uno alla volta in ordine casuale: mentre un task è
-- "pending" nessuno lo vede (nemmeno l'assegnatario), così l'ordine resta a
-- sorpresa. Quando tocca il suo turno il task diventa "revealed" a tutti;
-- gli altri membri (non l'assegnatario) lo segnano come completato dal vivo,
-- e alla maggioranza dei voti diventa "completed" e si apre la votazione
-- +1/-1. L'admin avanza al turno successivo quando è pronto. Classifica
-- finale = somma dei voti ricevuti (net_score).

-- ============================================================
-- ENUMS
-- ============================================================
create type public.party_session_status as enum ('checkin', 'active', 'completed');
create type public.party_task_status as enum ('pending', 'revealed', 'completed');

-- ============================================================
-- TABLES
-- ============================================================

-- Libreria dei task party: is_seed = true per i task di libreria condivisa
-- (stesso pattern di public.prompts). Da popolare con l'elenco fornito
-- separatamente: qui la tabella nasce vuota.
create table public.party_prompts (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  is_seed boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.party_sessions (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  started_by uuid not null references public.profiles(id),
  status public.party_session_status not null default 'checkin',
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- Una sola sessione non completata (checkin o active) alla volta per cerchia:
-- rete di sicurezza a livello DB oltre al controllo applicativo in start_party_session.
create unique index party_sessions_one_active_per_circle
  on public.party_sessions (circle_id)
  where status <> 'completed';

create table public.party_checkins (
  session_id uuid not null references public.party_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  primary key (session_id, user_id)
);

create table public.party_tasks (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.party_sessions(id) on delete cascade,
  assignee_id uuid not null references public.profiles(id) on delete cascade,
  prompt_text text not null,
  turn_order int not null,
  status public.party_task_status not null default 'pending',
  revealed_at timestamptz,
  completed_at timestamptz,
  unique (session_id, assignee_id),
  unique (session_id, turn_order)
);

-- Turno corrente della sessione: aggiunta dopo party_tasks per la FK incrociata.
alter table public.party_sessions
  add column current_task_id uuid references public.party_tasks(id) on delete set null;

create table public.party_completion_votes (
  task_id uuid not null references public.party_tasks(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  voted_at timestamptz not null default now(),
  primary key (task_id, voter_id)
);

create table public.party_ratings (
  task_id uuid not null references public.party_tasks(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  value int not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (task_id, voter_id)
);

-- ============================================================
-- RPC FUNCTIONS (security definer, stesso pattern delle daily_challenges)
-- ============================================================

-- Avvia una nuova sessione in fase di check-in. Solo un admin della cerchia,
-- e solo se non ce n'è già una in corso (checkin o active).
create or replace function public.start_party_session(p_circle_id uuid)
returns public.party_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.party_sessions;
begin
  if not public.is_circle_admin(p_circle_id) then
    raise exception 'Solo un admin può avviare una sessione party';
  end if;

  if exists (
    select 1 from public.party_sessions
    where circle_id = p_circle_id and status in ('checkin', 'active')
  ) then
    raise exception 'C''è già una sessione party in corso per questa cerchia';
  end if;

  insert into public.party_sessions (circle_id, started_by, status)
  values (p_circle_id, auth.uid(), 'checkin')
  returning * into v_session;

  return v_session;
end;
$$;

grant execute on function public.start_party_session(uuid) to authenticated;

-- Sessione checkin/active corrente della cerchia, se esiste (per il polling client).
create or replace function public.get_active_party_session(p_circle_id uuid)
returns public.party_sessions
language sql
security definer
stable
set search_path = public
as $$
  select s.* from public.party_sessions s
  where s.circle_id = p_circle_id
    and s.status in ('checkin', 'active')
    and public.is_circle_member(p_circle_id)
  order by s.created_at desc
  limit 1;
$$;

grant execute on function public.get_active_party_session(uuid) to authenticated;

-- Un membro fisicamente presente si registra alla sessione durante il check-in.
create or replace function public.party_checkin(p_session_id uuid)
returns public.party_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_status public.party_session_status;
  v_row public.party_checkins;
begin
  select circle_id, status into v_circle_id, v_status
  from public.party_sessions where id = p_session_id;

  if v_circle_id is null then
    raise exception 'Sessione non trovata';
  end if;
  if not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;
  if v_status <> 'checkin' then
    raise exception 'Il check-in per questa sessione è chiuso';
  end if;

  insert into public.party_checkins (session_id, user_id)
  values (p_session_id, auth.uid())
  on conflict (session_id, user_id) do nothing;

  select * into v_row from public.party_checkins
  where session_id = p_session_id and user_id = auth.uid();

  return v_row;
end;
$$;

grant execute on function public.party_checkin(uuid) to authenticated;

-- Chiude il check-in, assegna a ogni presente un task distinto in ordine
-- casuale e rivela il primo turno. Solo l'admin.
create or replace function public.start_party_round(p_session_id uuid)
returns public.party_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_status public.party_session_status;
  v_participant_count int;
  v_prompt_count int;
begin
  select circle_id, status into v_circle_id, v_status
  from public.party_sessions where id = p_session_id;

  if v_circle_id is null then
    raise exception 'Sessione non trovata';
  end if;
  if not public.is_circle_admin(v_circle_id) then
    raise exception 'Solo un admin può avviare il round';
  end if;
  if v_status <> 'checkin' then
    raise exception 'La sessione non è in fase di check-in';
  end if;

  select count(*) into v_participant_count
  from public.party_checkins where session_id = p_session_id;

  if v_participant_count < 2 then
    raise exception 'Servono almeno 2 partecipanti per iniziare';
  end if;

  select count(*) into v_prompt_count from public.party_prompts where is_seed = true;
  if v_prompt_count < v_participant_count then
    raise exception 'Non ci sono abbastanza task nella libreria party per tutti i partecipanti';
  end if;

  with shuffled_participants as (
    select user_id, row_number() over (order by random()) as turn_order
    from public.party_checkins
    where session_id = p_session_id
  ),
  shuffled_prompts as (
    select text, row_number() over (order by random()) as rn
    from public.party_prompts
    where is_seed = true
  )
  insert into public.party_tasks (session_id, assignee_id, prompt_text, turn_order, status, revealed_at)
  select
    p_session_id,
    sp.user_id,
    spr.text,
    sp.turn_order,
    case when sp.turn_order = 1 then 'revealed' else 'pending' end,
    case when sp.turn_order = 1 then now() else null end
  from shuffled_participants sp
  join shuffled_prompts spr on spr.rn = sp.turn_order;

  update public.party_sessions
  set status = 'active',
      current_task_id = (
        select id from public.party_tasks
        where session_id = p_session_id and turn_order = 1
      )
  where id = p_session_id;

  return (select * from public.party_sessions where id = p_session_id);
end;
$$;

grant execute on function public.start_party_round(uuid) to authenticated;

-- Un membro presente (non l'assegnatario) segna il task corrente come
-- eseguito dal vivo. Alla maggioranza dei presenti idonei, il task passa a
-- "completed" e si apre la votazione.
create or replace function public.mark_task_done(p_task_id uuid)
returns public.party_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.party_tasks;
  v_circle_id uuid;
  v_eligible_voters int;
  v_votes int;
begin
  select * into v_task from public.party_tasks where id = p_task_id;
  if v_task.id is null then
    raise exception 'Task non trovato';
  end if;

  select circle_id into v_circle_id from public.party_sessions where id = v_task.session_id;
  if not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;
  if auth.uid() = v_task.assignee_id then
    raise exception 'Non puoi votare il tuo task';
  end if;
  if v_task.status <> 'revealed' then
    raise exception 'Il task non è nella fase di completamento';
  end if;
  if not exists (
    select 1 from public.party_checkins
    where session_id = v_task.session_id and user_id = auth.uid()
  ) then
    raise exception 'Devi aver fatto il check-in alla sessione';
  end if;

  insert into public.party_completion_votes (task_id, voter_id)
  values (p_task_id, auth.uid())
  on conflict (task_id, voter_id) do nothing;

  select count(*) into v_eligible_voters
  from public.party_checkins
  where session_id = v_task.session_id and user_id <> v_task.assignee_id;

  select count(*) into v_votes
  from public.party_completion_votes
  where task_id = p_task_id;

  if v_votes * 2 > v_eligible_voters then
    update public.party_tasks
    set status = 'completed', completed_at = now()
    where id = p_task_id and status = 'revealed';
  end if;

  select * into v_task from public.party_tasks where id = p_task_id;
  return v_task;
end;
$$;

grant execute on function public.mark_task_done(uuid) to authenticated;

-- Voto +1/-1 su un task completato. Non l'assegnatario. Modificabile (upsert).
create or replace function public.rate_task(p_task_id uuid, p_value int)
returns public.party_ratings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.party_tasks;
  v_circle_id uuid;
  v_row public.party_ratings;
begin
  if p_value not in (-1, 1) then
    raise exception 'Valore voto non valido';
  end if;

  select * into v_task from public.party_tasks where id = p_task_id;
  if v_task.id is null then
    raise exception 'Task non trovato';
  end if;

  select circle_id into v_circle_id from public.party_sessions where id = v_task.session_id;
  if not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;
  if auth.uid() = v_task.assignee_id then
    raise exception 'Non puoi votare il tuo task';
  end if;
  if v_task.status <> 'completed' then
    raise exception 'Il task non è ancora stato completato';
  end if;
  if not exists (
    select 1 from public.party_checkins
    where session_id = v_task.session_id and user_id = auth.uid()
  ) then
    raise exception 'Devi aver fatto il check-in alla sessione';
  end if;

  insert into public.party_ratings (task_id, voter_id, value)
  values (p_task_id, auth.uid(), p_value)
  on conflict (task_id, voter_id) do update set value = excluded.value, created_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.rate_task(uuid, int) to authenticated;

-- L'admin avanza al turno successivo (richiede che il turno corrente sia
-- "completed"); se non ci sono altri task la sessione si chiude.
create or replace function public.advance_party_round(p_session_id uuid)
returns public.party_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.party_sessions;
  v_current public.party_tasks;
  v_next public.party_tasks;
begin
  select * into v_session from public.party_sessions where id = p_session_id;
  if v_session.id is null then
    raise exception 'Sessione non trovata';
  end if;
  if not public.is_circle_admin(v_session.circle_id) then
    raise exception 'Solo un admin può avanzare il round';
  end if;
  if v_session.status <> 'active' then
    raise exception 'La sessione non è attiva';
  end if;

  select * into v_current from public.party_tasks where id = v_session.current_task_id;
  if v_current.id is null or v_current.status <> 'completed' then
    raise exception 'Il task corrente deve essere completato prima di avanzare';
  end if;

  select * into v_next
  from public.party_tasks
  where session_id = p_session_id and turn_order > v_current.turn_order
  order by turn_order asc
  limit 1;

  if v_next.id is not null then
    update public.party_tasks
    set status = 'revealed', revealed_at = now()
    where id = v_next.id;

    update public.party_sessions
    set current_task_id = v_next.id
    where id = p_session_id;
  else
    update public.party_sessions
    set status = 'completed', completed_at = now(), current_task_id = null
    where id = p_session_id;
  end if;

  select * into v_session from public.party_sessions where id = p_session_id;
  return v_session;
end;
$$;

grant execute on function public.advance_party_round(uuid) to authenticated;

-- Classifica finale della sessione: net_score = upvotes - downvotes.
create or replace function public.get_party_leaderboard(p_session_id uuid)
returns table (
  task_id uuid,
  assignee_id uuid,
  username text,
  prompt_text text,
  turn_order int,
  upvotes int,
  downvotes int,
  net_score int
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_circle_id uuid;
begin
  select circle_id into v_circle_id from public.party_sessions where id = p_session_id;
  if v_circle_id is null or not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;

  return query
  select
    t.id as task_id,
    t.assignee_id,
    pr.username,
    t.prompt_text,
    t.turn_order,
    coalesce(sum(case when r.value = 1 then 1 else 0 end), 0)::int as upvotes,
    coalesce(sum(case when r.value = -1 then 1 else 0 end), 0)::int as downvotes,
    coalesce(sum(r.value), 0)::int as net_score
  from public.party_tasks t
  join public.profiles pr on pr.id = t.assignee_id
  left join public.party_ratings r on r.task_id = t.id
  where t.session_id = p_session_id
  group by t.id, t.assignee_id, pr.username, t.prompt_text, t.turn_order
  order by net_score desc, upvotes desc, t.turn_order asc;
end;
$$;

grant execute on function public.get_party_leaderboard(uuid) to authenticated;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.party_prompts enable row level security;
alter table public.party_sessions enable row level security;
alter table public.party_checkins enable row level security;
alter table public.party_tasks enable row level security;
alter table public.party_completion_votes enable row level security;
alter table public.party_ratings enable row level security;

-- Nessuna policy di insert/update/delete su queste tabelle: tutte le
-- scritture passano dalle funzioni security definer sopra, che bypassano
-- la RLS (stesso pattern di daily_challenges/photos).

create policy party_prompts_select on public.party_prompts
  for select using (auth.role() = 'authenticated');

create policy party_sessions_select on public.party_sessions
  for select using (public.is_circle_member(circle_id));

create policy party_checkins_select on public.party_checkins
  for select using (
    public.is_circle_member((select circle_id from public.party_sessions where id = session_id))
  );

-- I task "pending" (turni futuri) restano invisibili a chiunque, assegnatario
-- incluso: solo così l'ordine di rivelazione resta a sorpresa.
create policy party_tasks_select on public.party_tasks
  for select using (
    status <> 'pending'
    and public.is_circle_member((select circle_id from public.party_sessions where id = session_id))
  );

create policy party_completion_votes_select on public.party_completion_votes
  for select using (
    public.is_circle_member((
      select s.circle_id from public.party_sessions s
      join public.party_tasks t on t.session_id = s.id
      where t.id = task_id
    ))
  );

create policy party_ratings_select on public.party_ratings
  for select using (
    public.is_circle_member((
      select s.circle_id from public.party_sessions s
      join public.party_tasks t on t.session_id = s.id
      where t.id = task_id
    ))
  );
