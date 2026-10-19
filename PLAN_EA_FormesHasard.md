# Plan EA FormesHasard (reverse de FormesHasard.mq5)

Fichier cible : FormesHasardEA.mq5 — XAUUSD M1, barres closes seulement.

## Logique extraite
- Fenêtre glissante 720 barres M1 (filtre UTC, décalage -3), 2 jambes de 360.
- z = déplacement jambe / (sd des variations × √360), seuil |z| > 1.0 → classe -1/0/+1.
- Forme (a,b) : TENDANCE (a=b≠0), ÉPUISEMENT (a≠0,b=0), DÉPART (a=0,b≠0), RETOURNEMENT (b=-a), RANGE (0,0).
- Sens : TEND/ÉPUI = a ; DÉP/RETO = b.
- Alignement prix > M54 > M162 > M423 (ou inverse), âge en barres ; p90=37, p99=97.
- Conduite : TEND suivre/laisser courir ; ÉPUI sortir ; DÉP suivre ; RETO inverser ; RANGE limites.

## Règles EA proposées (à valider)
- Entrée : DÉPART ou TENDANCE (nouvelle forme) dans le sens, + alignement même sens.
- Entrée inverse : RETOURNEMENT dans le sens de b.
- Sortie : ÉPUISEMENT, ou changement de sens, ou alignement perdu.
- RANGE : pas de trade (v1).
- SL ATR fixe, risque % par trade, 1 position/magic, anti-burst (nouvelle barre).

## Blocs
- B1 : header, inputs, globals
- B2 : chargement barres, filtre UTC, sommes cumulées (repris tel quel)
- B3 : Glissante/Forme/Sens (repris)
- B4 : alignement (repris)
- B5 : signal (forme+sens+align → ordre)
- B6 : helpers trade (lot risque, filling, stops, retcodes)
- B7 : gestion position (sortie, trailing option)
- B8 : OnInit/OnTick(new bar)/OnDeinit
- Assemblage final en un fichier, sans réécrire les blocs.

## Révision 2 : Pattern T + règles d'entrée (remplace "Règles EA proposées")
Pattern T (pattern_T.html) : 17 M1 consécutives, angle = atan(pente régression clôtures / ATR60), cible ±23.5° (±25 % : 17.6°–29.4°), R² ≥ 0.88, ATR60 = moy(H-L) des 60 M1 avant. Hausses et baisses (miroir).
- PAUSE : T détecté sur la fenêtre close → aucune entrée, ordres limites en attente annulés, jusqu'à la fin du T (fenêtre ne répond plus aux critères).
- Entrée (si pas de pause, forme glissante TENDANCE/RETOURNEMENT/RANGE) : séquence de N bougies M1 consécutives contre le sens (InpNbConsec, déf. 3), chacune de corps/taille > InpTailleMin (1.0 $), la dernière dans le sens inverse de la tendance.
  Ex. trend down : bougies haussières consécutives ≥ N, taille > 1 $ → ordre BUY LIMIT.
- Ordre toujours LIMIT (prix de la limite : clôture de la dernière bougie de la séquence, input d'offset), expiration 1–2 barres.
- TP : RANGE et RETOURNEMENT = 0.50 $ ; TENDANCE = 4.00 $ (inputs).
- InpMaxPositions (1 = une seule, >1 = multi). SL ATR (input), magic, anti-burst new-bar.
- Hypothèses à confirmer : "taille" = high-low ; sens de la limite = dans le sens de la tendance (retour de tendance après contre-bougies) ; pause = blocage des entrées pendant T.
