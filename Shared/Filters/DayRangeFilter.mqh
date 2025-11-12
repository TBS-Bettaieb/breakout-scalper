//+------------------------------------------------------------------+
//|                                             DayRangeFilter.mqh    |
//|                   Filtre par jours de la semaine pour le trading   |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Dans votre fichier .mq5 principal, ajoutez ces inputs :       |
//|    input group "=== Day Range Filter ==="                         |
//|    input bool UseDayFilter = false;                              |
//|    input string DayRanges = "1-5";                               |
//|                                                                   |
//| 2. Incluez ce fichier : #include "../Shared/DayRangeFilter.mqh"     |
//|                                                                   |
//| 3. Utilisez les fonctions :                                       |
//|    - IsDayRangeAllowed() : utilise UseDayFilter/DayRanges        |
//|    - IsDayRangeAllowed(enabled, ranges) : paramètres explicites  |
//|    - CurrentWeekDay() : jour actuel (0=Dim, 1=Lun...6=Sam)      |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - DayRanges="1-5" : trading du Lundi au Vendredi                 |
//| - DayRanges="0;6" : trading le Dimanche et Samedi                |
//| - DayRanges="1;3;5" : trading Lundi, Mercredi, Vendredi          |
//| - DayRanges="5-1" : trading Vendredi à Lundi (weekend)           |
//+------------------------------------------------------------------+
#property strict
// New architecture include
#include "ITimeFilter.mqh"

//---------------------------- Inputs (reusable) ---------------------
// ATTENTION DEVELOPPEUR : Pour utiliser ce DayRangeFilter dans votre EA, 
// vous devez AJOUTER ces inputs dans votre fichier .mq5 principal :
//
// input group "=== Day Range Filter ==="
// input bool UseDayFilter = false;              // Activer filtre par jour
// input string DayRanges = "1-5";              // Jours autorisés (0=Dim,1=Lun...6=Sam)
//
// Ces inputs ne peuvent PAS être définis dans un fichier .mqh (include)
// Ils doivent être dans le fichier .mq5 principal de votre EA.
//
// Exemple d'utilisation dans votre EA :
// 1. Ajoutez les inputs ci-dessus dans votre .mq5
// 2. Incluez ce fichier : #include "../Shared/DayRangeFilter.mqh"
// 3. Utilisez les fonctions : IsDayRangeAllowed(), CurrentWeekDay(), etc.
//
// Ces variables sont commentées ici car elles causeraient des erreurs de compilation
// si définies dans un fichier include (.mqh)
// input group "=== Day Range Filter ==="
// input bool UseDayFilter = false;              // Activer filtre par jour
// input string DayRanges = "1-5";              // Jours autorisés (0=Dim,1=Lun...6=Sam)

//+------------------------------------------------------------------+
//| Helpers globaux - Fonctions utilitaires                         |
//+------------------------------------------------------------------+
int CurrentWeekDay()
{
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt); return dt.day_of_week; // 0..6
}

