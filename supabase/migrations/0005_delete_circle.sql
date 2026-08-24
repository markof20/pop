-- Permette all'admin della cerchia di eliminarla (e le sue foto su Storage).
-- Le altre tabelle (membri, sfide, foto, voti, streak, badge...) sono già
-- collegate a circles con `on delete cascade`, quindi vengono ripulite in automatico.

create policy circles_delete_admin on public.circles
  for delete using (public.is_circle_admin(id));

create policy storage_photos_delete_admin on storage.objects
  for delete using (
    bucket_id = 'photos'
    and public.is_circle_admin((storage.foldername(name))[1]::uuid)
  );
