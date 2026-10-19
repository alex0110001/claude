
//--- B7 : cycle, evenements ----------------------------------------------------

bool Rafraichir()
{
   g_forme = -1;
   if(!Charger()) return false;
   if(!Glissante()) return false;
   CalculerAlignement();
   g_pause = InpPauseT && DetecterT();
   Comment("FormesHasardEA ", _Symbol, "\n",
           "Forme : ", NOM_FORME[g_forme], "  sens ", g_sens, "  zA ", DoubleToString(g_zA, 2),
           "  zB ", DoubleToString(g_zB, 2), "  align ", g_align, "\n",
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
