
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
