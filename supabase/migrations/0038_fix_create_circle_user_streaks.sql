-- Bugfix di 0037: la nuova create_circle era stata riscritta copiando il corpo
-- di 0017 (create_circle inserisce in group_streaks), ma 0025 aveva già
-- sostituito group_streaks con user_streaks e aggiornato create_circle di
-- conseguenza. Il copia-incolla ha fatto regredire quella parte, causando
-- "relation public.group_streaks does not exist" alla creazione di ogni
-- nuova cerchia. Stesso corpo di 0037 ma con l'insert corretto in user_streaks.

create or replace function public.create_circle(
  p_name text,
  p_time_window_minutes int default 120,
  p_category text default 'normal',
  p_circle_type text default 'photo'
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
  if p_circle_type not in ('photo', 'gif') then
    raise exception 'Tipo di cerchia non valido';
  end if;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.circles (name, invite_code, time_window_minutes, category, circle_type, created_by)
  values (p_name, v_code, p_time_window_minutes, p_category, p_circle_type, auth.uid())
  returning * into v_circle;

  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle.id, auth.uid(), 'admin');

  insert into public.user_streaks (circle_id, user_id)
  values (v_circle.id, auth.uid());

  return v_circle;
end;
$$;

grant execute on function public.create_circle(text, int, text, text) to authenticated;
