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

//--- B2 : barres M1 closes, filtre UTC ------------------------------------

// coupure [21:55, 23:05[ UTC, samedi, dimanche avant 23:05, vendredi des 21:55
bool Retenue(const datetime tu)
{
   MqlDateTime d;
   TimeToStruct(tu, d);
   int m = d.hour * 60 + d.min;
   if(d.day_of_week == 6) return false;
   if(d.day_of_week == 0 && m < 23 * 60 + 5) return false;
   if(d.day_of_week == 5 && m >= 21 * 60 + 55) return false;
   if(m >= 21 * 60 + 55 && m < 23 * 60 + 5) return false;
   return true;
}

bool Charger()
{
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int tot = Bars(_Symbol, PERIOD_M1);
   if(tot < FEN + 2) return false;
   int nb  = MathMin(tot, MAX_DIRECT + 1);
   int got = CopyRates(_Symbol, PERIOD_M1, 0, nb, r);
   if(got < FEN + 2) return false;
   int fermees = got - 1;                  // la barre en formation n'est jamais lue
   ArrayResize(g_c, fermees);
   ArrayResize(g_t, fermees);
   int k = 0;
   for(int i = 0; i < fermees; i++)
   {
      datetime tu = r[i].time + InpDecalageHeures * 3600;
      if(!Retenue(tu)) continue;
      g_c[k] = r[i].close;
      g_t[k] = tu;
      k++;
   }
   g_n = k;
   return (g_n >= FEN);
}

//--- B3 : fenetre 720, jambes A/B, forme -----------------------------------

int Classe(const double z)
{
   if(z >  InpSeuil) return  1;
   if(z < -InpSeuil) return -1;
   return 0;
}

int Forme(const int a, const int b)
{
   if(a != 0 && b == a)  return 0;   // TENDANCE
   if(a != 0 && b == 0)  return 1;   // EPUISEMENT
   if(a == 0 && b != 0)  return 2;   // DEPART
   if(a != 0 && b == -a) return 3;   // RETOURNEMENT
   return 4;                         // RANGE
}

int Sens(const int f, const int a, const int b)
{
   if(f == 0 || f == 1) return a;
   if(f == 2 || f == 3) return b;
   return 0;
}

// derniere fenetre close : barres e-719..e, e = derniere barre retenue
bool Glissante()
{
   if(g_n < FEN) return false;
   int e = g_n - 1;
   int s = e - (FEN - 1);
   double m1 = 0.0, m2 = 0.0;
   for(int i = s + 1; i <= e; i++)
   {
      double v = g_c[i] - g_c[i - 1];
      m1 += v;
      m2 += v * v;
   }
   int n = e - s;
   m1 /= n;
   m2 /= n;
   double sd  = MathSqrt(MathMax(m2 - m1 * m1, 1e-12));
   double den = sd * MathSqrt((double)JAMBE);
   double zA  = (g_c[s + JAMBE] - g_c[s]) / den;
   double zB  = (g_c[e] - g_c[s + JAMBE]) / den;
   int a = Classe(zA), b = Classe(zB);
   g_forme = Forme(a, b);
   g_sens  = Sens(g_forme, a, b);
   g_zA = zA;
   g_zB = zB;
   return true;
}

//--- B4 : Pattern T (pause) -------------------------------------------------
// N M1 consecutives sans minute manquante (fenetre + ATR avant), angle =
// atan(pente regression clotures / ATR), |angle| dans cible +-tol, R2 >= min.
// Hausses et baisses (miroir). Fenetre = les N dernieres barres closes.

bool DetecterT()
{
   int N = InpTBarres, P = InpTATR, tot = N + P;
   MqlRates r[];
   ArraySetAsSeries(r, false);
   g_tAngle = 0;
   g_tR2 = 0;
   if(CopyRates(_Symbol, PERIOD_M1, 1, tot, r) != tot) return false;
   for(int i = 1; i < tot; i++)
      if(r[i].time - r[i - 1].time != 60) return false;
   double atr = 0.0;
   for(int i = 0; i < P; i++) atr += r[i].high - r[i].low;
   atr /= P;
   if(atr <= 0.0) return false;
   double base = r[P].close;
   double sx = 0, sy = 0, sxy = 0, sxx = 0, syy = 0;
   for(int k = 0; k < N; k++)
   {
      double x = k, y = r[P + k].close - base;
      sx += x; sy += y; sxy += x * y; sxx += x * x; syy += y * y;
   }
   double dn = N * sxx - sx * sx;
   double dy = N * syy - sy * sy;
   if(dn <= 0.0 || dy <= 0.0) return false;
   double num   = N * sxy - sx * sy;
   double slope = num / dn;
   g_tR2    = num * num / (dn * dy);
   g_tAngle = MathArctan(slope / atr) * 180.0 / M_PI;
   double a  = MathAbs(g_tAngle);
   return (a >= InpTAngle * (1.0 - InpTTol) && a <= InpTAngle * (1.0 + InpTTol) && g_tR2 >= InpTR2Min);
}

//--- B5 : helpers trade ------------------------------------------------------

double Nrm(const double p)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   return NormalizeDouble(MathRound(p / tick) * tick, _Digits);
}

// positions + ordres limites de ce symbole / magic
int Exposition()
{
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic) n++;
   }
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagic) n++;
   }
   return n;
}

