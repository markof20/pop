-- Fase 2: attivazione lazy del prompt del giorno, calcolo server-side del ritardo,
-- possibilità di cambiare il proprio top pick.

-- Restituisce la sfida attiva di oggi per la cerchia, creandola se non esiste ancora.
create or replace function public.get_active_challenge(p_circle_id uuid)
returns public.daily_challenges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.daily_challenges;
  v_time_window_minutes int;
  v_prompt_text text;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select * into v_challenge
  from public.daily_challenges
  where circle_id = p_circle_id and challenge_date = current_date;

  if v_challenge.id is not null then
    return v_challenge;
  end if;

  select time_window_minutes into v_time_window_minutes
  from public.circles where id = p_circle_id;

  select text into v_prompt_text
  from public.prompts
  where is_seed = true
    and text not in (
      select prompt_text from public.daily_challenges where circle_id = p_circle_id
    )
  order by random()
  limit 1;

  if v_prompt_text is null then
    select text into v_prompt_text from public.prompts where is_seed = true order by random() limit 1;
  end if;

  insert into public.daily_challenges (
    circle_id, challenge_date, prompt_text, source, activation_at, window_end_at, status
  ) values (
    p_circle_id,
    current_date,
    v_prompt_text,
    'seed',
    now(),
    now() + (v_time_window_minutes || ' minutes')::interval,
    'active'
  )
  returning * into v_challenge;

  return v_challenge;
end;
$$;

grant execute on function public.get_active_challenge(uuid) to authenticated;

-- Il client non deve poter falsificare il ritardo: uploaded_at e is_late sono calcolati qui.
create or replace function public.compute_photo_lateness()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_window_end timestamptz;
begin
  select window_end_at into v_window_end
  from public.daily_challenges where id = new.daily_challenge_id;

  new.uploaded_at := now();
  new.is_late := now() > v_window_end;
  return new;
end;
$$;

create trigger trg_compute_photo_lateness
  before insert on public.photos
  for each row execute procedure public.compute_photo_lateness();

-- Permette di cambiare il proprio top pick (delete + insert lato client) prima della rivelazione dei risultati.
create policy top_picks_delete_self on public.top_picks
  for delete using (voter_id = auth.uid());
