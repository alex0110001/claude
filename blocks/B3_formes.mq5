
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

// alignement sur la derniere cloture close : prix > SMA1 > SMA2 > SMA3 > SMA4 (+1) ou inverse (-1)
double SMAfin(const int p)
{
   double s = 0.0;
   for(int i = g_n - p; i < g_n; i++) s += g_c[i];
   return s / p;
}

void CalculerAlignement()
{
   g_align = 0;
   int pmax = MathMax(MathMax(InpSMA1, InpSMA2), MathMax(InpSMA3, InpSMA4));
   if(g_n < pmax) return;
   double c = g_c[g_n - 1];
   double m1 = SMAfin(InpSMA1), m2 = SMAfin(InpSMA2), m3 = SMAfin(InpSMA3), m4 = SMAfin(InpSMA4);
   if(c > m1 && m1 > m2 && m2 > m3 && m3 > m4) g_align = 1;
   else if(c < m1 && m1 < m2 && m2 < m3 && m3 < m4) g_align = -1;
}
