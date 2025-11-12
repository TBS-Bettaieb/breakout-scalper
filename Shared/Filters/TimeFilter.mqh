//+------------------------------------------------------------------+
//|                                              TimeFilter.mqh       |
//|                   Filtre horaire et jours pour le trading         |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Dans votre fichier .mq5 principal, ajoutez ces inputs :       |
//|    input group "=== Time Filter ==="                              |
//|    input int SHInput = 7;  // Start Hour (0-23)                  |
//|    input int EHInput = 19; // End Hour (0-23)                     |
//|                                                                   |
//| 2. Incluez ce fichier : #include "../Shared/TimeFilter.mqh"       |
//|                                                                   |
//| 3. Utilisez les fonctions :                                       |
//|    - IsTradingAllowed() : utilise SHInput/EHInput automatiquement |
//|    - IsTradingAllowed(start, end) : paramètres explicites         |
//|    - CurrentHour() : heure actuelle                               |
//|    - TimeFilter class : filtres avancés                          |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - SHInput=7, EHInput=19 : trading de 7h à 19h                    |
//| - SHInput=22, EHInput=6 : trading de 22h à 6h (overnight)        |
//| - SHInput=0, EHInput=0 : pas de filtre horaire                   |
//+------------------------------------------------------------------+
#property strict

//---------------------------- Inputs (reusable) ---------------------
// ATTENTION DEVELOPPEUR : Pour utiliser ce TimeFilter dans votre EA, 
// vous devez AJOUTER ces inputs dans votre fichier .mq5 principal :
//
// input group "=== Time Filter ==="
// input int SHInput = 7;  // Start Hour (0 = Inactive, 1-23 = Active)
// input int EHInput = 19; // End Hour (0 = Inactive, 1-23 = Active)
//
// Ces inputs ne peuvent PAS être définis dans un fichier .mqh (include)
// Ils doivent être dans le fichier .mq5 principal de votre EA.
//
// Exemple d'utilisation dans votre EA :
// 1. Ajoutez les inputs ci-dessus dans votre .mq5
// 2. Incluez ce fichier : #include "../Shared/TimeFilter.mqh"
// 3. Utilisez les fonctions : IsTradingAllowed(), CurrentHour(), etc.
//
// Ces variables sont commentées ici car elles causeraient des erreurs de compilation
// si définies dans un fichier include (.mqh)
// input group "=== Time Filter ==="
// input int SHInput = 7;  // Start Hour (0 = Inactive, 1-23 = Active)
// input int EHInput = 19; // End Hour (0 = Inactive, 1-23 = Active)

//+------------------------------------------------------------------+
//| Helpers globaux - Fonctions utilitaires                         |
//+------------------------------------------------------------------+
int CurrentHour()
{
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt); return dt.hour;
}

//+------------------------------------------------------------------+
//| Fonction principale de vérification horaire                     |
//| IMPORTANT: Cette fonction utilise les variables SHInput et EHInput |
//| qui doivent être définies dans le fichier .mq5 principal        |
//+------------------------------------------------------------------+
/*
bool IsTradingAllowed()
{
   // This global variant expects SHInput/EHInput inputs defined in the main .mq5.
   // It is disabled here to avoid compilation when included without those inputs.
   return true;
}
*/

