
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
