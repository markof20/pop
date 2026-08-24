-- create_circle ora accetta la categoria fin dalla creazione, così la prima sfida
-- del giorno non viene mai generata come "normal" per poi dover essere corretta
-- dall'admin nelle impostazioni (il cambio categoria vale solo per le sfide future,
-- non tocca quella già generata quel giorno).

create or replace function public.create_circle(
  p_name text,
  p_time_window_minutes int default 120,
  p_category text default 'normal'
)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle public.circles;
  v_code text;
begin
  if p_category not in ('amici', 'normal', 'hot') then
    raise exception 'Categoria non valida';
  end if;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.circles (name, invite_code, time_window_minutes, category, created_by)
  values (p_name, v_code, p_time_window_minutes, p_category, auth.uid())
  returning * into v_circle;

  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle.id, auth.uid(), 'admin');

  insert into public.group_streaks (circle_id)
  values (v_circle.id);

  return v_circle;
end;
$$;
