-- Corregge le sfide di oggi che erano già state create dalla vecchia
-- get_active_challenge (quella coi livelli) col testo segnaposto, prima che
-- venisse eseguita 0022. Pesca un prompt vero dalla categoria della cerchia.

update public.daily_challenges dc
set prompt_text = (
  select p.text
  from public.prompts p
  join public.circles c on c.category = p.category
  where c.id = dc.circle_id and p.is_seed = true
  order by random()
  limit 1
)
where dc.prompt_text = 'Scegli il tuo livello per vedere il prompt di oggi';
