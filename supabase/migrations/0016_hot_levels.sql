-- Sistema a livelli per la categoria "hot": l'admin sceglie il livello (1 o 2) per
-- la propria cerchia, ogni livello vale un punteggio diverso quando la foto riceve
-- top pick. Resta lo stesso limite di sempre: nessuna nudità, parte intima o atto
-- sessuale, solo intensità crescente nello stesso registro suggestivo.
--
-- Nota: questo livellamento usa la categoria 'hot' con una nuova colonna `level`,
-- indipendente dalle categorie 'hot_lvl1'/'hot_lvl2' inserite manualmente in 0015
-- (quelle non vengono lette da nessuna funzione: get_active_challenge continua a
-- filtrare solo su category in ('amici','normal','hot')).

alter table public.prompts
  add column level int not null default 1 check (level in (1, 2));

alter table public.circles
  add column hot_level int not null default 1 check (hot_level in (1, 2));

alter table public.daily_challenges
  add column prompt_points int not null default 1;

-- I 20 prompt "hot" già in libreria diventano il Livello 1 (1 punto) — nessuna modifica
-- di testo, solo la colonna level che ora esiste con default 1.

-- Livello 2 (2 punti): stesso registro suggestivo, più intenso.
insert into public.prompts (text, is_seed, category, level) values
  ('Le tue mani premute contro il muro, come se qualcuno ti avesse appena sorpreso', true, 'hot', 2),
  ('Il tuo respiro appannato su uno specchio o un vetro freddo, con te sullo sfondo', true, 'hot', 2),
  ('Una foto quasi al buio, illuminata solo dallo schermo del telefono, sguardo fisso in camera', true, 'hot', 2),
  ('Le tue dita che stringono il bordo del materasso o del cuscino', true, 'hot', 2),
  ('La schiena scoperta fino alla base, con la luce che disegna l''ombra della colonna vertebrale', true, 'hot', 2),
  ('Un dettaglio di te appena uscito/a dalla doccia, avvolto/a in un accappatoio', true, 'hot', 2),
  ('Le tue gambe accavallate sul bordo del letto, foto scattata dal basso', true, 'hot', 2),
  ('La tua espressione mentre "aspetti" qualcuno, sdraiato/a con lo sguardo verso la porta', true, 'hot', 2),
  ('Le tue mani che slacciano lentamente una cintura o i lacci di un vestito, fermandoti prima di aprirli', true, 'hot', 2),
  ('Te avvolto/a in un lenzuolo o un asciugamano, inquadrato/a dalle spalle in su', true, 'hot', 2),
  ('Il tuo corpo di profilo, in controluce, con solo il contorno visibile', true, 'hot', 2),
  ('Le tue dita che tracciano una linea lenta lungo il collo verso la clavicola', true, 'hot', 2),
  ('Sguardo dritto in camera, sdraiato/a a pancia in giù, mento appoggiato sulle mani', true, 'hot', 2),
  ('Il tuo miglior "buonanotte" sussurrato senza parole: luce soffusa, sguardo basso', true, 'hot', 2),
  ('Un capo di biancheria appoggiato accanto a te, fuori fuoco, tu a fuoco sullo sfondo', true, 'hot', 2)
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
  v_hot_level int;
  v_prompt_points int;
  v_prompt_text text;
  v_prev_challenge public.daily_challenges;
  v_winner_user_id uuid;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  select time_window_minutes, category, hot_level
    into v_time_window_minutes, v_category, v_hot_level
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

  v_prompt_points := case when v_category = 'hot' then v_hot_level else 1 end;

  select text into v_prompt_text
  from public.prompts
  where is_seed = true
    and category = v_category
    and (v_category <> 'hot' or level = v_hot_level)
    and text not in (
      select prompt_text from public.daily_challenges where circle_id = p_circle_id
    )
  order by random()
  limit 1;

  if v_prompt_text is null then
    select text into v_prompt_text
    from public.prompts
    where is_seed = true
      and category = v_category
      and (v_category <> 'hot' or level = v_hot_level)
    order by random()
    limit 1;
  end if;

  insert into public.daily_challenges (
    circle_id, challenge_date, prompt_text, source, activation_at, window_end_at, status, prompt_points
  ) values (
    p_circle_id,
    current_date,
    v_prompt_text,
    'seed',
    now(),
    now() + (v_time_window_minutes || ' minutes')::interval,
    'active',
    v_prompt_points
  )
  returning * into v_challenge;

  return v_challenge;
