-- I task party possono differire per genere (stesso campo profiles.gender: 'uomo'/'donna',
-- testo con vincolo, non enum). target_gender null = task neutro, va bene per chiunque
-- (anche per chi ha genere 'altro' o non impostato: "target_gender = r.gender" è per
-- costruzione falso quando r.gender è null, quindi quei partecipanti pescano solo dai
-- neutri, senza bisogno di un caso speciale).
--
-- L'assegnazione non può più essere un unico INSERT...SELECT con due pool mischiati a
-- caso: ogni partecipante ha un pool ammesso diverso (il suo genere + i neutri), quindi
-- si assegna un partecipante alla volta con un loop, tenendo traccia dei task già usati.

alter table public.party_prompts
  add column target_gender text check (target_gender in ('uomo', 'donna'));

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
  v_used_ids uuid[] := '{}';
  v_turn int := 0;
  v_prompt_id uuid;
  v_prompt_text text;
  r record;
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

  for r in
    select cc.user_id, pr.gender
    from public.party_checkins cc
    join public.profiles pr on pr.id = cc.user_id
    where cc.session_id = p_session_id
    order by random()
  loop
    v_turn := v_turn + 1;

    select id, text into v_prompt_id, v_prompt_text
    from public.party_prompts
    where is_seed = true
      and (target_gender is null or target_gender = r.gender)
      and not (id = any (v_used_ids))
    order by random()
    limit 1;

    if v_prompt_id is null then
      raise exception 'Non ci sono abbastanza task party per il genere "%"', coalesce(r.gender, 'non specificato');
    end if;

    insert into public.party_tasks (session_id, assignee_id, prompt_text, turn_order, status, revealed_at)
    values (
      p_session_id,
      r.user_id,
      v_prompt_text,
      v_turn,
      (case when v_turn = 1 then 'revealed' else 'pending' end)::public.party_task_status,
      case when v_turn = 1 then now() else null end
    );

    v_used_ids := array_append(v_used_ids, v_prompt_id);
  end loop;

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
