-- L'admin deve poter chiudere la sessione party anche a metà (es. il gruppo si scioglie
-- prima di esaurire tutti i turni), non solo quando i turni finiscono naturalmente.
-- Riusa lo status 'completed': i task non ancora completati restano fuori da
-- get_party_leaderboard, che già filtra su status = 'completed'.

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
