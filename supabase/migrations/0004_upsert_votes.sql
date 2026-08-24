-- Fase 2 fix: permette di cambiare emoji/top pick con un upsert atomico invece di
-- un delete+insert in due passaggi lato client (che dipendeva silenziosamente
-- dalla policy di delete e poteva lasciare righe "bloccate" in caso di problemi).

create policy reactions_update_self on public.reactions
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy top_picks_update_self on public.top_picks
  for update using (voter_id = auth.uid()) with check (voter_id = auth.uid());