end;
$$;

-- Il punteggio ora pesa i top pick per il valore in punti del prompt del giorno
-- (1 per Normal/Amici/Hot livello 1, 2 per Hot livello 2).
create or replace function public.compute_challenge_scores(p_daily_challenge_id uuid)
returns table (
  photo_id uuid,
  user_id uuid,
  username text,
  storage_path text,
  is_late boolean,
  hours_late int,
  top_pick_count int,
  score int,
  uploaded_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    p.id as photo_id,
    p.user_id,
    pr.username,
    p.storage_path,
    p.is_late,
    greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600))::int as hours_late,
    coalesce(tp.cnt, 0)::int as top_pick_count,
    (coalesce(tp.cnt, 0) * dc.prompt_points - greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600)))::int as score,
    p.uploaded_at
  from public.photos p
  join public.profiles pr on pr.id = p.user_id
  join public.daily_challenges dc on dc.id = p.daily_challenge_id
  left join public.challenge_participants cp
    on cp.daily_challenge_id = p.daily_challenge_id and cp.user_id = p.user_id
  left join (
    select photo_id, count(*) as cnt
    from public.top_picks
    where daily_challenge_id = p_daily_challenge_id
    group by photo_id
  ) tp on tp.photo_id = p.id
  where p.daily_challenge_id = p_daily_challenge_id
  order by score desc, p.uploaded_at asc;
$$;

-- Stessa correzione di peso applicata alla classifica (duplicava la formula di score
-- invece di riusare compute_challenge_scores).
create or replace function public.get_circle_leaderboard(p_circle_id uuid, p_period text default 'all_time')
returns table (
  user_id uuid,
  username text,
  total_score int,
  wins_count int,
  challenges_participated int
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_since date;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'Not a member of this circle';
  end if;

  if p_period not in ('all_time', 'weekly') then
    raise exception 'Periodo non valido';
  end if;

  v_since := case
    when p_period = 'weekly' then date_trunc('week', current_date)::date
    else '0001-01-01'::date
  end;

  return query
  with scored_photos as (
    select
      p.user_id,
      p.id as photo_id,
      (coalesce(tp.cnt, 0) * dc.prompt_points - greatest(0, floor(extract(epoch from (p.uploaded_at - cp.window_end_at)) / 3600)))::int as score
    from public.photos p
    join public.daily_challenges dc on dc.id = p.daily_challenge_id
    left join public.challenge_participants cp
      on cp.daily_challenge_id = p.daily_challenge_id and cp.user_id = p.user_id
    left join (
      select photo_id, count(*) as cnt from public.top_picks group by photo_id
    ) tp on tp.photo_id = p.id
    where dc.circle_id = p_circle_id and dc.challenge_date >= v_since
  ),
  wins as (
    select wd.winner_user_id, count(*) as wins_count
    from public.winner_decisions wd
    join public.daily_challenges dc on dc.id = wd.daily_challenge_id
    where dc.circle_id = p_circle_id and dc.challenge_date >= v_since
    group by wd.winner_user_id
  )
  select
    cm.user_id,
    pr.username,
    coalesce(sum(sp.score), 0)::int as total_score,
    coalesce(max(w.wins_count), 0)::int as wins_count,
    count(distinct sp.photo_id)::int as challenges_participated
  from public.circle_members cm
  join public.profiles pr on pr.id = cm.user_id
  left join scored_photos sp on sp.user_id = cm.user_id
  left join wins w on w.winner_user_id = cm.user_id
  where cm.circle_id = p_circle_id
  group by cm.user_id, pr.username
  order by total_score desc, wins_count desc, pr.username asc;
end;
$$;
