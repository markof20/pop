-- Finora lo streak si aggiornava solo in batch a fine giornata (cron notturno
-- o finalize_challenge_if_ready a completamento totale della cerchia): chi
-- caricava la foto non vedeva il proprio streak salire finché non scattava
-- uno di quei due eventi, spesso ore dopo (o mai, per una cerchia con un solo
-- membro che gioca — nessuna "sfida completata al 100%" da rilevare finché
-- non passa il cron). Ora un trigger aggiorna lo streak del singolo utente
-- nel momento stesso in cui carica: current_streak diventa 1 subito al primo
-- upload, senza aspettare nulla.
--
-- update_user_streaks (il batch di fine giornata) resta per azzerare lo
-- streak di chi NON ha caricato — cosa che si può sapere solo a finestra
-- chiusa, non al momento del caricamento. Va però reso idempotente rispetto
-- al trigger: se last_valid_date è già la data della sfida corrente (il
-- trigger l'ha già aggiornato oggi), il batch non deve ricalcolare da capo
-- trattandolo come un nuovo giorno, altrimenti riporterebbe uno streak più
-- lungo indietro a 1.

create or replace function public.handle_photo_streak()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_challenge_date date;
  v_current_streak int;
  v_longest_streak int;
  v_last_valid_date date;
  v_new_streak int;
begin
  select circle_id, challenge_date into v_circle_id, v_challenge_date
  from public.daily_challenges where id = new.daily_challenge_id;

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

  -- unique(daily_challenge_id, user_id) su photos rende questo caso impossibile
  -- in pratica, ma resta un no-op sicuro invece di ricontare la stessa giornata.
  if v_last_valid_date = v_challenge_date then
    return new;
  end if;

  if v_last_valid_date is not null and v_last_valid_date = v_challenge_date - 1 then
    v_new_streak := v_current_streak + 1;
  else
    v_new_streak := 1;
  end if;

  update public.user_streaks
  set current_streak = v_new_streak,
      longest_streak = greatest(v_longest_streak, v_new_streak),
      last_valid_date = v_challenge_date
  where circle_id = v_circle_id and user_id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_photo_streak on public.photos;
create trigger trg_photo_streak
  after insert on public.photos
  for each row execute procedure public.handle_photo_streak();

-- Stessa logica di prima, ma il ramo "ha caricato" ora salta il ricalcolo se
-- last_valid_date è già la data della sfida (già gestito dal trigger sopra).
create or replace function public.update_user_streaks(p_daily_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_challenge_date date;
  v_member record;
  v_current_streak int;
  v_longest_streak int;
  v_last_valid_date date;
  v_new_streak int;
begin
  select circle_id, challenge_date into v_circle_id, v_challenge_date
  from public.daily_challenges
  where id = p_daily_challenge_id;

  if v_circle_id is null then
    return;
  end if;

  for v_member in
    select
      cm.user_id,
      exists (
        select 1 from public.photos p
        where p.daily_challenge_id = p_daily_challenge_id and p.user_id = cm.user_id
      ) as uploaded
    from public.circle_members cm
    where cm.circle_id = v_circle_id
  loop
    select current_streak, longest_streak, last_valid_date
      into v_current_streak, v_longest_streak, v_last_valid_date
    from public.user_streaks
    where circle_id = v_circle_id and user_id = v_member.user_id
    for update;

    if not found then
      insert into public.user_streaks (circle_id, user_id, current_streak, longest_streak, last_valid_date)
      values (v_circle_id, v_member.user_id, 0, 0, null);
      v_current_streak := 0;
      v_longest_streak := 0;
      v_last_valid_date := null;
    end if;

    if v_member.uploaded then
      if v_last_valid_date = v_challenge_date then
        -- Già aggiornato dal trigger al momento del caricamento: non ricontare.
        null;
      else
        if v_last_valid_date is not null and v_last_valid_date = v_challenge_date - 1 then
          v_new_streak := v_current_streak + 1;
        else
          v_new_streak := 1;
        end if;

        update public.user_streaks
        set current_streak = v_new_streak,
            longest_streak = greatest(v_longest_streak, v_new_streak),
            last_valid_date = v_challenge_date
        where circle_id = v_circle_id and user_id = v_member.user_id;
      end if;
    else
      update public.user_streaks
      set current_streak = 0
      where circle_id = v_circle_id and user_id = v_member.user_id;
    end if;
  end loop;
end;
$$;
