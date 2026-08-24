-- Il nickname era univoco solo char-per-char ("Mario" e "mario" potevano coesistere)
-- e un doppione faceva fallire l'insert nel trigger con un errore Postgres generico
-- invece di un messaggio chiaro. Aggiunge un indice univoco case-insensitive e una
-- RPC per controllare la disponibilità del nickname PRIMA di inviare la registrazione
-- (il form gira senza sessione, quindi profiles non è leggibile direttamente per RLS).
--
-- Nota: se in produzione esistono già righe con nickname duplicati a meno del case,
-- la create unique index qui sotto fallisce e vanno rinominati a mano prima di
-- riapplicare la migration.

create unique index profiles_username_lower_idx on public.profiles (lower(username));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public.profiles (id, username)
    values (
      new.id,
      trim(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)))
    );
  exception when unique_violation then
    raise exception 'Nickname già in uso';
  end;
  return new;
end;
$$;

create or replace function public.is_username_taken(p_username text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where lower(username) = lower(trim(p_username))
  );
$$;

grant execute on function public.is_username_taken(text) to anon, authenticated;
