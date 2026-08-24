-- L'admin può scegliere il "tono" della cerchia: Amici, Normal o Hot.
-- Ogni prompt seed viene taggato con una categoria, e get_active_challenge pesca
-- solo dalla categoria impostata sulla cerchia invece che dall'intera libreria.
-- Approfitto per ripulire la libreria di prompt esistente (non categorizzata,
-- e con troppe varianti simili tra loro) e ripartire con tre liste più curate.

alter table public.prompts
  add column category text not null default 'normal'
  check (category in ('amici', 'normal', 'hot'));

alter table public.circles
  add column category text not null default 'normal'
  check (category in ('amici', 'normal', 'hot'));

delete from public.prompts where is_seed = true;

insert into public.prompts (text, is_seed, category) values
  -- Normal: assurdo e giocoso, adatto a qualsiasi cerchia.
  ('Il tuo piede in una posizione imbarazzante', true, 'normal'),
  ('Qualcosa nel tuo frigo che ti fa vergognare', true, 'normal'),
  ('Un oggetto che non dovrebbe stare dove sta in questo momento', true, 'normal'),
  ('Il tuo miglior tentativo di sembrare una spia', true, 'normal'),
  ('La cosa più inutile che possiedi', true, 'normal'),
  ('Il tuo angolo preferito per procrastinare', true, 'normal'),
  ('Il tuo outfit da "sono uscito di casa in due minuti"', true, 'normal'),
  ('Qualcosa che sta per cadere', true, 'normal'),
  ('La tua reazione a un rumore improvviso', true, 'normal'),
  ('Il posto più disordinato vicino a te in questo momento', true, 'normal'),
  ('Ricrea la copertina di un album immaginario', true, 'normal'),
  ('Una torre fatta con quello che hai sulla scrivania', true, 'normal'),
  ('Il tuo riflesso in qualcosa che non è uno specchio', true, 'normal'),
  ('La prova che oggi hai fatto qualcosa di produttivo', true, 'normal'),
  ('Qualcosa che useresti come arma in un''emergenza', true, 'normal'),
  ('La tua espressione da "ho appena ricevuto una bolletta"', true, 'normal'),
  ('Un selfie con l''oggetto più vecchio della stanza', true, 'normal'),
  ('Il tuo tentativo di imitare una statua famosa', true, 'normal'),
  ('La vista dal punto più scomodo della casa', true, 'normal'),
  ('Un oggetto a forma di faccia (pareidolia obbligatoria)', true, 'normal'),
  ('La prova che sei sopravvissuto alla giornata', true, 'normal'),
  ('Un monumento improvvisato con oggetti da cucina', true, 'normal'),
  ('Il tuo peggior angolo di ripresa, di proposito', true, 'normal'),
  ('Una foto che racconta una bugia (ma sembra vera)', true, 'normal'),
  ('Un oggetto che ti ha tradito almeno una volta', true, 'normal'),
  ('Qualcosa che hai rubato a un ristorante (con orgoglio)', true, 'normal'),
  ('Il tuo nascondiglio segreto per gli snack', true, 'normal'),
  ('Il tuo miglior travestimento improvvisato in 10 secondi', true, 'normal'),
  ('La cosa più assurda nel tuo zaino/borsa in questo momento', true, 'normal'),
  ('Il posto dove nascondi le cose quando arrivano ospiti', true, 'normal'),

  -- Amici: legati alla vita di gruppo, ricordi e dinamiche della cerchia.
  ('Qualcosa che ti ricorda l''ultima uscita di gruppo', true, 'amici'),
  ('Il tuo miglior "sguardo di giudizio" per la chat di gruppo', true, 'amici'),
  ('Una prova che stai pensando a qualcuno della cerchia in questo momento', true, 'amici'),
  ('Il regalo più assurdo che faresti a uno del gruppo', true, 'amici'),
  ('Qualcosa che presteresti solo alla tua persona di fiducia nella cerchia', true, 'amici'),
  ('Ricrea con oggetti reali l''ultimo meme che avete condiviso nel gruppo', true, 'amici'),
  ('Una cosa che ti fa pensare a un ricordo imbarazzante di gruppo', true, 'amici'),
  ('Il tuo alibi fotografico per l''ultima volta che hai dato buca', true, 'amici'),
  ('Qualcosa che useresti per convincere il gruppo a uscire stasera', true, 'amici'),
  ('La prova che sei pronto per la prossima uscita di gruppo', true, 'amici'),
  ('Il tuo contributo (vero o immaginario) alla prossima cena tra amici', true, 'amici'),
  ('Un oggetto che rappresenta il ruolo che hai nel gruppo', true, 'amici'),
  ('La reazione che faresti leggendo un messaggio nella chat del gruppo adesso', true, 'amici'),
  ('Qualcosa che dimostra chi sei quando non c''è nessuno del gruppo a guardare', true, 'amici'),
  ('Il souvenir più inutile portato a casa da un''uscita con la cerchia', true, 'amici'),
  ('Il tuo outfit ideale per la prossima serata tutti insieme', true, 'amici'),
  ('Qualcosa che nasconderesti se il gruppo venisse a casa tua ora', true, 'amici'),
  ('La prova fotografica di chi arriva sempre in ritardo (tu, probabilmente)', true, 'amici'),
  ('Un brindisi improvvisato con quello che hai in casa', true, 'amici'),
  ('La tua miglior imitazione di qualcun altro della cerchia', true, 'amici'),

  -- Hot: più intima e provocante, ma sempre giocosa e non esplicita.
  ('La tua posa più seducente con quello che indossi in questo momento', true, 'hot'),
  ('Un dettaglio di te che di solito tieni nascosto', true, 'hot'),
  ('Lo sguardo che faresti per rimorchiare al buio', true, 'hot'),
  ('La tua versione di una foto da profilo di un''app di incontri', true, 'hot'),
  ('Qualcosa che indosseresti per un appuntamento last minute', true, 'hot'),
  ('Il tuo miglior sguardo da "vieni a scoprirlo di persona"', true, 'hot'),
  ('Una foto che manderesti a un crush per fare colpo', true, 'hot'),
  ('Il capo di abbigliamento che ti fa sentire più sicuro/a di te', true, 'hot'),
  ('La tua posa da copertina di calendario', true, 'hot'),
  ('Qualcosa di rosso che hai a portata di mano', true, 'hot'),
  ('Il tuo miglior "ti aspetto stasera" senza dire una parola', true, 'hot'),
  ('Una foto che useresti per ingelosire un ex (senza cattiveria)', true, 'hot'),
  ('Il profumo o il prodotto che usi per un''occasione speciale', true, 'hot'),
  ('La tua miglior imitazione di una scena da film romantico', true, 'hot'),
  ('Qualcosa che diresti sia "solo per la persona giusta"', true, 'hot'),
  ('Un accessorio che ti fa sentire irresistibile', true, 'hot'),
  ('La tua espressione dopo un complimento inaspettato', true, 'hot'),
  ('Il tuo angolo più fotogenico di casa per una foto "misteriosa"', true, 'hot'),
  ('Una posa da copertina di un romanzo rosa', true, 'hot'),
  ('Il tuo miglior selfie "buonanotte" da mandare a qualcuno di speciale', true, 'hot')
