//+------------------------------------------------------------------+
//|                                     RiskMultiplierManager.mqh   |
//|                    Gestionnaire de multiplication de risque      |
//|                                          (c) 2025 - Public Domain |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Structure pour une période de multiplication                    |
//+------------------------------------------------------------------+
struct RiskMultiplierPeriod {
   bool enabled;
   int startHour;
   int startMinute;
   int endHour;
   int endMinute;
   double multiplier;
   string description;
   string timeRanges;  // Format unifié: "08:30-10:45; 15:30-18:00"
};

//+------------------------------------------------------------------+
//| Classe RiskMultiplierManager                                    |
//+------------------------------------------------------------------+
class RiskMultiplierManager {
private:
   RiskMultiplierPeriod m_period;
   bool m_wasActive;
   datetime m_lastCheckTime;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   RiskMultiplierManager()
   {
      m_period.enabled = false;
      m_period.startHour = 0;
      m_period.startMinute = 0;
      m_period.endHour = 0;
      m_period.endMinute = 0;
      m_period.multiplier = 1.0;
      m_period.description = "";
      m_period.timeRanges = "";
      m_wasActive = false;
      m_lastCheckTime = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Initialiser le gestionnaire (ancien format - rétro-compatibilité) |
   //+------------------------------------------------------------------+
   void Initialize(bool enabled, int startHour, int startMinute, 
                   int endHour, int endMinute, double multiplier,
                   string description = "Risk Boost Period")
   {
      // Convertir l'ancien format vers le nouveau format unifié
      string timeRanges = StringFormat("%02d:%02d-%02d:%02d", startHour, startMinute, endHour, endMinute);
      InitializeUnified(enabled, timeRanges, multiplier, description);
   }

   //+------------------------------------------------------------------+
   //| Initialiser avec format unifié (ex: "08:30-10:45; 15:30-18:00") |
   //+------------------------------------------------------------------+
   void InitializeUnified(bool enabled, string timeRanges, double multiplier,
                         string description = "Risk Boost Period")
   {
      m_period.enabled = enabled;
      m_period.multiplier = MathMax(0.1, MathMin(10.0, multiplier));
      m_period.description = description;
      m_lastCheckTime = 0;
      
      // Stocker la chaîne de plages pour le parsing unifié
      m_period.timeRanges = timeRanges;
      
      if(m_period.enabled)
      {
         if(ValidateUnifiedRanges())
         {
            Logger::Success("🚀 RISK MULTIPLIER ACTIVÉ: " + description);
            Logger::Info("   Plages: " + timeRanges);
            Logger::Info("   Multiplicateur: x" + DoubleToString(m_period.multiplier, 2));
         }
         else
         {
            Logger::Error("❌ ERREUR: Configuration Risk Multiplier invalide");
            m_period.enabled = false;
         }
      }
      else
      {
         Logger::Info("ℹ️ Risk Multiplier DÉSACTIVÉ");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le multiplicateur actuel                                |
   //+------------------------------------------------------------------+
   double GetCurrentMultiplier()
   {
      if(!m_period.enabled) return 1.0;
      
      if(IsInActivePeriod())
         return m_period.multiplier;
      else
         return 1.0;
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si on est dans la période active                       |
   //+------------------------------------------------------------------+
   bool IsInActivePeriod()
   {
      if(!m_period.enabled) return false;
      
      // Si format unifié est utilisé
      if(m_period.timeRanges != "")
      {
         return IsInUnifiedRanges();
      }
      
      // Format classique (rétro-compatibilité)
      datetime currentTime = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      int currentMinutes = dt.hour * 60 + dt.min;
      int startMinutes = m_period.startHour * 60 + m_period.startMinute;
      int endMinutes = m_period.endHour * 60 + m_period.endMinute;
      
      // Gérer les périodes traversant minuit (ex: 22h-2h)
      if(endMinutes <= startMinutes)
      {
         // Période traverse minuit
         return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
      }
      else
      {
         // Période normale
         return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si le statut a changé                                  |
   //+------------------------------------------------------------------+
   bool HasStatusChanged()
   {
      datetime currentTime = TimeCurrent();
      
      // Vérifier chaque minute seulement
      if(currentTime - m_lastCheckTime < 60) return false;
      
      bool currentlyActive = IsInActivePeriod();
      
      if(m_wasActive != currentlyActive)
      {
         m_wasActive = currentlyActive;
         m_lastCheckTime = currentTime;
         
         if(currentlyActive)
         {
            Logger::Info("🟡 RISK MULTIPLIER ACTIVÉ: x" + DoubleToString(m_period.multiplier, 2) + 
                  " | Période: " + GetPeriodString());
         }
         else
         {
            Logger::Info("🔴 RISK MULTIPLIER DÉSACTIVÉ | Retour à x1.0");
         }
         
         return true;
      }
      
      m_lastCheckTime = currentTime;
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la description du statut                                |
   //+------------------------------------------------------------------+
   string GetStatusDescription()
   {
      if(!m_period.enabled)
         return "Risk Mult: OFF";
      
      double currentMultiplier = GetCurrentMultiplier();
      if(IsInActivePeriod())
         return StringFormat("Risk Mult: x%.1f", currentMultiplier);
      else
         return "Risk Mult: x1.0";
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo()
   {
      if(!m_period.enabled)
         return "Risk Multiplier: DISABLED";
      
      string info = "Risk Multiplier: " + m_period.description + "\n";
      info += "  Period: " + GetPeriodString() + "\n";
      info += "  Multiplier: x" + DoubleToString(m_period.multiplier, 2) + "\n";
      info += "  Status: " + (IsInActivePeriod() ? "ACTIVE" : "INACTIVE");
      
      return info;
   }

   
   //+------------------------------------------------------------------+
   //| Obtenir la chaîne de période formatée                           |
   //+------------------------------------------------------------------+
   string GetPeriodString()
   {
      if(m_period.timeRanges != "")
         return m_period.timeRanges;
      
      return StringFormat("%02d:%02d-%02d:%02d", 
                         m_period.startHour, m_period.startMinute,
                         m_period.endHour, m_period.endMinute);
   }

   //+------------------------------------------------------------------+
   //| Versions const des méthodes pour GetInfo()                      |
   //+------------------------------------------------------------------+
   double GetCurrentMultiplierConst() const
   {
      return m_period.enabled ? m_period.multiplier : 1.0;
   }

   bool IsInActivePeriodConst() const
   {
      if(!m_period.enabled) return false;

      // Utiliser le nouveau format unifié si disponible
      if(m_period.timeRanges != "")
      {
         return IsInUnifiedRanges();
      }

      // Fallback vers l'ancien format
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentMinutes = dt.hour * 60 + dt.min;
      int startMinutes = m_period.startHour * 60 + m_period.startMinute;
      int endMinutes = m_period.endHour * 60 + m_period.endMinute;

      if(startMinutes <= endMinutes)
      {
         return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
      }
      else
      {
         // Traverse minuit
         return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
      }
   }

   string GetPeriodStringConst() const
   {
      if(m_period.timeRanges != "")
         return m_period.timeRanges;
      
      return StringFormat("%02d:%02d-%02d:%02d", 
                         m_period.startHour, m_period.startMinute,
                         m_period.endHour, m_period.endMinute);
   }

   //+------------------------------------------------------------------+
   //| Info pour affichage graphique                                   |
   //+------------------------------------------------------------------+
   string GetInfo() const
   {
      if(!m_period.enabled) return "Risk Mult: OFF";
      
      // Vérifier le statut sans modifier l'objet
      double currentMultiplier = GetCurrentMultiplierConst();
      bool isActive = IsInActivePeriodConst();
      string ranges = GetPeriodStringConst();
      
      return StringFormat("Risk Mult: x%.1f [%s] | %s", 
                         currentMultiplier, ranges, isActive ? "ACTIVE" : "INACTIVE");
   }

private:
   //+------------------------------------------------------------------+
   //| Vérifier si on est dans les plages unifiées                     |
   //+------------------------------------------------------------------+
   bool IsInUnifiedRanges() const
   {
      if(m_period.timeRanges == "") return false;
      
      datetime currentTime = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      int currentMinutes = dt.hour * 60 + dt.min;
      return IsTimeInRanges(m_period.timeRanges, currentMinutes);
   }

   //+------------------------------------------------------------------+
   //| Test d'appartenance avec précision minute (format unifié)      |
   //+------------------------------------------------------------------+
   bool IsTimeInRanges(string ranges, int currentMinutes) const
   {
      if(ranges == "" || ranges == " ") return false;

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
            int startMin = ParseTimeToMinutes(startStr);
            int endMin   = ParseTimeToMinutes(endStr);
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
            // Moment exact
            int one = ParseTimeToMinutes(token);
            if(one >= 0 && currentMinutes == one) return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Parse "HH:MM" ou "HHMM" vers minutes                           |
   //+------------------------------------------------------------------+
   int ParseTimeToMinutes(string s) const
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
   //| Valider les plages unifiées                                     |
   //+------------------------------------------------------------------+
   bool ValidateUnifiedRanges()
   {
      if(m_period.timeRanges == "") return false;
      
      string tokens[]; int n = StringSplit(m_period.timeRanges, ';', tokens);
      bool hasValidRange = false;
      
      for(int i=0;i<n;i++)
      {
         string token = tokens[i]; StringTrimLeft(token); StringTrimRight(token);
         if(token == "") continue;

         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            string startStr = StringSubstr(token, 0, dash);
            string endStr   = StringSubstr(token, dash+1);
            int startMin = ParseTimeToMinutes(startStr);
            int endMin   = ParseTimeToMinutes(endStr);
            if(startMin >= 0 && endMin >= 0) hasValidRange = true;
         }
         else
         {
            int one = ParseTimeToMinutes(token);
            if(one >= 0) hasValidRange = true;
         }
      }
      
      return hasValidRange;
   }
};
