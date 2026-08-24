-- Due problemi trovati ispezionando il database live:
-- 1) start_party_round: l'ultima riga faceva "return (select * from ...)", un
--    subquery multi-colonna usato come valore di ritorno diretto — non ammesso da
--    Postgres ("subquery must return only one column"). Va passato da una variabile
--    riga. Bug presente fin da 0029, mascherato dall'errore di cast risolto in 0031.
-- 2) mark_task_done, rate_task (0029) ed end_party_session (0030) risultano assenti
--    dal database: li ricreiamo qui per riallinearlo ai file di migrazione.

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
  v_session public.party_sessions;
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
    (case when sp.turn_order = 1 then 'revealed' else 'pending' end)::public.party_task_status,
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

  select * into v_session from public.party_sessions where id = p_session_id;
  return v_session;
end;
$$;

grant execute on function public.start_party_round(uuid) to authenticated;

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

create or replace function public.end_party_session(p_session_id uuid)
returns public.party_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.party_sessions;
begin
  select * into v_session from public.party_sessions where id = p_session_id;
  if v_session.id is null then
    raise exception 'Sessione non trovata';
  end if;
  if not public.is_circle_admin(v_session.circle_id) then
    raise exception 'Solo un admin può chiudere la sessione party';
  end if;
  if v_session.status = 'completed' then
    raise exception 'Questa sessione è già chiusa';
  end if;

  update public.party_sessions
  set status = 'completed', completed_at = now(), current_task_id = null
  where id = p_session_id
  returning * into v_session;

  return v_session;
end;
$$;

grant execute on function public.end_party_session(uuid) to authenticated;
