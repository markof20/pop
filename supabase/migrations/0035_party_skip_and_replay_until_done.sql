-- Redesign delle meccaniche party:
-- - all'avvio del round si crea SUBITO l'intera matrice (partecipante x task
--   ammesso per il suo genere), non un solo task a testa: la sessione va avanti
--   finché ogni partecipante non ha fatto (o saltato-poi-fatto) ogni suo task.
-- - l'assegnatario può saltare il task corrente UNA sola volta per quella coppia
--   (partecipante, task): torna in circolo con status 'skipped' e può essere
--   ripescato più avanti; se ricapita a lui, non può più saltarlo.
-- - "turn_order" sparisce: il prossimo task è scelto a caso tra quelli ancora
--   non completati (pending o skipped), non più per indice sequenziale.
-- - la classifica ora aggrega per partecipante (tanti task completati a testa),
--   non più una riga per task.

alter table public.party_tasks
  drop constraint party_tasks_session_id_assignee_id_key,
  drop constraint party_tasks_session_id_turn_order_key,
  drop column turn_order,
  add column prompt_id uuid references public.party_prompts(id),
  add column skipped boolean not null default false,
  add constraint party_tasks_session_assignee_prompt_key unique (session_id, assignee_id, prompt_id);

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
  v_session public.party_sessions;
  v_first_task_id uuid;
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

  insert into public.party_tasks (session_id, assignee_id, prompt_id, prompt_text, status)
  select p_session_id, cc.user_id, pp.id, pp.text, 'pending'
  from public.party_checkins cc
  join public.profiles pr on pr.id = cc.user_id
  cross join public.party_prompts pp
  where cc.session_id = p_session_id
    and pp.is_seed = true
    and (pp.target_gender is null or pp.target_gender = pr.gender);

  if not exists (select 1 from public.party_tasks where session_id = p_session_id) then
    raise exception 'Nessun task disponibile per i partecipanti presenti (controlla la libreria party_prompts)';
  end if;

  select id into v_first_task_id
  from public.party_tasks
  where session_id = p_session_id and status = 'pending'
  order by random()
  limit 1;

  update public.party_tasks
  set status = 'revealed', revealed_at = now()
  where id = v_first_task_id;

  update public.party_sessions
  set status = 'active', current_task_id = v_first_task_id
  where id = p_session_id;

  select * into v_session from public.party_sessions where id = p_session_id;
  return v_session;
end;
$$;

grant execute on function public.start_party_round(uuid) to authenticated;

-- Solo l'assegnatario, solo mentre il task è "revealed", solo se non l'ha già
-- saltato una volta in precedenza per questa stessa coppia (partecipante, task).
create or replace function public.skip_task(p_task_id uuid)
returns public.party_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.party_tasks;
begin
  select * into v_task from public.party_tasks where id = p_task_id;
  if v_task.id is null then
    raise exception 'Task non trovato';
  end if;
  if auth.uid() <> v_task.assignee_id then
    raise exception 'Solo chi deve eseguire il task può saltarlo';
  end if;
  if v_task.status <> 'revealed' then
    raise exception 'Questo task non è nella fase corretta per essere saltato';
  end if;
  if v_task.skipped then
    raise exception 'Hai già saltato questo task una volta: adesso va eseguito';
  end if;

  update public.party_tasks
  set status = 'skipped', skipped = true
  where id = p_task_id
  returning * into v_task;

  return v_task;
end;
$$;

grant execute on function public.skip_task(uuid) to authenticated;

-- L'admin avanza dopo un completamento (con voti) o dopo uno skip. Il prossimo
-- task è scelto a caso tra quelli non ancora completati (pending o skipped),
-- evitando se possibile di ripresentare subito quello appena risolto. La
-- sessione finisce solo quando non resta più nessun task non completato.
create or replace function public.advance_party_round(p_session_id uuid)
returns public.party_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.party_sessions;
  v_current public.party_tasks;
  v_next_id uuid;
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
  if v_current.id is null or v_current.status not in ('completed', 'skipped') then
    raise exception 'Il task corrente deve essere completato o saltato prima di avanzare';
  end if;

  select id into v_next_id
  from public.party_tasks
  where session_id = p_session_id and status in ('pending', 'skipped') and id <> v_current.id
  order by random()
  limit 1;

  if v_next_id is null then
    select id into v_next_id
    from public.party_tasks
    where session_id = p_session_id and status in ('pending', 'skipped')
    order by random()
    limit 1;
  end if;

  if v_next_id is not null then
    update public.party_tasks
    set status = 'revealed', revealed_at = now()
    where id = v_next_id;

    update public.party_sessions
    set current_task_id = v_next_id
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

-- Classifica aggregata per partecipante (ora ognuno completa molti task, non uno solo).
-- La forma delle colonne di ritorno è cambiata: create or replace da solo non basta.
drop function if exists public.get_party_leaderboard(uuid);

create or replace function public.get_party_leaderboard(p_session_id uuid)
returns table (
  assignee_id uuid,
  username text,
  tasks_completed int,
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
    t.assignee_id,
    pr.username,
    count(*)::int as tasks_completed,
    coalesce(sum(case when r.value = 1 then 1 else 0 end), 0)::int as upvotes,
    coalesce(sum(case when r.value = -1 then 1 else 0 end), 0)::int as downvotes,
    coalesce(sum(r.value), 0)::int as net_score
  from public.party_tasks t
  join public.profiles pr on pr.id = t.assignee_id
  left join public.party_ratings r on r.task_id = t.id
  where t.session_id = p_session_id and t.status = 'completed'
  group by t.assignee_id, pr.username
  order by net_score desc, upvotes desc, pr.username asc;
end;
$$;

grant execute on function public.get_party_leaderboard(uuid) to authenticated;
