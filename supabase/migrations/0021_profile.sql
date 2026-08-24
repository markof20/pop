-- Sezione profilo: foto profilo, genere (per eventuali domande differenziate in
-- futuro) e preferenze personali di tema (palette colori + font), che si applicano
-- solo al proprio client, non alla cerchia.

alter table public.profiles
  add column gender text check (gender in ('uomo', 'donna', 'altro')),
  add column theme_palette text not null default 'pop',
  add column theme_font text not null default 'baloo';

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy storage_avatars_insert on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_avatars_update on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_avatars_delete on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
