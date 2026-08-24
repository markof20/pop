-- Bug di design in 0009: il cron notturno proclamava solo le sfide di
-- ESATTAMENTE "oggi" (current_date alle 19:00 UTC = 21:00 CEST). Una cerchia
-- che gioca più tardi la sera non ha ancora la sfida del giorno creata quel
-- momento (creazione lazy al primo accesso): il giorno dopo il cron guarda
-- solo il nuovo "oggi", quindi quella sfida resta orfana per sempre — mai
-- proclamata, streak mai aggiornato per chi ha comunque partecipato.
--
-- Fix: ogni notte il cron riprova anche IERI, non solo oggi (in quest'ordine,
-- così gli streak restano consistenti cronologicamente). proclaim_winners_for_date
-- resta invariata ed è già un no-op sicuro per le sfide già proclamate
-- (filtro "not exists winner_decisions").

do $$
begin
  if exists (select 1 from cron.job where jobname = 'proclaim-daily-winners') then
    perform cron.unschedule('proclaim-daily-winners');
  end if;
end $$;

select cron.schedule(
  'proclaim-daily-winners',
  '0 19 * * *',
  $$select public.proclaim_winners_for_date(current_date - 1); select public.proclaim_winners_for_date(current_date);$$
);
