-- Ripensamento del timing GIF: niente più due finestre sequenziali
-- (submission_end_at/voting_end_at) derivate da circles.time_window_minutes,
-- che con l'impostazione di default (120 min) chiudevano l'intero round in
-- sole 4 ore dalla creazione — troppo poco per chi apre l'app solo una volta
-- al giorno, e comunque diverso da come si comportano le cerchie foto.
--
-- Ora il round GIF si comporta esattamente come la sfida foto: una sola
-- finestra per cerchia per giorno solare (session_date). Puoi mandare la tua
-- GIF in qualunque momento del giorno; una volta mandata, sblocchi la
-- griglia di tutti e puoi votare, sempre in qualunque momento, fino a
-- mezzanotte. Il giorno dopo, chiunque apra la cerchia trova la nuova frase
-- e sopra il risultato di ieri (stesso pattern di get_latest_completed_challenge
-- per le foto).

-- La vecchia policy referenzia submission_end_at: va tolta prima di poter
-- droppare la colonna, altrimenti Postgres rifiuta l'ALTER TABLE.
drop policy if exists gif_submissions_select on public.gif_submissions;

alter table public.gif_sessions drop column submission_end_at;
alter table public.gif_sessions drop column voting_end_at;

create or replace function public.get_active_gif_session(p_circle_id uuid)
returns public.gif_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.gif_sessions;
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

  insert into public.gif_sessions (circle_id, started_by, prompt_text, session_date)
  values (p_circle_id, auth.uid(), v_prompt_text, current_date)
  returning * into v_session;

  return v_session;
end;
$$;

grant execute on function public.get_active_gif_session(uuid) to authenticated;

-- Round di ieri (o l'ultimo passato), per il banner "risultato di ieri" —
-- stesso pattern di get_latest_completed_challenge.
create or replace function public.get_latest_completed_gif_session(p_circle_id uuid)
returns public.gif_sessions
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_row public.gif_sessions;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;

  select * into v_row
  from public.gif_sessions
  where circle_id = p_circle_id and session_date < current_date
  order by session_date desc
  limit 1;

  if v_row.id is null then
    return null;
  end if;

  return v_row;
end;
$$;

grant execute on function public.get_latest_completed_gif_session(uuid) to authenticated;

-- Si può mandare la GIF in qualunque momento del round di oggi (non più
-- entro una scadenza calcolata dalla finestra della cerchia).
create or replace function public.submit_gif(p_session_id uuid, p_giphy_id text, p_gif_url text)
returns public.gif_submissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_session_date date;
  v_row public.gif_submissions;
begin
  select circle_id, session_date into v_circle_id, v_session_date
  from public.gif_sessions where id = p_session_id;

  if v_circle_id is null then
    raise exception 'Round non trovato';
  end if;
  if not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;
  if v_session_date <> current_date then
    raise exception 'Il round di questo giorno è chiuso';
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

-- Si può votare in qualunque momento del round di oggi (non più solo dopo
-- la chiusura della submission); resta modificabile.
create or replace function public.vote_gif(p_session_id uuid, p_submission_id uuid)
returns public.gif_votes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_session_date date;
  v_submission_user_id uuid;
  v_row public.gif_votes;
begin
  select circle_id, session_date into v_circle_id, v_session_date
  from public.gif_sessions where id = p_session_id;

  if v_circle_id is null then
    raise exception 'Round non trovato';
  end if;
  if not public.is_circle_member(v_circle_id) then
    raise exception 'Non sei membro di questa cerchia';
  end if;
  if v_session_date <> current_date then
    raise exception 'Il voto per questo round è chiuso';
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

-- Non c'è più una finestra di submission che nasconde le GIF altrui: come le
-- foto (photos_select), la visibilità è solo "sei membro della cerchia" — lo
-- sblocco "manda la tua prima di vedere le altre" resta, ma solo lato client
-- (stesso pattern di usePhotos), non più una garanzia lato DB.
create policy gif_submissions_select on public.gif_submissions
  for select using (
    public.is_circle_member((select circle_id from public.gif_sessions where id = session_id))
  );
