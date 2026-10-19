//+------------------------------------------------------------------+
//| FormesHasardEA.mq5                                               |
//| XAUUSD M1. Formes du hasard (fenetre 720 barres) + pause T.      |
//| Entree en LIMIT dans le sens de la forme, apres N bougies M1     |
//| contraires > taille min, posee InpSecAvantFin s avant la fin.    |
//| Barres closes pour les formes et le pattern T (causal).          |
//+------------------------------------------------------------------+
#property copyright "HACHI"
#property version   "1.00"

#include <Trade\Trade.mqh>

input group "=== Formes (720 barres) ==="
input double InpSeuil          = 1.0;     // seuil |z| d'une jambe nette
input int    InpDecalageHeures = -3;      // decalage heure serveur -> UTC (Fusion = -3)

input group "=== Pattern T (pause) ==="
input bool   InpPauseT         = true;    // pause des entrees pendant un T
input int    InpTBarres        = 17;      // barres M1 consecutives du T
input double InpTAngle         = 23.5;    // angle cible (degres)
input double InpTTol           = 0.25;    // tolerance relative sur l'angle
input double InpTR2Min         = 0.88;    // R2 minimum de la regression
input int    InpTATR           = 60;      // barres de l'ATR (H-L) avant le T

input group "=== Entree ==="
input int    InpNbConsec       = 3;       // bougies M1 contraires consecutives
input double InpTailleMin      = 1.0;     // taille min (high-low) en $
input int    InpSecAvantFin    = 3;       // secondes avant la fin de la derniere bougie
input double InpOffsetLimit    = 0.30;    // distance de la limite au marche ($)
input int    InpExpirSec       = 120;     // annulation de la limite non touchee (s)
input double InpMaxSpread      = 0.50;    // spread max en $ (0 = off)
input int    InpMaxPositions   = 1;       // positions + limites simultanees (1 = une seule)

input group "=== TP / SL ($) ==="
input double InpTP_Tendance    = 4.0;     // TP TENDANCE / DEPART
input double InpTP_Range       = 0.50;    // TP RANGE
input double InpTP_Retourn     = 0.50;    // TP RETOURNEMENT
input double InpSL             = 8.0;     // SL en $

input group "=== Lot ==="
input double InpLotFixe        = 0.0;     // lot fixe (0 = risque %)
input double InpRisquePct      = 0.5;     // risque % equity par trade

input group "=== Divers ==="
input long   InpMagic          = 5720001;
input int    InpSlippage       = 30;

#define FEN        720
#define JAMBE      360
#define NFORMES    5
#define MAX_DIRECT 2000

// 0 TENDANCE 1 EPUISEMENT 2 DEPART 3 RETOURNEMENT 4 RANGE
string NOM_FORME[NFORMES] = {"TENDANCE","EPUISEMENT","DEPART","RETOURNEMENT","RANGE"};

double   g_c[];
datetime g_t[];
int      g_n = 0;

int      g_forme = -1, g_sens = 0;
double   g_zA = 0, g_zB = 0;

bool     g_pause = false;
double   g_tAngle = 0, g_tR2 = 0;

datetime g_barCache = 0;
datetime g_lastOrderBar = 0;

CTrade   trade;
