-- Bug: quando una giornata non aveva NESSUNA foto caricata, compute_challenge_scores
-- non restituiva righe, v_winner_user_id restava null e update_group_streak non veniva
-- mai chiamata (era dentro il blocco "if v_winner_user_id is not null"). Risultato: una
-- giornata completamente saltata non azzerava lo streak, che restava fermo al valore
-- vecchio invece di andare a 0 come da regola (0013_streaks.sql).
--
-- Stesso problema per le cerchie che non hanno nemmeno una riga in daily_challenges per
-- quella data (nessuno ha aperto l'app quel giorno): non venivano mai considerate,
-- quindi lo streak restava fermo anche in quel caso.

create or replace function public.proclaim_winners_for_date(p_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge record;
  v_winner_user_id uuid;
  v_circle record;
begin
  for v_challenge in
    select dc.id
    from public.daily_challenges dc
    where dc.challenge_date = p_date
      and not exists (select 1 from public.winner_decisions wd where wd.daily_challenge_id = dc.id)
  loop
    select user_id into v_winner_user_id
    from public.compute_challenge_scores(v_challenge.id)
    order by score desc, uploaded_at asc
    limit 1;

    if v_winner_user_id is not null then
      insert into public.winner_decisions (daily_challenge_id, winner_user_id, choice, decide_by_at)
      values (v_challenge.id, v_winner_user_id, null, now() + interval '1 hour')
      on conflict (daily_challenge_id) do nothing;
    end if;

    -- Aggiorna lo streak sempre, anche a zero foto: update_group_streak ricalcola
    -- v_day_valid da sé e azzera current_streak se la giornata non è valida.
    perform public.update_group_streak(v_challenge.id);
  end loop;

  -- Cerchie senza nessuna sfida per questa data: nessuno ha partecipato, streak azzerato.
  for v_circle in
    select c.id
    from public.circles c
    where not exists (
      select 1 from public.daily_challenges dc
      where dc.circle_id = c.id and dc.challenge_date = p_date
    )
  loop
    update public.group_streaks
    set current_streak = 0
    where circle_id = v_circle.id
      and current_streak <> 0;
  end loop;
end;
$$;
