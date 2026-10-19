
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
