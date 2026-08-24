-- La GIF inviata è definitiva: niente più "cambia gif" (tolto anche dalla UI).
-- Prima era un upsert silenzioso; ora un secondo invio viene rifiutato esplicitamente,
-- così la regola vale per chiunque chiami la RPC, non solo per chi passa dalla UI.

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
  if exists (
    select 1 from public.gif_submissions
    where session_id = p_session_id and user_id = auth.uid()
  ) then
    raise exception 'Hai già mandato la tua GIF per questo round';
  end if;

  insert into public.gif_submissions (session_id, user_id, giphy_id, gif_url)
  values (p_session_id, auth.uid(), p_giphy_id, p_gif_url)
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.submit_gif(uuid, text, text) to authenticated;
