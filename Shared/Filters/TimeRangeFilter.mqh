//+------------------------------------------------------------------+
//|                                            TimeRangeFilter.mqh    |
//|                   Filtre par plages horaires pour le trading      |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Dans votre fichier .mq5 principal, ajoutez ces inputs :       |
//|    input group "=== Time Range Filter ==="                        |
//|    input bool UseTimeFilter = true;                               |
//|    input string HourRanges = "8-10;16";                          |
//|                                                                   |
//| 2. Incluez ce fichier : #include "../Shared/TimeRangeFilter.mqh"     |
//|                                                                   |
//| 3. Utilisez les fonctions :                                       |
//|    - IsTimeRangeAllowed() : utilise UseTimeFilter/HourRanges      |
//|    - IsTimeRangeAllowed(enabled, ranges) : paramètres explicites  |
//|    - CurrentHour() : heure actuelle                               |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - HourRanges="8-10;16" : trading de 8h-10h et 16h-17h            |
//| - HourRanges="22-6" : trading overnight de 22h à 6h              |
//| - HourRanges="9;14;20" : trading aux heures exactes              |
//+------------------------------------------------------------------+
#property strict

//---------------------------- Inputs (reusable) ---------------------
// ATTENTION DEVELOPPEUR : Pour utiliser ce TimeRangeFilter dans votre EA, 
// vous devez AJOUTER ces inputs dans votre fichier .mq5 principal :
//
// input group "=== Time Range Filter ==="
// input bool UseTimeFilter = true;               // Activer filtre horaire
// input string HourRanges = "8-10;16";          // Plages horaires (ex: 8-10;16)
//
// Ces inputs ne peuvent PAS être définis dans un fichier .mqh (include)
// Ils doivent être dans le fichier .mq5 principal de votre EA.
//
// Exemple d'utilisation dans votre EA :
// 1. Ajoutez les inputs ci-dessus dans votre .mq5
// 2. Incluez ce fichier : #include "../Shared/TimeRangeFilter.mqh"
// 3. Utilisez les fonctions : IsTimeRangeAllowed(), CurrentHour(), etc.
//
// Ces variables sont commentées ici car elles causeraient des erreurs de compilation
// si définies dans un fichier include (.mqh)
// input group "=== Time Range Filter ==="
// input bool UseTimeFilter = true;               // Activer filtre horaire
// input string HourRanges = "8-10;16";          // Plages horaires (ex: 8-10;16)

//+------------------------------------------------------------------+
//| Helpers globaux - Fonctions utilitaires                         |
//+------------------------------------------------------------------+
int CurrentHour()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); return dt.hour;
}

