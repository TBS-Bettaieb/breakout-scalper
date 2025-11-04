//+------------------------------------------------------------------+
//|                                        TradingTimeManager.mqh    |
//|                   Gestionnaire centralisé des filtres temporels   |
//|                   avec architecture modulaire et filtres NULL-safe |
//|                                                                   |
//| VERSION MODULAIRE - Filtres séparés et initialisation à la carte  |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ChartManager.mqh AVANT ce fichier                     |
//| 2. Initialisez uniquement les filtres nécessaires               |
//| 3. Les filtres NULL sont automatiquement ignorés (sécurité)      |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "2.0"
#property strict

// Include ChartManager pour utiliser ses méthodes
#include "ChartManager.mqh"

// Interface en premier
#include "Filters/ITimeFilter.mqh"

// Implémentations ensuite
#include "Filters/TimeRangeFilter.mqh"
#include "Filters/DayRangeFilter.mqh"
#include "Filters/SessionFilter.mqh"
#include "Filters/NewsFilter.mqh"
#include "Filters/TimeMinuteFilter.mqh"

//+------------------------------------------------------------------+
//| Énumération des états du trading                                |
//+------------------------------------------------------------------+
enum ENUM_TRADING_STATUS
{
   TRADING_ACTIVE,               // Trading actif
   TRADING_BLOCKED_HOUR,         // Bloqué par filtre horaire
   TRADING_BLOCKED_DAY,          // Bloqué par filtre jour
   TRADING_BLOCKED_SESSION,      // Bloqué par filtre session
   TRADING_BLOCKED_NEWS,         // Bloqué par filtre news
   TRADING_BLOCKED_TIME_MINUTE,  // Bloqué par filtre minute
   TRADING_BLOCKED_MULTIPLE,     // Plusieurs filtres bloqués
   TRADING_BLOCKED_BOTH          // Bloqué par les deux filtres (compatibilité)
};

//+------------------------------------------------------------------+
//| Classe de gestion centralisée des filtres temporels             |
//| Architecture modulaire avec filtres NULL-safe                   |
//+------------------------------------------------------------------+
class TradingTimeManager
{
private:
   // Polymorphic filters (new architecture)
   ITimeFilter*         m_filters[];
   
   // Chart Manager pour l'affichage
   ChartManager*        m_chartManager;
   
   // Configuration affichage
   bool                 m_showVisualAlerts;
   
   // État
   ENUM_TRADING_STATUS  m_currentStatus;
   ENUM_TRADING_STATUS  m_lastStatus;
   datetime             m_lastAlertTime;
   int                  m_lastLoggedHour;
   int                  m_lastLoggedDay;
   
   // Messages personnalisés
   string               m_hourBlockMessage;
   string               m_dayBlockMessage;
   string               m_bothBlockMessage;
   
