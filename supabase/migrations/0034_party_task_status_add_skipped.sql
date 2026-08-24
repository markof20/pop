-- Nuovo stato per party_tasks: un task rivelato e poi saltato dall'assegnatario non
-- deve tornare a 'pending' (la RLS nasconde i 'pending' per preservare la sorpresa
-- dei turni non ancora rivelati — ma questo è già stato mostrato una volta, non c'è
-- più nulla da nascondere). 'skipped' resta visibile e rientra nel pool dei task da
-- ripescare più avanti nella sessione.
--
-- ALTER TYPE ... ADD VALUE deve stare in una migrazione a sé: il nuovo valore non è
-- utilizzabile nella stessa transazione in cui viene aggiunto.

alter type public.party_task_status add value 'skipped';
