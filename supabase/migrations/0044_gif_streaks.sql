-- Estende lo streak per contare anche le cerchie GIF, con la stessa logica
-- già usata per le foto (0042): un trigger aggiorna current_streak/last_valid_date
-- nel momento in cui mandi la GIF del giorno, usando gif_sessions.session_date
-- al posto di daily_challenges.challenge_date. user_streaks resta la stessa
-- tabella per entrambi i tipi di cerchia — ogni utente ha una sola riga per
-- circle_id, a prescindere dal circle_type.

create or replace function public.handle_gif_streak()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_session_date date;
  v_current_streak int;
  v_longest_streak int;
  v_last_valid_date date;
  v_new_streak int;
begin
  select circle_id, session_date into v_circle_id, v_session_date
  from public.gif_sessions where id = new.session_id;

  select current_streak, longest_streak, last_valid_date
    into v_current_streak, v_longest_streak, v_last_valid_date
  from public.user_streaks
  where circle_id = v_circle_id and user_id = new.user_id
  for update;

  if not found then
    insert into public.user_streaks (circle_id, user_id, current_streak, longest_streak, last_valid_date)
    values (v_circle_id, new.user_id, 0, 0, null);
    v_current_streak := 0;
    v_longest_streak := 0;
    v_last_valid_date := null;
  end if;

  -- unique(session_id, user_id) su gif_submissions rende questo caso impossibile
  -- in pratica, ma resta un no-op sicuro invece di ricontare la stessa giornata.
  if v_last_valid_date = v_session_date then
    return new;
  end if;

  if v_last_valid_date is not null and v_last_valid_date = v_session_date - 1 then
    v_new_streak := v_current_streak + 1;
  else
    v_new_streak := 1;
  end if;

  update public.user_streaks
  set current_streak = v_new_streak,
      longest_streak = greatest(v_longest_streak, v_new_streak),
      last_valid_date = v_session_date
  where circle_id = v_circle_id and user_id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_gif_streak on public.gif_submissions;
create trigger trg_gif_streak
  after insert on public.gif_submissions
  for each row execute procedure public.handle_gif_streak();

-- Azzeramento notturno per chi salta un giorno in una cerchia GIF (stesso
-- principio del ramo finale di proclaim_winners_for_date per le foto): chi
-- non ha mandato la GIF quel giorno, o la cerchia non ha nemmeno avuto una
-- sessione quel giorno (nessuno l'ha aperta), va a zero.
create or replace function public.zero_out_gif_streaks(p_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session record;
  v_circle record;
begin
  for v_session in
    select gs.id, gs.circle_id
    from public.gif_sessions gs
    where gs.session_date = p_date
  loop
    update public.user_streaks us
    set current_streak = 0
    where us.circle_id = v_session.circle_id
      and us.current_streak <> 0
      and not exists (
        select 1 from public.gif_submissions s
        where s.session_id = v_session.id and s.user_id = us.user_id
      );
  end loop;

  for v_circle in
    select c.id
    from public.circles c
    where c.circle_type = 'gif'
      and not exists (
        select 1 from public.gif_sessions gs
        where gs.circle_id = c.id and gs.session_date = p_date
      )
  loop
    update public.user_streaks
    set current_streak = 0
    where circle_id = v_circle.id
      and current_streak <> 0;
  end loop;
end;
$$;

-- Stesso pattern di 0041: riprova anche ieri, non solo oggi, per non perdere
-- l'azzeramento se il job gira prima che qualcuno abbia aperto la cerchia.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'proclaim-daily-winners') then
    perform cron.unschedule('proclaim-daily-winners');
  end if;
end $$;

select cron.schedule(
  'proclaim-daily-winners',
  '0 19 * * *',
  $$
  select public.proclaim_winners_for_date(current_date - 1);
  select public.proclaim_winners_for_date(current_date);
  select public.zero_out_gif_streaks(current_date - 1);
  select public.zero_out_gif_streaks(current_date);
  $$
);