   // Logging
   string               m_logPrefix;
   bool                 m_verboseLogging;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TradingTimeManager(ChartManager* chartMgr = NULL)
   {
      ArrayResize(m_filters, 0);
      
      m_chartManager = chartMgr;
      
      m_showVisualAlerts = true;
      
      m_currentStatus = TRADING_ACTIVE;
      m_lastStatus = TRADING_ACTIVE;
      m_lastAlertTime = 0;
      m_lastLoggedHour = -1;
      m_lastLoggedDay = -1;
      
      m_hourBlockMessage = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_dayBlockMessage = "📅 TRADING PAUSED - Outside Trading Days";
      m_bothBlockMessage = "🚫 TRADING PAUSED - Outside Trading Schedule";
      
      m_logPrefix = "[TradingTimeManager] ";
      m_verboseLogging = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~TradingTimeManager()
   {
      // Cleanup polymorphic filters
      for(int i=0;i<ArraySize(m_filters);i++)
      {
         if(m_filters[i] != NULL) { delete m_filters[i]; m_filters[i] = NULL; }
      }
      ArrayFree(m_filters);
      
      // Ne pas supprimer m_chartManager car il est géré ailleurs
      HideAlert();
   }

   // (Legacy Initialize/Init* methods removed)

   //+------------------------------------------------------------------+
   //| Attacher un ChartManager                                         |
   //+------------------------------------------------------------------+
   void AttachChartManager(ChartManager* chartMgr)
   {
      m_chartManager = chartMgr;
   }

   // Ajouter un filtre polymorphique (nouvelle architecture)
   bool AddFilter(ITimeFilter* filter)
   {
      if(filter == NULL)
      {
         Print("[TradingTimeManager] ERROR: Cannot add NULL filter");
         return false;
      }
      if(!filter.IsEnabled())
      {
         Print("[TradingTimeManager] WARNING: Filter is disabled, not adding");
         delete filter;
         return false;
      }
      int sz = ArraySize(m_filters);
      ArrayResize(m_filters, sz + 1);
      m_filters[sz] = filter;
      Print("[TradingTimeManager] ✅ Filter added: ", filter.GetDescription());
      return true;
   }

   //+------------------------------------------------------------------+
   //| Vérification principale du trading                              |
   //| Architecture modulaire avec gestion NULL-safe                  |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      // Utiliser uniquement les filtres polymorphiques
      for(int i=0;i<ArraySize(m_filters);i++)
      {
         if(m_filters[i] != NULL && m_filters[i].IsEnabled())
         {
            if(!m_filters[i].IsTradingAllowed())
            {
               // Identifier le type de filtre qui bloque
               ENUM_TRADING_STATUS blockStatus = IdentifyFilterStatus(m_filters[i]);
               UpdateStatus(blockStatus);
               return false;
            }
         }
      }
      UpdateStatus(TRADING_ACTIVE);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Vérification rapide sans mise à jour de l'affichage             |
   //+------------------------------------------------------------------+
  // (IsTradingAllowedQuick removed in polymorphic-only architecture)

   //+------------------------------------------------------------------+
   //| Obtenir le statut actuel                                        |
   //+------------------------------------------------------------------+
   ENUM_TRADING_STATUS GetCurrentStatus() const
   {
      return m_currentStatus;
   }

   //+------------------------------------------------------------------+
   //| Obtenir une description du statut                               |
   //+------------------------------------------------------------------+
   string GetStatusDescription() const
   {
      switch(m_currentStatus)
      {
         case TRADING_ACTIVE:
            return "Trading Active";
         case TRADING_BLOCKED_HOUR:
            return "Blocked (Time)";
         case TRADING_BLOCKED_DAY:
            return "Blocked (Day)";
         case TRADING_BLOCKED_SESSION:
            return "Blocked (Session)";
         case TRADING_BLOCKED_NEWS:
            return "Blocked (News)";
         case TRADING_BLOCKED_TIME_MINUTE:
            return "Blocked (TimeMinute)";
         case TRADING_BLOCKED_MULTIPLE:
            return "Blocked (Multiple)";
         case TRADING_BLOCKED_BOTH:
            return "Blocked (Time & Day)";
         default:
            return "Unknown";
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir des informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo() const
   {
      string info = "=== Trading Time Manager (Modular) ===\n";
      info += "Status: " + GetStatusDescription() + "\n";
      
      // Afficher les filtres actifs
      info += "Active Filters:\n";
      if(ArraySize(m_filters) > 0)
      {
         for(int i=0;i<ArraySize(m_filters);i++)
         {
            if(m_filters[i] != NULL && m_filters[i].IsEnabled())
               info += "  ✓ " + m_filters[i].GetDescription() + "\n";
         }
      }
      
      // Informations actuelles
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      
      string dayNames[] = {"Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"};
      string currentDay = (dt.day_of_week >= 0 && dt.day_of_week < 7) ? dayNames[dt.day_of_week] : "Unknown";
      
      info += StringFormat("Current: %s %02d:%02d", currentDay, dt.hour, dt.min);
      
      return info;
   }

   //+------------------------------------------------------------------+
   //| Configuration des messages personnalisés                        |
   //+------------------------------------------------------------------+
   void SetAlertMessages(
      string hourBlockMsg = "",
      string dayBlockMsg = "",
      string bothBlockMsg = ""
   )
   {
      if(hourBlockMsg != "") m_hourBlockMessage = hourBlockMsg;
      if(dayBlockMsg != "") m_dayBlockMessage = dayBlockMsg;
      if(bothBlockMsg != "") m_bothBlockMessage = bothBlockMsg;
   }

   //+------------------------------------------------------------------+
   //| Activer/désactiver les alertes visuelles                        |
   //+------------------------------------------------------------------+
   void SetVisualAlerts(bool enabled)
   {
      m_showVisualAlerts = enabled;
      
      // Si on désactive, masquer l'alerte en cours
      if(!enabled)
      {
         HideAlert();
      }
   }

   //+------------------------------------------------------------------+
   //| Activer/désactiver le logging verbeux                           |
   //+------------------------------------------------------------------+
   void SetVerboseLogging(bool enabled)
   {
      m_verboseLogging = enabled;
   }

   //+------------------------------------------------------------------+
   //| Forcer la mise à jour de l'affichage                            |
   //+------------------------------------------------------------------+
   void RefreshDisplay()
   {
      UpdateStatus(m_currentStatus, true);
   }

   //+------------------------------------------------------------------+
   //| Masquer l'alerte manuellement                                   |
   //+------------------------------------------------------------------+
   void HideAlert()
   {
      if(m_chartManager != NULL)
      {
         m_chartManager.HideAlert();
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir l'heure actuelle                                        |
   //+------------------------------------------------------------------+
   int GetCurrentHour()
   {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      return dt.hour;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le jour de la semaine actuel                            |
   //+------------------------------------------------------------------+
   int GetCurrentWeekDay()
   {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      return dt.day_of_week;
   }

private:
   // (All legacy private Is*Allowed helpers removed)

   //+------------------------------------------------------------------+
   //| Identifier le type de filtre qui bloque                         |
   //+------------------------------------------------------------------+
   ENUM_TRADING_STATUS IdentifyFilterStatus(ITimeFilter* filter)
   {
      if(filter == NULL) return TRADING_BLOCKED_MULTIPLE;
      
      string desc = filter.GetDescription();
      
      // Détecter le type de filtre par sa description
      if(StringFind(desc, "TimeRange") >= 0)
         return TRADING_BLOCKED_HOUR;
      else if(StringFind(desc, "DayRange") >= 0)
         return TRADING_BLOCKED_DAY;
      else if(StringFind(desc, "Session") >= 0)
         return TRADING_BLOCKED_SESSION;
      else if(StringFind(desc, "News") >= 0)
         return TRADING_BLOCKED_NEWS;
      else if(StringFind(desc, "TimeMinute") >= 0)
         return TRADING_BLOCKED_TIME_MINUTE;
      else
         return TRADING_BLOCKED_MULTIPLE;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour le statut et afficher l'alerte si nécessaire      |
   //+------------------------------------------------------------------+
   void UpdateStatus(ENUM_TRADING_STATUS newStatus, bool forceUpdate = false)
   {
      bool statusChanged = (newStatus != m_lastStatus);
      
      // Mettre à jour le statut actuel
      m_currentStatus = newStatus;
      
      // Afficher une alerte si nécessaire
      if(m_showVisualAlerts && m_chartManager != NULL)
      {
         if(newStatus == TRADING_ACTIVE)
         {
            // Si on revient en mode actif, masquer l'alerte
            if(statusChanged)
            {
               m_chartManager.HideAlert();
               
               if(m_verboseLogging)
                  Print(m_logPrefix + "✅ Trading resumed - All filters passed");
            }
         }
         else
         {
            // Afficher l'alerte de blocage
            datetime currentTime = TimeGMT();
            
            // Mettre à jour l'alerte toutes les 5 minutes ou si le statut change
            if(forceUpdate || statusChanged || (currentTime - m_lastAlertTime) >= 300)
            {
               string alertMessage = GetBlockMessage(newStatus);
               color alertColor = GetBlockColor(newStatus);
               
               m_chartManager.ShowAlert(alertMessage, alertColor, 18);
               m_lastAlertTime = currentTime;
               
               if(m_verboseLogging && statusChanged)
                  Print(m_logPrefix + "🚫 " + alertMessage);
            }
         }
      }
      
      m_lastStatus = newStatus;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le message de blocage approprié                         |
   //+------------------------------------------------------------------+
   string GetBlockMessage(ENUM_TRADING_STATUS status)
   {
      switch(status)
      {
         case TRADING_BLOCKED_HOUR:
            return m_hourBlockMessage;
         case TRADING_BLOCKED_DAY:
            return m_dayBlockMessage;
         case TRADING_BLOCKED_SESSION:
            return "📊 TRADING PAUSED - Outside Trading Session";
         case TRADING_BLOCKED_NEWS:
            return "📰 TRADING PAUSED - News Event Detected";
         case TRADING_BLOCKED_TIME_MINUTE:
            return "⏱️ TRADING PAUSED - Outside Time Minute Range";
         case TRADING_BLOCKED_MULTIPLE:
            return "🚫 TRADING PAUSED - Multiple Filters Blocked";
         case TRADING_BLOCKED_BOTH:
            return m_bothBlockMessage;
         default:
            return "Trading Status Unknown";
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir la couleur de l'alerte selon le statut                  |
   //+------------------------------------------------------------------+
   color GetBlockColor(ENUM_TRADING_STATUS status)
   {
      switch(status)
      {
         case TRADING_BLOCKED_HOUR:
            return clrOrange;
         case TRADING_BLOCKED_DAY:
            return clrOrange;
         case TRADING_BLOCKED_SESSION:
            return clrBlue;
         case TRADING_BLOCKED_NEWS:
            return clrMagenta;
         case TRADING_BLOCKED_TIME_MINUTE:
            return clrCyan;
         case TRADING_BLOCKED_MULTIPLE:
            return clrRed;
         case TRADING_BLOCKED_BOTH:
            return clrRed;
         default:
            return clrWhite;
      }
   }
};