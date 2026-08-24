# POP — Prompt Of the day Photo

Social fotografico per piccole cerchie di amici: ogni giorno un prompt assurdo, una finestra di tempo per scattare, poi la votazione della foto migliore.

Stack: React + Vite + TypeScript + Tailwind CSS v4, Supabase (Auth/Postgres/Storage/Realtime), deploy su Vercel.

## Setup Supabase

1. Crea un progetto su [supabase.com](https://supabase.com) (piano gratuito va bene).
2. Nello SQL editor del progetto, esegui in ordine:
   - `supabase/migrations/0001_init.sql` (schema, RLS, funzioni)
   - `supabase/seed.sql` (50 prompt predefiniti)
3. In **Settings → API**, copia `Project URL` e `anon public key`.
4. Copia `.env.example` in `.env.local` e incolla i due valori:
   ```
   VITE_SUPABASE_URL=...
   VITE_SUPABASE_ANON_KEY=...
   ```

Se usi la [Supabase CLI](https://supabase.com/docs/guides/cli) collegata al progetto, puoi anche fare:

```
supabase link --project-ref <your-project-ref>
supabase db push
```

`seed.sql` viene eseguito automaticamente da `supabase db reset` in locale.

## Sviluppo

```
npm install
npm run dev
```

## Stato del progetto (Fase 1)

- [x] Autenticazione email/password (Supabase Auth)
- [x] Creazione cerchia (max 20 membri, ruolo admin per il creatore)
- [x] Adesione a una cerchia tramite codice invito
- [x] Impostazioni base della cerchia (finestra di tempo, lista membri)
- [ ] Prompt del giorno, scatto foto, griglia, votazione (fase 2)
- [ ] Potere del vincitore, streak, classifiche (fase 3)
- [ ] Archivio personale e recap mensile (fase 4)

## Deploy

Frontend su Vercel (`vercel.json` include il rewrite SPA), variabili d'ambiente `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` da impostare nel progetto Vercel. Backend interamente su Supabase (nessun server separato da deployare in questa fase).