//+------------------------------------------------------------------+
//| Fonction globale pour vérifier si une heure est dans les plages |
//+------------------------------------------------------------------+
bool IsHourAllowedCustom(string ranges, int hour)
{
   if(ranges == "" || ranges == " ") return true; // rien => tout autorisé

   string tokens[]; int n = StringSplit(ranges, ';', tokens);
   for(int i = 0; i < n; i++)
   {
      string token = tokens[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      if(token == "") continue;

      int dash = StringFind(token, "-");
      if(dash >= 0)
      {
         // Plage d'heures (ex: "8-10")
         int startH = (int)StringToInteger(StringSubstr(token, 0, dash));
         int endH = (int)StringToInteger(StringSubstr(token, dash + 1));
         
         if(startH <= endH)
         {
            // Plage normale (ex: 8-10)
            if(hour >= startH && hour <= endH) return true;
         }
         else
         {
            // Plage chevauchant minuit (ex: 22-6)
            if(hour >= startH || hour <= endH) return true;
         }
      }
      else
      {
         // Heure exacte (ex: "16")
         int h = (int)StringToInteger(token);
         if(hour == h) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Fonction principale de vérification par plages horaires         |
//| IMPORTANT: Cette fonction utilise les variables UseTimeFilter    |
//| et HourRanges qui doivent être définies dans le fichier .mq5    |
//+------------------------------------------------------------------+
/*
bool IsTimeRangeAllowed()
{
   // Si le filtre est désactivé, autoriser le trading
   if(!UseTimeFilter) return true;
   
   int currentHour = CurrentHour();
   return IsHourAllowedCustom(HourRanges, currentHour);
}
*/

//+------------------------------------------------------------------+
//| Fonction alternative avec paramètres explicites                 |
//| Utilisez cette fonction si vous préférez passer les paramètres  |
//| directement plutôt que d'utiliser les inputs globaux            |
//+------------------------------------------------------------------+
bool IsTimeRangeAllowed(bool useFilter, string hourRanges)
{
   // Si le filtre est désactivé, autoriser le trading
   if(!useFilter) return true;
   
   int currentHour = CurrentHour();
   return IsHourAllowedCustom(hourRanges, currentHour);
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres par plages horaires                |
//+------------------------------------------------------------------+
class TimeRangeFilter
{
private:
   // Configuration
   bool              m_useFilter;
   string            m_hourRanges;        // Ex: "8-10;16;20-22"
   
   // Logging (anti-spam)
   int               m_lastLoggedHour;
   string            m_logPrefix;
   string            m_lastBlockReason;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TimeRangeFilter()
   {
      m_useFilter = false;
      m_hourRanges = "";
      m_lastLoggedHour = -1;
      m_logPrefix = "[TimeRangeFilter] ";
      m_lastBlockReason = "";
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void SetFilter(bool enabled, string ranges)
   {
      m_useFilter = enabled;
      m_hourRanges = ranges;
   }

   void SetLogPrefix(string prefix)
   {
      m_logPrefix = prefix;
   }

   // Chargement rapide depuis une configuration simple
   void InitFromInputs(bool useFilter, string hourRanges)
   {
      m_useFilter = useFilter;
      m_hourRanges = hourRanges;
   }

   //+------------------------------------------------------------------+
   //| Vérifications principales                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      if(!m_useFilter) return true;

      // Détection format minutes (ex: "08:30-10:45" ou compact "0830-1045")
      bool useMinuteFormat = RangesHasMinuteFormat(m_hourRanges);

      bool allowed;
      if(useMinuteFormat)
      {
         MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
         int currentMinutes = dt.hour * 60 + dt.min;
         allowed = IsTimeMinuteAllowedUnified(m_hourRanges, currentMinutes);
      }
      else
      {
         int currentHour = CurrentHour();
         allowed = IsHourAllowedCustom(m_hourRanges, currentHour);
      }

      if(!allowed && m_lastLoggedHour != CurrentHour())
      {
         Print(m_logPrefix + "Heure non autorisée: ", CurrentHour(), ":00 | Ranges: ", m_hourRanges);
         m_lastLoggedHour = CurrentHour();
         m_lastBlockReason = "Hour not in allowed ranges";
      }
      else if(allowed)
      {
         m_lastBlockReason = "";
      }

      return allowed;
   }

   //+------------------------------------------------------------------+
   //| Helpers publics                                                  |
   //+------------------------------------------------------------------+
   int CurrentHour() const
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); return dt.hour;
   }

   // Raison du blocage lors du dernier appel à IsTradingAllowed()
   string GetLastBlockReason() const
   {
      return m_lastBlockReason;
   }

   // Représentation humaine des plages configurées
   string Describe() const
   {
      if(!m_useFilter) return "Time range filter disabled";
      return "Hours: " + m_hourRanges;
   }

   // Obtenir les plages horaires configurées
   string GetHourRanges() const
   {
      return m_hourRanges;
   }

   // Vérifier si le filtre est activé
   bool IsEnabled() const
   {
      return m_useFilter;
   }

   // Vérifier le statut actuel (version const)
   bool IsCurrentlyActive() const
   {
      if(!m_useFilter) return true;

      // Détection format minutes (ex: "08:30-10:45" ou compact "0830-1045")
      bool useMinuteFormat = RangesHasMinuteFormat(m_hourRanges);

      bool allowed;
      if(useMinuteFormat)
      {
         MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
         int currentMinutes = dt.hour * 60 + dt.min;
         allowed = IsTimeMinuteAllowedUnified(m_hourRanges, currentMinutes);
      }
      else
      {
         int currentHour = CurrentHour();
         allowed = IsHourAllowedCustom(m_hourRanges, currentHour);
      }

      return allowed;
   }

   // Info pour affichage graphique
   string GetInfo() const
   {
      if(!m_useFilter) return "TimeRangeFilter: OFF";
      
      // Vérifier le statut sans modifier l'objet
      bool isActive = IsCurrentlyActive();
      string status = isActive ? "ACTIVE" : "INACTIVE";
      string info = "TimeRangeFilter: ON [" + m_hourRanges + "] | " + status;
      return info;
   }

private:
   //+------------------------------------------------------------------+
   //| Parsing "8-10;16;20-22" → test d'appartenance                   |
   //+------------------------------------------------------------------+
   bool IsHourAllowedCustom(string ranges, int hour) const
   {
      if(ranges == "" || ranges == " ") return true; // rien => tout autorisé

      string tokens[]; int n = StringSplit(ranges, ';', tokens);
      for(int i = 0; i < n; i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         if(token == "") continue;

         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            // Plage d'heures (ex: "8-10")
            int startH = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endH = (int)StringToInteger(StringSubstr(token, dash + 1));
            
            if(startH <= endH)
            {
               // Plage normale (ex: 8-10)
               if(hour >= startH && hour <= endH) return true;
            }
            else
            {
               // Plage chevauchant minuit (ex: 22-6)
               if(hour >= startH || hour <= endH) return true;
            }
         }
         else
         {
            // Heure exacte (ex: "16")
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
};
