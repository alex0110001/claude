
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
