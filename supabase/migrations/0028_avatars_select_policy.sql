-- L'upload dell'avatar usa upsert:true. Quando esiste già un file allo stesso path,
-- Postgres tratta l'upload come un "insert ... on conflict do update": per stabilire
-- se la riga esistente è in conflitto e va aggiornata deve prima poterla leggere, il
-- che richiede una policy SELECT — mancava del tutto per il bucket avatars (0021
-- aveva solo insert/update/delete), da cui "new row violates row-level security
-- policy" ogni volta che si ricarica la foto profilo su un path già occupato.
-- Il bucket è comunque pubblico (public:true), quindi qui una select aperta a tutti
-- non aggiunge nessuna esposizione rispetto a quanto già leggibile via public URL.

create policy storage_avatars_select on storage.objects
  for select using (bucket_id = 'avatars');