//+------------------------------------------------------------------+
//| Fonction globale pour vérifier si un jour est dans les plages   |
//+------------------------------------------------------------------+
bool IsDayAllowedCustom(string ranges, int weekday)
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
         // Plage de jours (ex: "1-5")
         int startD = (int)StringToInteger(StringSubstr(token, 0, dash));
         int endD = (int)StringToInteger(StringSubstr(token, dash + 1));
         
         if(startD <= endD)
         {
            // Plage normale (ex: 1-5 = Lundi à Vendredi)
            if(weekday >= startD && weekday <= endD) return true;
         }
         else
         {
            // Plage chevauchant fin de semaine (ex: 5-1 = Vendredi à Lundi)
            if(weekday >= startD || weekday <= endD) return true;
         }
      }
      else
      {
         // Jour exact (ex: "1" = Lundi)
         int d = (int)StringToInteger(token);
         if(weekday == d) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Fonction principale de vérification par jours de la semaine      |
//| IMPORTANT: Cette fonction utilise les variables UseDayFilter     |
//| et DayRanges qui doivent être définies dans le fichier .mq5     |
//+------------------------------------------------------------------+
/*
bool IsDayRangeAllowed()
{
   // Si le filtre est désactivé, autoriser le trading
   if(!UseDayFilter) return true;
   
   int currentDay = CurrentWeekDay();
   return IsDayAllowedCustom(DayRanges, currentDay);
}
*/

//+------------------------------------------------------------------+
//| Fonction alternative avec paramètres explicites                 |
//| Utilisez cette fonction si vous préférez passer les paramètres  |
//| directement plutôt que d'utiliser les inputs globaux            |
//+------------------------------------------------------------------+
bool IsDayRangeAllowed(bool useFilter, string dayRanges)
{
   // Si le filtre est désactivé, autoriser le trading
   if(!useFilter) return true;
   
   int currentDay = CurrentWeekDay();
   return IsDayAllowedCustom(dayRanges, currentDay);
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres par jours de la semaine            |
//+------------------------------------------------------------------+
class DayRangeFilter : public ITimeFilter
{
private:
   // Configuration
   bool              m_enabled;
   string            m_configRanges;      // Ex: "1-5;0"  (0=Sun,1=Mon,..,6=Sat)
   bool              m_allowed[7];        // Parsed once
   int               m_lastLoggedDay;

   // Noms des jours pour l'affichage
   static string     m_dayNames[];

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   DayRangeFilter()
   {
      m_enabled = false;
      m_configRanges = "";
      m_lastLoggedDay = -1;
      m_logPrefix = "[DayRangeFilter] ";
      m_lastLoggedState = true;
      m_lastLogTime = 0;
      for(int i=0;i<7;i++) m_allowed[i] = true; // default allow all
      
      // Initialiser les noms des jours si pas encore fait
      if(ArraySize(m_dayNames) == 0)
      {
         ArrayResize(m_dayNames, 7);
         m_dayNames[0] = "Dimanche";
         m_dayNames[1] = "Lundi";
         m_dayNames[2] = "Mardi";
         m_dayNames[3] = "Mercredi";
         m_dayNames[4] = "Jeudi";
         m_dayNames[5] = "Vendredi";
         m_dayNames[6] = "Samedi";
      }
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   bool Initialize(bool enabled, string dayRanges)
   {
      m_enabled = enabled;
      m_configRanges = dayRanges;
      for(int i=0;i<7;i++) m_allowed[i] = true; // if empty -> allow all
      if(!enabled || dayRanges == "" || dayRanges == " ")
         return true;

      // reset and parse explicit config
      for(int j=0;j<7;j++) m_allowed[j] = false;

      string tokens[]; int n = StringSplit(dayRanges, ';', tokens);
      for(int k=0;k<n;k++)
      {
         string token = tokens[k]; StringTrimLeft(token); StringTrimRight(token);
         if(token == "") continue;
         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            int startD = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endD   = (int)StringToInteger(StringSubstr(token, dash + 1));
            if(startD < 0 || startD > 6 || endD < 0 || endD > 6) return false;
            if(startD <= endD)
            {
               for(int d=startD; d<=endD; d++) m_allowed[d] = true;
            }
            else
            {
               for(int d2=startD; d2<=6; d2++) m_allowed[d2] = true;
               for(int d3=0; d3<=endD; d3++) m_allowed[d3] = true;
            }
         }
         else
         {
            int d = (int)StringToInteger(token);
            if(d < 0 || d > 6) return false;
            m_allowed[d] = true;
         }
      }
      Print(m_logPrefix + "Initialized with day config: " + dayRanges);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Vérifications principales                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed() override
   {
      if(!m_enabled) return true;

      int currentDay = CurrentWeekDay();
      bool allowed = (currentDay >= 0 && currentDay < 7 ? m_allowed[currentDay] : true);
      if(!allowed && m_lastLoggedDay != currentDay)
      {
         string dayName = (currentDay >= 0 && currentDay < 7) ? m_dayNames[currentDay] : "Unknown";
         LogIfChanged(allowed, StringFormat("Trading blocked on %s (%d)", dayName, currentDay));
         m_lastLoggedDay = currentDay;
      }
      return allowed;
   }

   //+------------------------------------------------------------------+
   //| Helpers publics                                                  |
   //+------------------------------------------------------------------+
   int CurrentWeekDay()
   {
      MqlDateTime dt; TimeToStruct(TimeGMT(), dt); return dt.day_of_week; // 0..6
   }

   // Obtenir le nom du jour actuel
   string GetCurrentDayName()
   {
      int currentDay = CurrentWeekDay();
      return (currentDay >= 0 && currentDay < 7) ? m_dayNames[currentDay] : "Unknown";
   }

   // Obtenir le nom d'un jour par son index
   string GetDayName(int dayIndex)
   {
      return (dayIndex >= 0 && dayIndex < 7) ? m_dayNames[dayIndex] : "Unknown";
   }

   // Représentation humaine des plages configurées
   string Describe() const
   {
      if(!m_enabled) return "DayRange: Disabled";
      return "DayRange: Config [" + m_configRanges + "]";
   }

   // Obtenir les plages de jours configurées
   string GetDayRanges() const
   {
      return m_configRanges;
   }

   // Vérifier si le filtre est activé
   bool IsEnabled() const override
   {
      return m_enabled;
   }

   virtual string GetDescription() const override
   {
      if(!m_enabled) return "DayRange: Disabled";
      return "DayRange: Active";
   }

   virtual string GetStatusMessage() const override
   {
      if(!m_enabled) return "DayRange: OFF";
      return "DayRange: ON [" + m_configRanges + "]";
   }

private:
   //+------------------------------------------------------------------+
   //| Parsing "1-5;0" → test d'appartenance (0=Dim .. 6=Sam)         |
   //+------------------------------------------------------------------+
   bool IsDayAllowedCustom(string ranges, int weekday)
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
            // Plage de jours (ex: "1-5")
            int startD = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endD = (int)StringToInteger(StringSubstr(token, dash + 1));
            
            if(startD <= endD)
            {
               // Plage normale (ex: 1-5 = Lundi à Vendredi)
               if(weekday >= startD && weekday <= endD) return true;
            }
            else
            {
               // Plage chevauchant fin de semaine (ex: 5-1 = Vendredi à Lundi)
               if(weekday >= startD || weekday <= endD) return true;
            }
         }
         else
         {
            // Jour exact (ex: "1" = Lundi)
            int d = (int)StringToInteger(token);
            if(weekday == d) return true;
         }
      }
      return false;
   }
};

// Initialisation statique des noms de jours
static string DayRangeFilter::m_dayNames[];
