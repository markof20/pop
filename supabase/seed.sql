-- Libreria di prompt predefiniti per POP, divisa per categoria (Amici / Normal / Hot).
-- Eseguito automaticamente da `supabase db reset` in locale;
-- da lanciare manualmente nello SQL editor per un progetto hosted
-- (le migrazioni successive alla 0014 richiedono la colonna `category`).

insert into public.prompts (text, is_seed, category) values
  -- Normal: assurdo e giocoso, adatto a qualsiasi cerchia.
  ('Il tuo piede in una posizione imbarazzante', true, 'normal'),
  ('Qualcosa nel tuo frigo che ti fa vergognare', true, 'normal'),
  ('Un oggetto che non dovrebbe stare dove sta in questo momento', true, 'normal'),
  ('Il tuo miglior tentativo di sembrare una spia', true, 'normal'),
  ('La cosa più inutile che possiedi', true, 'normal'),
  ('Il tuo angolo preferito per procrastinare', true, 'normal'),
  ('Il tuo outfit da "sono uscito di casa in due minuti"', true, 'normal'),
  ('Qualcosa che sta per cadere', true, 'normal'),
  ('La tua reazione a un rumore improvviso', true, 'normal'),
  ('Il posto più disordinato vicino a te in questo momento', true, 'normal'),
  ('Ricrea la copertina di un album immaginario', true, 'normal'),
  ('Una torre fatta con quello che hai sulla scrivania', true, 'normal'),
  ('Il tuo riflesso in qualcosa che non è uno specchio', true, 'normal'),
  ('La prova che oggi hai fatto qualcosa di produttivo', true, 'normal'),
  ('Qualcosa che useresti come arma in un''emergenza', true, 'normal'),
  ('La tua espressione da "ho appena ricevuto una bolletta"', true, 'normal'),
  ('Un selfie con l''oggetto più vecchio della stanza', true, 'normal'),
  ('Il tuo tentativo di imitare una statua famosa', true, 'normal'),
  ('La vista dal punto più scomodo della casa', true, 'normal'),
  ('Un oggetto a forma di faccia (pareidolia obbligatoria)', true, 'normal'),
  ('La prova che sei sopravvissuto alla giornata', true, 'normal'),
  ('Un monumento improvvisato con oggetti da cucina', true, 'normal'),
  ('Il tuo peggior angolo di ripresa, di proposito', true, 'normal'),
  ('Una foto che racconta una bugia (ma sembra vera)', true, 'normal'),
  ('Un oggetto che ti ha tradito almeno una volta', true, 'normal'),
  ('Qualcosa che hai rubato a un ristorante (con orgoglio)', true, 'normal'),
  ('Il tuo nascondiglio segreto per gli snack', true, 'normal'),
  ('Il tuo miglior travestimento improvvisato in 10 secondi', true, 'normal'),
  ('La cosa più assurda nel tuo zaino/borsa in questo momento', true, 'normal'),
  ('Il posto dove nascondi le cose quando arrivano ospiti', true, 'normal'),

  -- Amici: legati alla vita di gruppo, ricordi e dinamiche della cerchia.
  ('Qualcosa che ti ricorda l''ultima uscita di gruppo', true, 'amici'),
  ('Il tuo miglior "sguardo di giudizio" per la chat di gruppo', true, 'amici'),
  ('Una prova che stai pensando a qualcuno della cerchia in questo momento', true, 'amici'),
  ('Il regalo più assurdo che faresti a uno del gruppo', true, 'amici'),
  ('Qualcosa che presteresti solo alla tua persona di fiducia nella cerchia', true, 'amici'),
  ('Ricrea con oggetti reali l''ultimo meme che avete condiviso nel gruppo', true, 'amici'),
  ('Una cosa che ti fa pensare a un ricordo imbarazzante di gruppo', true, 'amici'),
  ('Il tuo alibi fotografico per l''ultima volta che hai dato buca', true, 'amici'),
  ('Qualcosa che useresti per convincere il gruppo a uscire stasera', true, 'amici'),
  ('La prova che sei pronto per la prossima uscita di gruppo', true, 'amici'),
  ('Il tuo contributo (vero o immaginario) alla prossima cena tra amici', true, 'amici'),
  ('Un oggetto che rappresenta il ruolo che hai nel gruppo', true, 'amici'),
  ('La reazione che faresti leggendo un messaggio nella chat del gruppo adesso', true, 'amici'),
  ('Qualcosa che dimostra chi sei quando non c''è nessuno del gruppo a guardare', true, 'amici'),
  ('Il souvenir più inutile portato a casa da un''uscita con la cerchia', true, 'amici'),
  ('Il tuo outfit ideale per la prossima serata tutti insieme', true, 'amici'),
  ('Qualcosa che nasconderesti se il gruppo venisse a casa tua ora', true, 'amici'),
  ('La prova fotografica di chi arriva sempre in ritardo (tu, probabilmente)', true, 'amici'),
  ('Un brindisi improvvisato con quello che hai in casa', true, 'amici'),
  ('La tua miglior imitazione di qualcun altro della cerchia', true, 'amici'),

  -- Hot: intensa e sensuale, ma sempre suggerita — mai nudità, parti intime o atti sessuali.
  ('Lo sguardo che uccide: primo piano intenso, occhi socchiusi', true, 'hot'),
  ('La tua miglior espressione mentre ti mordi il labbro', true, 'hot'),
  ('La tua schiena inarcata, fotografata di spalle', true, 'hot'),
  ('La tua sagoma stagliata contro una finestra o una lampada', true, 'hot'),
  ('Uno spallino che scivola lentamente giù da una spalla', true, 'hot'),
  ('Ti passi le dita tra i capelli con lo sguardo fisso in camera', true, 'hot'),
  ('La curva della schiena bassa, dove la maglia si solleva appena', true, 'hot'),
  ('Seduto/a sul letto, ginocchia al petto, sguardo che invita', true, 'hot'),
  ('La testa inclinata di lato, collo teso, come in un momento di abbandono', true, 'hot'),
  ('Una foto scattata da sotto le lenzuola: solo un occhio o un sorriso visibile', true, 'hot'),
  ('Le tue dita che accarezzano lentamente il bordo di un bicchiere', true, 'hot'),
  ('Un dettaglio sensuale del piede o della caviglia appoggiato sul cuscino', true, 'hot'),
  ('L''incavo del fianco dove la maglia si solleva sopra i pantaloni', true, 'hot'),
  ('Un cubetto di ghiaccio che scivola su collo o clavicola', true, 'hot'),
  ('Appena sveglio/a: capelli spettinati, sguardo ancora assonnato ma intenso', true, 'hot'),
  ('Una mano premuta sul petto, come a trattenere il respiro', true, 'hot'),
  ('Sdraiato/a, foto scattata dall''alto, sguardo dritto in camera', true, 'hot'),
  ('Il tuo profilo illuminato solo dalla luce di una candela', true, 'hot'),
  ('Il tuo riflesso allo specchio con un''aria da "guardami"', true, 'hot'),
  ('Le tue mani che stringono lentamente il bordo di una porta, come in attesa', true, 'hot')
