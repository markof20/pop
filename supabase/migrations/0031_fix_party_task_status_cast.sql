-- Bug: dentro una CASE, i letterali 'revealed'/'pending' vengono tipizzati come
-- text semplice da Postgres; assegnarli a una colonna enum (party_task_status)
-- via INSERT ... SELECT fallisce con "column status is of type party_task_status
-- but expression is of type text" perché non esiste un cast implicito text->enum.
-- Basta un cast esplicito sull'espressione CASE.

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

  return (select * from public.party_sessions where id = p_session_id);
end;
$$;

grant execute on function public.start_party_round(uuid) to authenticated;
