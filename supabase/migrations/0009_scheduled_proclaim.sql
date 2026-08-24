-- Proclama il vincitore ogni giorno alle 20:00 (ora italiana) invece di aspettare
-- che qualcuno apra l'app il giorno dopo. Usa pg_cron, che gira dentro Postgres:
-- nessuna Edge Function o servizio esterno da distribuire, solo altro SQL.
--
-- Nota sul fuso orario: pg_cron gira in UTC. 19:00 UTC = 20:00 CET (ora solare,
-- inverno). In ora legale (CEST, primavera/estate) corrisponde alle 21:00 —
-- uno scarto di un'ora due volte l'anno, accettabile per l'uso previsto. Se si
-- vuole essere precisi tutto l'anno bisognerebbe cambiare l'orario cron ogni
-- cambio ora legale (basta rilanciare il blocco "select cron.schedule" in fondo
-- con un orario diverso).

create extension if not exists pg_cron;

-- Versione "di sistema" del calcolo vincitore: gira per TUTTE le cerchie senza
-- bisogno di un utente autenticato (il cron non ha un auth.uid()), quindi non
-- passa da is_circle_member() come get_challenge_results().
create or replace function public.proclaim_winners_for_date(p_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge record;
  v_winner_user_id uuid;
begin
  for v_challenge in
    select dc.id
    from public.daily_challenges dc
    where dc.challenge_date = p_date
      and not exists (select 1 from public.winner_decisions wd where wd.daily_challenge_id = dc.id)
  loop
    select p.user_id into v_winner_user_id
    from public.photos p
    left join public.challenge_participants cp
      on cp.daily_challenge_id = p.daily_challenge_id and cp.user_id = p.user_id
    left join (
      select photo_id, count(*) as cnt
      from public.top_picks
      where daily_challenge_id = v_challenge.id
      group by photo_id
    ) tp on tp.photo_id = p.id
    where p.daily_challenge_id = v_challenge.id
    order by
      (coalesce(tp.cnt, 0) - greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600))) desc,
      p.uploaded_at asc
    limit 1;

    if v_winner_user_id is not null then
      insert into public.winner_decisions (daily_challenge_id, winner_user_id, choice, decide_by_at)
      values (v_challenge.id, v_winner_user_id, null, now() + interval '1 hour')
      on conflict (daily_challenge_id) do nothing;
    end if;
  end loop;
end;
$$;

-- Idempotente: se lo script viene rilanciato, sostituisce il job invece di duplicarlo.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'proclaim-daily-winners') then
    perform cron.unschedule('proclaim-daily-winners');
  end if;
end $$;

select cron.schedule(
  'proclaim-daily-winners',
  '0 19 * * *',
  $$select public.proclaim_winners_for_date(current_date);$$
);

-- I "risultati" mostrati in app ora seguono la proclamazione (che può avvenire
-- oggi stesso alle 20:00), non più solo i giorni passati per data.
create or replace function public.get_latest_completed_challenge(p_circle_id uuid)
returns public.daily_challenges
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_row public.daily_challenges;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select dc.* into v_row
  from public.daily_challenges dc
  where dc.circle_id = p_circle_id
    and exists (select 1 from public.winner_decisions wd where wd.daily_challenge_id = dc.id)
  order by dc.challenge_date desc
  limit 1;

  if v_row.id is null then
    return null;
  end if;

  return v_row;
end;
$$;