on conflict do nothing;

-- Amici livello 2 (2 punti): più profondo/vulnerabile invece che più leggero. Richiede
-- la colonna `level` aggiunta in 0016_hot_levels.sql.
insert into public.prompts (text, is_seed, category, level) values
  ('Una foto di qualcosa che non hai mai mostrato a nessuno del gruppo', true, 'amici', 2),
  ('Il tuo posto sicuro quando hai una brutta giornata, fotografato adesso', true, 'amici', 2),
  ('Qualcosa che rappresenta una paura che non hai mai confessato al gruppo', true, 'amici', 2),
  ('Una prova fotografica di quanto sei cambiato/a da quando conosci questa cerchia', true, 'amici', 2),
  ('Il messaggio che non hai mai avuto il coraggio di mandare nella chat, scritto su carta (senza inviarlo)', true, 'amici', 2),
  ('Qualcosa che terresti anche se il gruppo si sciogliesse domani', true, 'amici', 2),
  ('Il tuo momento più imbarazzante vissuto con la cerchia, ricreato con oggetti', true, 'amici', 2),
  ('Una foto di ciò che faresti se uno del gruppo avesse bisogno di te alle 3 di notte', true, 'amici', 2),
  ('L''oggetto che ti ricorda la persona della cerchia che ammiri di più', true, 'amici', 2),
  ('Il tuo "io" di 5 anni fa che reagisce a questa cerchia: ricrea l''espressione', true, 'amici', 2),
  ('Una prova che ti fideresti di questo gruppo con un segreto vero', true, 'amici', 2),
  ('Il ricordo più vulnerabile condiviso con la cerchia, rappresentato con un oggetto', true, 'amici', 2),
  ('Qualcosa che faresti solo se sapessi che nessuno ti giudica', true, 'amici', 2),
  ('Un "grazie" mai detto a qualcuno del gruppo, scritto e fotografato', true, 'amici', 2),
  ('La versione di te che il gruppo non ha mai visto, in un solo oggetto', true, 'amici', 2)
on conflict do nothing;

-- Hot livello 2 (2 punti): stesso registro, più intenso. Richiede la colonna
-- `level` aggiunta in 0016_hot_levels.sql.
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
