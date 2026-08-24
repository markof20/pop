-- Ogni membro ha il proprio timer personale: la finestra per scattare parte
-- quando LUI vede per la prima volta il prompt del giorno, non quando il primo
-- membro della cerchia apre l'app. Il prompt resta condiviso (daily_challenges),
-- ma la scadenza personale vive in questa nuova tabella.

create table public.challenge_participants (
  daily_challenge_id uuid not null references public.daily_challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  started_at timestamptz not null default now(),
  window_end_at timestamptz not null,
  primary key (daily_challenge_id, user_id)
);

alter table public.challenge_participants enable row level security;

create policy challenge_participants_select on public.challenge_participants
  for select using (
    public.is_circle_member((select circle_id from public.daily_challenges where id = daily_challenge_id))
  );

-- Registra (se non già presente) l'inizio del timer personale dell'utente per la sfida
-- e restituisce sempre la riga corrente (creata al primo accesso, invariata dopo).
create or replace function public.start_my_challenge(p_daily_challenge_id uuid)
returns public.challenge_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.challenge_participants;
  v_circle_id uuid;
  v_time_window_minutes int;
begin
  select circle_id into v_circle_id from public.daily_challenges where id = p_daily_challenge_id;

  if v_circle_id is null or not public.is_circle_member(v_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select time_window_minutes into v_time_window_minutes from public.circles where id = v_circle_id;

  insert into public.challenge_participants (daily_challenge_id, user_id, started_at, window_end_at)
  values (p_daily_challenge_id, auth.uid(), now(), now() + (v_time_window_minutes || ' minutes')::interval)
  on conflict (daily_challenge_id, user_id) do nothing;

  select * into v_row from public.challenge_participants
  where daily_challenge_id = p_daily_challenge_id and user_id = auth.uid();

  return v_row;
end;
$$;

grant execute on function public.start_my_challenge(uuid) to authenticated;

-- Il ritardo ora si misura sul timer personale di chi carica, non su quello globale della cerchia.
create or replace function public.compute_photo_lateness()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_window_end timestamptz;
begin
  select window_end_at into v_window_end
  from public.challenge_participants
  where daily_challenge_id = new.daily_challenge_id and user_id = new.user_id;

  new.uploaded_at := now();
  new.is_late := v_window_end is not null and now() > v_window_end;
  return new;
end;
$$;