on conflict do nothing;

create or replace function public.get_active_challenge(p_circle_id uuid)
returns public.daily_challenges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.daily_challenges;
  v_time_window_minutes int;
  v_category text;
  v_prompt_text text;
  v_prev_challenge public.daily_challenges;
  v_winner_user_id uuid;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select time_window_minutes, category into v_time_window_minutes, v_category
  from public.circles where id = p_circle_id;

  -- Proclama il vincitore della sfida passata più recente, se non è già stato fatto.
  select * into v_prev_challenge
  from public.daily_challenges
  where circle_id = p_circle_id and challenge_date < current_date
  order by challenge_date desc
  limit 1;

  if v_prev_challenge.id is not null
     and not exists (select 1 from public.winner_decisions where daily_challenge_id = v_prev_challenge.id)
  then
    select r.user_id into v_winner_user_id
    from public.get_challenge_results(v_prev_challenge.id) r
    order by r.score desc, r.uploaded_at asc
    limit 1;

    if v_winner_user_id is not null then
      insert into public.winner_decisions (daily_challenge_id, winner_user_id, choice, decide_by_at)
      values (v_prev_challenge.id, v_winner_user_id, null, now() + interval '1 hour')
      on conflict (daily_challenge_id) do nothing;
    end if;
  end if;

  -- Sfida di oggi: se esiste già (magari creata dal vincitore con l'Opzione A), restituiscila.
  select * into v_challenge
  from public.daily_challenges
  where circle_id = p_circle_id and challenge_date = current_date;

  if v_challenge.id is not null then
    return v_challenge;
  end if;

  select text into v_prompt_text
  from public.prompts
  where is_seed = true
    and category = v_category
    and text not in (
      select prompt_text from public.daily_challenges where circle_id = p_circle_id
    )
  order by random()
  limit 1;

  if v_prompt_text is null then
    select text into v_prompt_text
    from public.prompts
    where is_seed = true and category = v_category
    order by random()
    limit 1;
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
