-- Limita le reazioni a 1 per utente per foto (sostituibile), invece di illimitate.

-- Ripulisce eventuali duplicati creati durante i test prima del vincolo unique
-- (tiene la riga più recente per ogni coppia foto/utente).
delete from public.reactions a
using public.reactions b
where a.photo_id = b.photo_id
  and a.user_id = b.user_id
  and (a.created_at, a.id) < (b.created_at, b.id);

alter table public.reactions
  add constraint reactions_photo_user_unique unique (photo_id, user_id);

create policy reactions_delete_self on public.reactions
  for delete using (user_id = auth.uid());
