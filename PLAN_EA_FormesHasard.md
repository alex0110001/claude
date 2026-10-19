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