double CalcLot(const double slDist)
{
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot   = InpLotFixe;
   if(lot <= 0.0)
   {
      double tv   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double ts   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tv <= 0.0 || ts <= 0.0 || slDist <= 0.0) return 0.0;
      double risque  = AccountInfoDouble(ACCOUNT_EQUITY) * InpRisquePct / 100.0;
      double perteLot = slDist / ts * tv;
      lot = risque / perteLot;
   }
   if(vstep > 0.0) lot = MathFloor(lot / vstep) * vstep;
   lot = MathMax(vmin, MathMin(vmax, lot));
   return NormalizeDouble(lot, 2);
}

// pose une limite dans le sens voulu : vente au-dessus du bid, achat sous l'ask
bool Poser(const bool vente, const double tpDist)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return false;
   if(InpMaxSpread > 0.0 && ask - bid > InpMaxSpread) return false;

   double lvl = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;
   double off = MathMax(InpOffsetLimit, lvl + 2 * _Point);
   double tp  = MathMax(tpDist, lvl + _Point);
   double sl  = MathMax(InpSL,  lvl + _Point);

   double prix = Nrm(vente ? bid + off : ask - off);
   double sP   = Nrm(vente ? prix + sl : prix - sl);
   double tP   = Nrm(vente ? prix - tp : prix + tp);

   double lot = CalcLot(sl);
   if(lot <= 0.0) return false;
   double marge = 0.0;
   if(OrderCalcMargin(vente ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_BUY_LIMIT, _Symbol, lot, prix, marge)
      && marge > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      Print("FormesHasardEA : marge insuffisante, lot ", lot);
      return false;
   }

   bool ok = vente ? trade.SellLimit(lot, prix, _Symbol, sP, tP, ORDER_TIME_GTC, 0, "FH " + NOM_FORME[g_forme])
                   : trade.BuyLimit (lot, prix, _Symbol, sP, tP, ORDER_TIME_GTC, 0, "FH " + NOM_FORME[g_forme]);
   if(!ok)
      Print("FormesHasardEA : ordre refuse, retcode ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   return ok;
}

// annule les limites trop vieilles, ou toutes pendant la pause T
void GererOrdres()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      long age = (long)(TimeTradeServer() - (datetime)OrderGetInteger(ORDER_TIME_SETUP));
      if(g_pause || age > InpExpirSec) trade.OrderDelete(tk);
   }
}

//--- B6 : signal d'entree ----------------------------------------------------
// N bougies M1 de meme sens (la derniere encore en formation), chacune de
// taille high-low > InpTailleMin, sans minute manquante.

bool Sequence(const bool haussier)
{
   int N = InpNbConsec;
   MqlRates r[];
   ArraySetAsSeries(r, false);
   if(CopyRates(_Symbol, PERIOD_M1, 0, N, r) != N) return false;
   if(r[N - 1].time - r[0].time != (N - 1) * 60) return false;
   for(int i = 0; i < N; i++)
   {
      if(r[i].high - r[i].low <= InpTailleMin) return false;
      if(haussier ? (r[i].close <= r[i].open) : (r[i].close >= r[i].open)) return false;
   }
   return true;
}

double TpForme()
{
   if(g_forme == 4) return InpTP_Range;
   if(g_forme == 3) return InpTP_Retourn;
   return InpTP_Tendance;
}

// tendance baissiere (ou range) + N haussieres -> SELL LIMIT
// tendance haussiere (ou range) + N baissieres -> BUY LIMIT
void Entree(const datetime b)
{
   if(g_forme < 0 || g_forme == 1) return;        // EPUISEMENT : pas d'entree
   if(b == g_lastOrderBar) return;
   long sec = (long)(TimeTradeServer() - b);
   if(sec < 60 - InpSecAvantFin || sec >= 60) return;
   if(Exposition() >= InpMaxPositions) return;

   bool vente = (g_forme == 4 || g_sens < 0) && Sequence(true);
   bool achat = (g_forme == 4 || g_sens > 0) && Sequence(false);
   if(!vente && !achat) return;

   g_lastOrderBar = b;                             // un seul essai par barre
   Poser(vente, TpForme());
}

//--- B7 : cycle, evenements ----------------------------------------------------

bool Rafraichir()
{
   g_forme = -1;
   if(!Charger()) return false;
   if(!Glissante()) return false;
   g_pause = InpPauseT && DetecterT();
   Comment("FormesHasardEA ", _Symbol, "\n",
           "Forme : ", NOM_FORME[g_forme], "  sens ", g_sens, "  zA ", DoubleToString(g_zA, 2),
           "  zB ", DoubleToString(g_zB, 2), "\n",
           "T : angle ", DoubleToString(g_tAngle, 1), "  R2 ", DoubleToString(g_tR2, 3),
           (g_pause ? "  -> PAUSE" : "  -> actif"));
   return true;
}

void Pas()
{
   datetime b = iTime(_Symbol, PERIOD_M1, 0);
   if(b == 0) return;
   if(b != g_barCache)
   {
      if(!Rafraichir()) return;                    // historique pas pret : nouvel essai
      g_barCache = b;
   }
   GererOrdres();
   if(g_pause) return;
   Entree(b);
}

int OnInit()
{
   if(InpNbConsec < 1 || InpSecAvantFin < 1 || InpSecAvantFin > 30 || InpMaxPositions < 1
      || InpTBarres < 3 || InpTATR < 1)
      return INIT_PARAMETERS_INCORRECT;
   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Comment("");
}

void OnTimer() { Pas(); }
void OnTick()  { Pas(); }