//+------------------------------------------------------------------+
//| Fonction alternative avec paramètres explicites                 |
//| Utilisez cette fonction si vous préférez passer les heures      |
//| directement plutôt que d'utiliser les inputs globaux            |
//+------------------------------------------------------------------+
bool IsTradingAllowed(int startHour, int endHour)
{
   int h = CurrentHour();
   
   if(startHour < endHour) 
   {
      // Plage normale même journée (ex: 8h-17h)
      return (h >= startHour && h <= endHour);
   }
   else if(startHour > endHour) 
   {
      // Plage overnight traverse minuit (ex: 22h-6h)
      return (h >= startHour || h <= endHour);
   }
   else 
   {
      // Pas de filtre ou égalité
      return true;
   }
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres temporels                           |
//+------------------------------------------------------------------+
class TimeFilter
{
private:
   // Configuration
   bool              m_useHourFilter;
   string            m_hourRanges;        // Ex: "8-10;16;20-22"
   bool              m_useDayFilter;
   string            m_dayRanges;         // Ex: "1-5;0"  (0=Dim,1=Lun,..,6=Sam)

   // Logging (anti-spam)
   int               m_lastLoggedHour;
   int               m_lastLoggedDay;
   string            m_logPrefix;
   string            m_lastBlockReason;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TimeFilter()
   {
      m_useHourFilter = false;
      m_hourRanges = "";
      m_useDayFilter = false;
      m_dayRanges = "";
      m_lastLoggedHour = -1;
      m_lastLoggedDay = -1;
      m_logPrefix = "[TimeFilter] ";
      m_lastBlockReason = "";
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void SetHourFilter(bool enabled, string ranges)
   {
      m_useHourFilter = enabled;
      m_hourRanges = ranges;
   }

   void SetDayFilter(bool enabled, string ranges)
   {
      m_useDayFilter = enabled;
      m_dayRanges = ranges;
   }

   void SetLogPrefix(string prefix)
   {
      m_logPrefix = prefix;
   }

   // Chargement rapide depuis une configuration simple Start/End hour
   void InitFromSimpleHours(int startHour, int endHour)
   {
      // 0/0 => pas de filtre; seulement start => start-23; seulement end => 0-end
      if(startHour <= 0 && endHour <= 0)
      {
         m_useHourFilter = false;
         m_hourRanges = "";
         return;
      }

      if(startHour > 0 && endHour > 0)
         m_hourRanges = IntegerToString(startHour) + "-" + IntegerToString(endHour);
      else if(startHour > 0)
         m_hourRanges = IntegerToString(startHour) + "-23";
      else // endHour > 0
         m_hourRanges = "0-" + IntegerToString(endHour);

      m_useHourFilter = true;
   }

   // Configuration par structure
   void Configure(bool useHour, string hourRanges, bool useDay, string dayRanges)
   {
      m_useHourFilter = useHour; m_hourRanges = hourRanges;
      m_useDayFilter = useDay;   m_dayRanges = dayRanges;
   }

   //+------------------------------------------------------------------+
   //| Vérifications principales                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      bool hourOk = IsHourAllowed();
      bool dayOk  = IsDayAllowed();
      if(!hourOk)
      {
         m_lastBlockReason = "Hour not allowed";
         return false;
      }
      if(!dayOk)
      {
         m_lastBlockReason = "Day not allowed";
         return false;
      }
      m_lastBlockReason = "";
      return true;
   }

   bool IsHourAllowed()
   {
      if(!m_useHourFilter) return true;

      // Détection format minutes (ex: "08:30-10:45" ou compact "0830-1045")
      bool useMinuteFormat = RangesHasMinuteFormat(m_hourRanges);

      bool allowed;
      int currentHourVal = CurrentHour();
      if(useMinuteFormat)
      {
         MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
         int currentMinutes = dt.hour * 60 + dt.min;
         allowed = IsTimeMinuteAllowedUnified(m_hourRanges, currentMinutes);
      }
      else
      {
         allowed = IsHourAllowedCustom(m_hourRanges, currentHourVal);
      }

      if(!allowed && m_lastLoggedHour != currentHourVal)
      {
         Print(m_logPrefix + "Heure non autorisée: ", currentHourVal, ":00 | Ranges: ", m_hourRanges);
         m_lastLoggedHour = currentHourVal;
      }

      return allowed;
   }

   bool IsDayAllowed()
   {
      if(!m_useDayFilter) return true;

      int currentDay = CurrentWeekDay();
      bool allowed = IsDayAllowedCustom(m_dayRanges, currentDay);

      if(!allowed && m_lastLoggedDay != currentDay)
      {
         static string dayNames[] = {"Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"};
         Print(m_logPrefix + "Jour non autorisé: ", dayNames[currentDay], " (", currentDay, ") | Ranges: ", m_dayRanges);
         m_lastLoggedDay = currentDay;
      }

      return allowed;
   }

   //+------------------------------------------------------------------+
   //| Helpers publics                                                  |
   //+------------------------------------------------------------------+
   int CurrentHour() const
   {
      MqlDateTime dt; TimeToStruct(TimeGMT(), dt); return dt.hour;
   }

   int CurrentWeekDay()
   {
      MqlDateTime dt; TimeToStruct(TimeGMT(), dt); return dt.day_of_week; // 0..6
   }

   // Raison du blocage lors du dernier appel à IsTradingAllowed()
   string GetLastBlockReason() const
   {
      return m_lastBlockReason;
   }

   // Représentation humaine des plages configurées
   string Describe() const
   {
      string txt = "";
      if(m_useHourFilter)  txt += "Hours: " + m_hourRanges;
      if(m_useDayFilter)   txt += (txt==""?"":" | ") + "Days: " + m_dayRanges;
      if(txt=="") txt = "No time filters";
      return txt;
   }

   // Vérifier le statut actuel (version const)
   bool IsCurrentlyActive() const
   {
      if(!m_useHourFilter && !m_useDayFilter) return true;

      // Vérifier les heures
      if(m_useHourFilter)
      {
         // Détection format minutes (ex: "08:30-10:45" ou compact "0830-1045")
         bool useMinuteFormat = RangesHasMinuteFormat(m_hourRanges);

         bool hourAllowed;
         if(useMinuteFormat)
         {
            MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
            int currentMinutes = dt.hour * 60 + dt.min;
            hourAllowed = IsTimeMinuteAllowedUnified(m_hourRanges, currentMinutes);
         }
         else
         {
            int currentHour = CurrentHour();
            hourAllowed = IsHourAllowedCustom(m_hourRanges, currentHour);
         }

         if(!hourAllowed) return false;
      }

      // Vérifier les jours
      if(m_useDayFilter)
      {
         int currentDay = CurrentWeekDay();
         if(!IsDayAllowedCustom(m_dayRanges, currentDay)) return false;
      }

      return true;
   }

   // Info pour affichage graphique
   string GetInfo() const
   {
      if(!m_useHourFilter && !m_useDayFilter) return "TimeFilter: OFF";
      
      // Vérifier le statut sans modifier l'objet
      bool isActive = IsCurrentlyActive();
      string status = isActive ? "ACTIVE" : "INACTIVE";
      string info = "TimeFilter: ON [" + Describe() + "] | " + status;
      return info;
   }

private:
   //+------------------------------------------------------------------+
   //| Parsing "8-10;16;20-22" → test d'appartenance                   |
   //+------------------------------------------------------------------+
   bool IsHourAllowedCustom(string ranges, int hour) const
   {
      if(ranges == "" ) return true; // rien => tout autorisé

      string tokens[]; int n = StringSplit(ranges, ';', tokens);
      for(int i=0;i<n;i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         if(token == "") continue;

         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            int startH = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endH   = (int)StringToInteger(StringSubstr(token, dash+1));
            if(startH <= endH)
            {
               if(hour >= startH && hour <= endH) return true;
            }
            else
            {
               // plage chevauchant minuit, ex: 22-2
               if(hour >= startH || hour <= endH) return true;
            }
         }
         else
         {
            int h = (int)StringToInteger(token);
            if(hour == h) return true;
         }
      }
      return false;
   }

   // Détecte si la chaîne contient un format minute (":" ou HHMM)
   bool RangesHasMinuteFormat(const string ranges) const
   {
      if(StringFind(ranges, ":") >= 0) return true;
      string tokens[]; int n = StringSplit(ranges, ';', tokens);
      for(int i=0;i<n;i++)
      {
         string t = tokens[i]; StringTrimLeft(t); StringTrimRight(t);
         if(t == "") continue;
         int dash = StringFind(t, "-");
         string a = (dash>=0? StringSubstr(t,0,dash): t);
         string b = (dash>=0? StringSubstr(t,dash+1): t);
         // Si un des segments est numérique de longueur >=3 (ex: 830, 1045) ⇒ minute
         if(IsAllDigits(a) && StringLen(a) >= 3) return true;
         if(IsAllDigits(b) && StringLen(b) >= 3) return true;
      }
      return false;
   }

   bool IsAllDigits(const string s) const
   {
      for(int i=0;i<StringLen(s);i++)
      {
         int ch = (uchar)StringGetCharacter(s,i);
         if(ch < '0' || ch > '9') return false;
      }
      return StringLen(s) > 0;
   }

   // Test d'appartenance avec précision minute
   bool IsTimeMinuteAllowedUnified(string ranges, int currentMinutes) const
   {
      if(ranges == "" || ranges == " ") return true;

      string tokens[]; int n = StringSplit(ranges, ';', tokens);
      for(int i=0;i<n;i++)
      {
         string token = tokens[i]; StringTrimLeft(token); StringTrimRight(token);
         if(token == "") continue;

         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            string startStr = StringSubstr(token, 0, dash);
            string endStr   = StringSubstr(token, dash+1);
            int startMin = ParseHHMMtoMinutes(startStr);
            int endMin   = ParseHHMMtoMinutes(endStr);
            if(startMin < 0 || endMin < 0) continue;

            if(startMin <= endMin)
            {
               if(currentMinutes >= startMin && currentMinutes <= endMin) return true;
            }
            else
            {
               // Traverse minuit
               if(currentMinutes >= startMin || currentMinutes <= endMin) return true;
            }
         }
         else
         {
            // Moment exact HH:MM ou HHMM
            int one = ParseHHMMtoMinutes(token);
            if(one >= 0 && currentMinutes == one) return true;
         }
      }
      return false;
   }

   // Accepte "HH:MM", "H:MM", ou compacts "HHMM"/"HMM"
   int ParseHHMMtoMinutes(string s) const
   {
      StringTrimLeft(s); StringTrimRight(s);
      int colon = StringFind(s, ":");
      int hh = 0, mm = 0;
      if(colon >= 0)
      {
         hh = (int)StringToInteger(StringSubstr(s,0,colon));
         mm = (int)StringToInteger(StringSubstr(s,colon+1));
      }
      else
      {
         // Compact: HMM ou HHMM
         int len = StringLen(s);
         if(len < 3 || len > 4) return -1;
         string hs = (len==3? StringSubstr(s,0,1): StringSubstr(s,0,2));
         string ms = (len==3? StringSubstr(s,1): StringSubstr(s,2));
         hh = (int)StringToInteger(hs);
         mm = (int)StringToInteger(ms);
      }
      if(hh < 0 || hh > 23 || mm < 0 || mm > 59) return -1;
      return hh*60 + mm;
   }

   //+------------------------------------------------------------------+
   //| Parsing "1-5;0" → test d'appartenance (0=Dim .. 6=Sam)         |
   //+------------------------------------------------------------------+
   bool IsDayAllowedCustom(string ranges, int weekday) const
   {
      if(ranges == "") return true;

      string tokens[]; int n = StringSplit(ranges, ';', tokens);
      for(int i=0;i<n;i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         if(token == "") continue;

         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            int startD = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endD   = (int)StringToInteger(StringSubstr(token, dash+1));
            if(startD <= endD)
            {
               if(weekday >= startD && weekday <= endD) return true;
            }
            else
            {
               // plage chevauchant fin de semaine, ex: 5-1 (Vendredi à Lundi)
               if(weekday >= startD || weekday <= endD) return true;
            }
         }
         else
         {
            int d = (int)StringToInteger(token);
            if(weekday == d) return true;
         }
      }
      return false;
   }
};
