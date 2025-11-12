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
// New architecture includes
#include "ITimeFilter.mqh"
#include "../Utils/TimeRangeParser.mqh"

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
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt); return dt.hour;
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
class TimeRangeFilter : public ITimeFilter
{
private:
   bool       m_enabled;
   string     m_configRanges;
   TimeRange  m_ranges[];   // Parsed once at initialization

public:
   TimeRangeFilter() : m_enabled(false)
   {
      m_logPrefix = "[TimeRangeFilter] ";
      m_lastLoggedState = true;
      m_lastLogTime = 0;
      m_configRanges = "";
      ArrayFree(m_ranges);
   }

   bool Initialize(bool enabled, string rangeString)
   {
      m_enabled = enabled;
      m_configRanges = rangeString;
      if(!enabled || rangeString == "")
      {
         ArrayFree(m_ranges);
         return true;
      }

      if(!TimeRangeParser::ParseRanges(rangeString, m_ranges))
      {
         Print(m_logPrefix + "ERROR: Invalid range format: " + rangeString);
         return false;
      }

      Print(m_logPrefix + "Initialized with " + IntegerToString(ArraySize(m_ranges)) + " ranges");
      return true;
   }

   virtual bool IsTradingAllowed() override
   {
      if(!m_enabled || ArraySize(m_ranges) == 0)
         return true;

      MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
      int currentMinutes = dt.hour * 60 + dt.min;

      bool allowed = TimeRangeParser::IsInRanges(currentMinutes, m_ranges);
      if(!allowed)
      {
         LogIfChanged(allowed, StringFormat("Trading blocked at %02d:%02d", dt.hour, dt.min));
      }
      return allowed;
   }

   virtual bool IsEnabled() const override { return m_enabled; }

   virtual string GetDescription() const override
   {
      if(!m_enabled) return "TimeRange: Disabled";
      return "TimeRange: " + IntegerToString(ArraySize(m_ranges)) + " ranges active";
   }

   virtual string GetStatusMessage() const override
   {
      if(!m_enabled) return "TimeRange: OFF";
      return "TimeRange: ON [" + m_configRanges + "]";
   }
};
