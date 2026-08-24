-- Rimuove i vecchi prompt della categoria hot
DELETE FROM public.prompts WHERE is_seed = true AND category IN ('hot_lvl1', 'hot_lvl2', 'hot_lvl3');

-- Inserimento dei nuovi prompt divisi per livello

-- LIVELLO 1: Provocanti & Hot
INSERT INTO public.prompts (text, is_seed, category) VALUES
  ('Sguardo da letto: Un primo piano ravvicinato ai tuoi occhi con l''espressione più maliziosa che riesci a fare ORA.', true, 'hot_lvl1'),
  ('Spalla scoperta: Fai scivolare la maglia o la camicia per mostrare una spalla e la clavicola.', true, 'hot_lvl1'),
  ('Morsetto: Fotografa la tua bocca mentre ti mordi con forza il labbro inferiore.', true, 'hot_lvl1'),
  ('La forma delle gambe: Uno scatto dall''alto verso le tue gambe, incrociate o aperte, mentre sei seduto/a o sdraiato/a.', true, 'hot_lvl1'),
  ('Dita sulle labbra: Passa uno o due dita sulle tue labbra come se ti stessi concentrando su un pensiero proibito.', true, 'hot_lvl1'),
  ('Inquadratura collo: Un primo piano stretto sul collo, teso all''indietro come durante un momento di piacere.', true, 'hot_lvl1'),
  ('Bordo dell''intimo: Un''inquadratura ravvicinata solo sul bordo dell''intimo che spunta dai pantaloni o dalla gonna.', true, 'hot_lvl1'),
  ('Mano sulla coscia: Una foto con la tua mano stretta sulla parte alta della coscia.', true, 'hot_lvl1'),
  ('Schiena nuda o quasi: Fotografa la parte alta della tua schiena tirando avanti la maglietta.', true, 'hot_lvl1'),
  ('Prospettiva dal basso: Inquadratura del tuo viso dal basso verso l''alto mentre guardi la fotocamera con un''aria di superiorità.', true, 'hot_lvl1'),
  ('Dettaglio calza/pelle: Tira leggermente il tessuto dei calzini o dei pantaloni per mostrare un lembo di pelle.', true, 'hot_lvl1'),
  ('Gesto allusivo: Fai un gesto lento e allusivo con la lingua rivolto verso l''obiettivo.', true, 'hot_lvl1'),
  ('Profilo corpo: Un''ombra o una silhouette del tuo busto scattata contro una fonte di luce (lampada o finestra).', true, 'hot_lvl1'),
  ('Tatuaggio o neo nascosto: Fotografa un dettaglio della tua pelle (tatuaggio, neo, lentiggini) solitamente coperto dai vestiti.', true, 'hot_lvl1'),
  ('Posizione di relax provocante: Sdraiati a pancia in giù sul divano/letto con il bacino leggermente alzato.', true, 'hot_lvl1'),
  ('Peek-a-boo décolleté/petto: Inquadratura dall''alto direttamente dentro la scollatura o sotto la maglia sbottonata.', true, 'hot_lvl2'),
  ('Pantaloni sbottonati: Apri il bottone e la zip dei pantaloni lasciando vedere l''intimo sottostante.', true, 'hot_lvl2'),
  ('Mano nei pantaloni: La tua mano infilata chiaramente dentro i pantaloni o le mutande, in posizione centrale.', true, 'hot_lvl2'),
  ('Lato B ravvicinato: Foto stretta sul tuo lato B (sopra i vestiti o in intimo) con una mano appoggiata sopra.', true, 'hot_lvl2'),
  ('Underwear reveal: Tira giù leggermente i pantaloni per mostrare la parte frontale dell''intimo.', true, 'hot_lvl2'),
  ('Pressione sul seno/petto: Una mano che stringe con decisione un seno o il muscolo del petto da sopra o da sotto la maglia.', true, 'hot_lvl2'),
  ('Prospettiva cavallo: Foto scattata direttamente dalla tua prospettiva guardando verso il tuo cavallo mentre sei seduto/a a gambe aperte.', true, 'hot_lvl2'),
  ('Pelle d''oca o brivido: Un primo piano di una parte del corpo mentre ti fai un grattino o un gesto che fa venire i brividi.', true, 'hot_lvl2'),
  ('Mano tra le cosce: Uno scatto con la mano posizionata nell''interno coscia, molto vicina al cavallo.', true, 'hot_lvl2'),
  ('Trasparenza o aderenza: Foto ad un dettaglio del corpo dove il tessuto del vestito è particolarmente aderente o trasparente.', true, 'hot_lvl2'),
  ('Tiro della maglietta: Tira la maglietta verso l''alto fino a scoprire la pancia e il limite dell''intimo.', true, 'hot_lvl2'),
  ('Posizione da dietro: Scatto al tuo corpo visto da dietro, in ginocchio sul letto o sul divano.', true, 'hot_lvl2'),
  ('Segno del dito: Premi un dito con forza sulla pelle di una coscia o del petto lasciando il segno bianco della pressione.', true, 'hot_lvl2'),
  ('Gonna/Pantaloni alzati: Alza leggermente il vestito o abbassa i pantaloncini per mostrare la curvatura del gluteo.', true, 'hot_lvl2'),
  ('Vista da sopra il letto: Inquadrati sdraiato/a sulla schiena con le braccia sopra la testa e la maglia alzata sul busto.', true, 'hot_lvl2'),
  ('Orgasm Face: Primo piano del viso al culmine dell''espressività.', true, 'hot_lvl2')
ON CONFLICT DO NOTHING;