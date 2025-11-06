//+------------------------------------------------------------------+
//|                                  TestTradingTimeManager.mq5       |
//|                      EA de Test pour TradingTimeManager            |
//|                  Validation de l'architecture modulaire            |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Includes nécessaires                                             |
//+------------------------------------------------------------------+
#include "Shared/TradingTimeManager.mqh"
#include "Shared/ChartManager.mqh"
#include "Shared/Filters/TimeRangeFilter.mqh"
#include "Shared/Filters/DayRangeFilter.mqh"
#include "Shared/Filters/SessionFilter.mqh"
#include "Shared/Filters/NewsFilter.mqh"
#include "Shared/Filters/TimeMinuteFilter.mqh"

// (Wrapper TimeMinuteFilter supprimé — le filtre hérite désormais de ITimeFilter)

//+------------------------------------------------------------------+
//| Énumération des configurations de test                          |
//+------------------------------------------------------------------+
enum ENUM_TEST_CONFIG
{
   CONFIG_BUSINESS_HOURS,      // Test 1: Heures ouvrables standard (8h-17h, Lun-Ven)
   CONFIG_NIGHT_TRADING,       // Test 2: Trading nocturne (22h-6h)
   CONFIG_OVERLAP_SESSION,     // Test 3: Session chevauchement London-US
   CONFIG_WEEKEND_WARRIOR,     // Test 4: Trading weekend uniquement
   CONFIG_MINUTE_PRECISION,    // Test 5: Précision à la minute (9:30-11:45)
   CONFIG_NEWS_ONLY,           // Test 6: NewsFilter uniquement (USD,EUR)
   CONFIG_ALL_FILTERS,         // Test 7: Tous les filtres combinés
   CONFIG_NO_FILTERS           // Test 8: Aucun filtre (24/7)
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Configuration de Test ==="
input ENUM_TEST_CONFIG TestConfig = CONFIG_BUSINESS_HOURS;  // Configuration à tester
input bool ShowVisualAlerts = true;                         // Afficher alertes visuelles
input bool VerboseLogging = true;                           // Logs détaillés

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
TradingTimeManager* g_timeManager = NULL;
ChartManager* g_chartManager = NULL;
ENUM_TEST_CONFIG g_currentConfig;
datetime g_lastStatusChange = 0;
ENUM_TRADING_STATUS g_lastStatus = TRADING_ACTIVE;
int g_statusChangeCount = 0;

//+------------------------------------------------------------------+
//| Noms des configurations pour affichage                           |
//+------------------------------------------------------------------+
string GetConfigName(ENUM_TEST_CONFIG config)
{
   switch(config)
   {
      case CONFIG_BUSINESS_HOURS:   return "Business Hours (8h-17h, Lun-Ven)";
      case CONFIG_NIGHT_TRADING:    return "Night Trading (22h-6h)";
      case CONFIG_OVERLAP_SESSION:  return "Overlap Session (13h-16h)";
      case CONFIG_WEEKEND_WARRIOR:  return "Weekend Warrior (Sam-Dim)";
      case CONFIG_MINUTE_PRECISION: return "Minute Precision (9:30-11:45;14:00-16:30)";
      case CONFIG_NEWS_ONLY:        return "News Filter Only (USD,EUR)";
      case CONFIG_ALL_FILTERS:      return "All Filters Combined";
      case CONFIG_NO_FILTERS:      return "No Filters (24/7)";
      default:                      return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Fonction d'initialisation                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Créer ChartManager
   g_chartManager = new ChartManager(0, "TestTTM");
   if(g_chartManager == NULL)
   {
      Print("❌ ERREUR: Échec création ChartManager");
      return INIT_FAILED;
   }
   
   // 2. Créer TradingTimeManager
   g_timeManager = new TradingTimeManager(g_chartManager);
   if(g_timeManager == NULL)
   {
      Print("❌ ERREUR: Échec création TradingTimeManager");
      delete g_chartManager;
      g_chartManager = NULL;
      return INIT_FAILED;
   }
   
   // 3. Configurer le logging
   g_timeManager.SetVerboseLogging(VerboseLogging);
   g_timeManager.SetVisualAlerts(ShowVisualAlerts);
   
   // 4. Charger la configuration sélectionnée
   g_currentConfig = TestConfig;
   if(!LoadConfiguration(g_currentConfig))
   {
      Print("❌ ERREUR: Échec chargement configuration");
      return INIT_FAILED;
   }
   
   // 5. Afficher infos de démarrage
   Print("╔════════════════════════════════════════════════════════════╗");
   Print("║   🧪 TEST TRADING TIME MANAGER - INITIALISATION            ║");
   Print("╠════════════════════════════════════════════════════════════╣");
   Print("║  Configuration: ", GetConfigName(g_currentConfig));
   Print("║  Verbose Logging: ", (VerboseLogging ? "ON" : "OFF"));
   Print("║  Visual Alerts: ", (ShowVisualAlerts ? "ON" : "OFF"));
   Print("╚════════════════════════════════════════════════════════════╝");
   
   // 6. Afficher les détails
   Print(g_timeManager.GetDetailedInfo());
   
   // 7. Afficher sur le graphique
   DisplayStartupInfo();
   
   Print("✅ TestTradingTimeManager initialisé avec succès");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Fonction de déinitialisation                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Nettoyage
   if(g_timeManager != NULL)
   {
      delete g_timeManager;
      g_timeManager = NULL;
   }
   
   if(g_chartManager != NULL)
   {
      g_chartManager.ClearLabels();
      delete g_chartManager;
      g_chartManager = NULL;
   }
   
   // Statistiques finales
   Print("╔════════════════════════════════════════════════════════════╗");
   Print("║   📊 STATISTIQUES FINALES                                 ║");
   Print("╠════════════════════════════════════════════════════════════╣");
   Print("║  Changements d'état: ", IntegerToString(g_statusChangeCount));
   Print("║  Configuration testée: ", GetConfigName(g_currentConfig));
   Print("╚════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Fonction principale appelée à chaque tick                        |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_timeManager == NULL) return;
   
   // Vérifier s'il y a une nouvelle barre
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Tester seulement s'il y a une nouvelle barre
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;
   
   // Tester IsTradingAllowed() à chaque nouvelle barre
   bool isAllowed = g_timeManager.IsTradingAllowed();
   ENUM_TRADING_STATUS currentStatus = g_timeManager.GetCurrentStatus();
   
   // Logger les changements d'état
   if(currentStatus != g_lastStatus)
   {
      g_statusChangeCount++;
      g_lastStatusChange = TimeGMT();
      g_lastStatus = currentStatus;
      
      if(VerboseLogging)
      {
         MqlDateTime dt;
         TimeToStruct(TimeGMT(), dt);
         string dayNames[] = {"Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"};
         string dayName = (dt.day_of_week >= 0 && dt.day_of_week < 7) ? dayNames[dt.day_of_week] : "Unknown";
         
         Print("🔄 CHANGEMENT D'ÉTAT #", IntegerToString(g_statusChangeCount), 
               " | ", dayName, " ", StringFormat("%02d:%02d", dt.hour, dt.min),
               " | Status: ", g_timeManager.GetStatusDescription());
      }
   }
   
   // Mettre à jour l'affichage toutes les secondes ou lors d'un changement
   static datetime lastDisplayUpdate = 0;
   datetime currentTime = TimeGMT();
   if(currentTime != lastDisplayUpdate || currentStatus != g_lastStatus)
   {
      UpdateDisplay();
      lastDisplayUpdate = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Charger une configuration de test                               |
//+------------------------------------------------------------------+
bool LoadConfiguration(ENUM_TEST_CONFIG config)
{
   if(g_timeManager == NULL) return false;
   
   // Nettoyer les filtres existants (déjà fait dans le destructeur)
   // Mais on doit créer un nouveau manager pour réinitialiser
   if(g_timeManager != NULL)
   {
      delete g_timeManager;
   }
   g_timeManager = new TradingTimeManager(g_chartManager);
   g_timeManager.SetVerboseLogging(VerboseLogging);
   g_timeManager.SetVisualAlerts(ShowVisualAlerts);
   
   bool success = true;
   
   switch(config)
   {
      case CONFIG_BUSINESS_HOURS:
         // TimeRangeFilter: "8-17" (8h à 17h)
         // DayRangeFilter: "1-5" (Lundi à Vendredi)
         success = LoadBusinessHours();
         break;
         
      case CONFIG_NIGHT_TRADING:
         // TimeRangeFilter: "22-6" (22h à 6h, traverse minuit)
         // DayRangeFilter: "0-6" (Tous les jours)
         success = LoadNightTrading();
         break;
         
      case CONFIG_OVERLAP_SESSION:
         // DayRangeFilter: "1-5" (Lundi à Vendredi)
         // SessionFilter: SESSION_OVERLAP (13h-16h)
         success = LoadOverlapSession();
         break;
         
      case CONFIG_WEEKEND_WARRIOR:
         // TimeRangeFilter: "0-23" (Toute la journée)
         // DayRangeFilter: "0;6" (Samedi et Dimanche uniquement)
         success = LoadWeekendWarrior();
         break;
         
      case CONFIG_MINUTE_PRECISION:
         // TimeMinuteFilter: "9:30-11:45;14:00-16:30"
         // DayRangeFilter: "1-5" (Lundi à Vendredi)
         success = LoadMinutePrecision();
         break;
         
      case CONFIG_NEWS_ONLY:
         // NewsFilter: "USD,EUR" uniquement
         success = LoadNewsOnly();
         break;
         
      case CONFIG_ALL_FILTERS:
         // Tous les filtres combinés
         success = LoadAllFilters();
         break;
         
      case CONFIG_NO_FILTERS:
         // Aucun filtre activé
         success = true; // Déjà initialisé sans filtres
         break;
         
      default:
         Print("❌ Configuration inconnue");
         return false;
   }
   
   if(success)
   {
      Print("✅ Configuration chargée: ", GetConfigName(config));
      Print(g_timeManager.GetDetailedInfo());
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| CONFIG_BUSINESS_HOURS                                            |
//+------------------------------------------------------------------+
bool LoadBusinessHours()
{
   // TimeRangeFilter: "8-17"
   TimeRangeFilter* trf = new TimeRangeFilter();
   if(trf == NULL || !trf.Initialize(true, "8-17"))
   {
      Print("❌ Échec initialisation TimeRangeFilter");
      if(trf != NULL) delete trf;
      return false;
   }
   if(!g_timeManager.AddFilter(trf))
   {
      delete trf;
      return false;
   }
   
   // DayRangeFilter: "1-5"
   DayRangeFilter* drf = new DayRangeFilter();
   if(drf == NULL || !drf.Initialize(true, "1-5"))
   {
      Print("❌ Échec initialisation DayRangeFilter");
      if(drf != NULL) delete drf;
      return false;
   }
   if(!g_timeManager.AddFilter(drf))
   {
      delete drf;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CONFIG_NIGHT_TRADING                                             |
//+------------------------------------------------------------------+
bool LoadNightTrading()
{
   // TimeRangeFilter: "22-6" (traverse minuit)
   TimeRangeFilter* trf = new TimeRangeFilter();
   if(trf == NULL || !trf.Initialize(true, "22-6"))
   {
      Print("❌ Échec initialisation TimeRangeFilter");
      if(trf != NULL) delete trf;
      return false;
   }
   if(!g_timeManager.AddFilter(trf))
   {
      delete trf;
      return false;
   }
   
   // DayRangeFilter: "0-6" (Tous les jours)
   DayRangeFilter* drf = new DayRangeFilter();
   if(drf == NULL || !drf.Initialize(true, "0-6"))
   {
      Print("❌ Échec initialisation DayRangeFilter");
      if(drf != NULL) delete drf;
      return false;
   }
   if(!g_timeManager.AddFilter(drf))
   {
      delete drf;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CONFIG_OVERLAP_SESSION                                           |
//+------------------------------------------------------------------+
bool LoadOverlapSession()
{
   // DayRangeFilter: "1-5" (Lundi à Vendredi)
   DayRangeFilter* drf = new DayRangeFilter();
   if(drf == NULL || !drf.Initialize(true, "1-5"))
   {
      Print("❌ Échec initialisation DayRangeFilter");
      if(drf != NULL) delete drf;
      return false;
   }
   if(!g_timeManager.AddFilter(drf))
   {
      delete drf;
      return false;
   }
   
   // SessionFilter: SESSION_OVERLAP
   SessionFilter* sf = new SessionFilter();
   if(sf == NULL || !sf.Initialize(true, SESSION_OVERLAP, 0))
   {
      Print("❌ Échec initialisation SessionFilter");
      if(sf != NULL) delete sf;
      return false;
   }
   if(!g_timeManager.AddFilter(sf))
   {
      delete sf;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CONFIG_WEEKEND_WARRIOR                                           |
//+------------------------------------------------------------------+
bool LoadWeekendWarrior()
{
   // TimeRangeFilter: "8-18" (Toute la journée)
   TimeRangeFilter* trf = new TimeRangeFilter();
   if(trf == NULL || !trf.Initialize(true, "0-23"))
   {
      Print("❌ Échec initialisation TimeRangeFilter");
      if(trf != NULL) delete trf;
      return false;
   }
   if(!g_timeManager.AddFilter(trf))
   {
      delete trf;
      return false;
   }
   
   // DayRangeFilter: "3-5" 
   DayRangeFilter* drf = new DayRangeFilter();
   if(drf == NULL || !drf.Initialize(true, "3-5"))
   {
      Print("❌ Échec initialisation DayRangeFilter");
      if(drf != NULL) delete drf;
      return false;
   }
   if(!g_timeManager.AddFilter(drf))
   {
      delete drf;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CONFIG_MINUTE_PRECISION                                          |
//+------------------------------------------------------------------+
bool LoadMinutePrecision()
{
   // TimeMinuteFilter: "9:30-11:45;14:00-16:30"
   TimeMinuteFilter* tmf = new TimeMinuteFilter();
   if(tmf == NULL || !tmf.Initialize(true, "9:30-11:45;14:00-16:30"))
   {
      Print("❌ Échec initialisation TimeMinuteFilter");
      if(tmf != NULL) delete tmf;
      return false;
   }
   if(!g_timeManager.AddFilter(tmf))
   {
      delete tmf;
      return false;
   }
   
   // DayRangeFilter: "1-5" (Lundi à Vendredi)
   DayRangeFilter* drf = new DayRangeFilter();
   if(drf == NULL || !drf.Initialize(true, "1-5"))
   {
      Print("❌ Échec initialisation DayRangeFilter");
      if(drf != NULL) delete drf;
      return false;
   }
   if(!g_timeManager.AddFilter(drf))
   {
      delete drf;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CONFIG_NEWS_ONLY                                                 |
//+------------------------------------------------------------------+
bool LoadNewsOnly()
{
   // NewsFilter UNIQUEMENT: "USD,EUR" / "NFP,PMI,Interest Rate" 
   // 30min avant / 10min après / 7 jours de lookup
   NewsFilter* nf = new NewsFilter();
   if(nf == NULL || !nf.Initialize(true, "USD,EUR", "NFP,PMI,Interest Rate", 30, 10, 7, NEWS_COMMA))
   {
      Print("❌ Échec initialisation NewsFilter");
      if(nf != NULL) delete nf;
      return false;
   }
   if(!g_timeManager.AddFilter(nf))
   {
      delete nf;
      return false;
   }
   
   Print("✅ NewsFilter chargé seul - Surveillance: USD, EUR");
   Print("   Keywords: NFP, PMI, Interest Rate");
   Print("   Stop avant: 30min | Reprendre après: 10min");
   
   return true;
}

//+------------------------------------------------------------------+
//| CONFIG_ALL_FILTERS                                               |
//+------------------------------------------------------------------+
bool LoadAllFilters()
{
   // TimeRangeFilter: "8-18"
   TimeRangeFilter* trf = new TimeRangeFilter();
   if(trf == NULL || !trf.Initialize(true, "8-18"))
   {
      if(trf != NULL) delete trf;
      return false;
   }
   if(!g_timeManager.AddFilter(trf)) { delete trf; return false; }
   
   // DayRangeFilter: "1-5"
   DayRangeFilter* drf = new DayRangeFilter();
   if(drf == NULL || !drf.Initialize(true, "1-5"))
   {
      if(drf != NULL) delete drf;
      return false;
   }
   if(!g_timeManager.AddFilter(drf)) { delete drf; return false; }
   
   // SessionFilter: SESSION_OVERLAP
   SessionFilter* sf = new SessionFilter();
   if(sf == NULL || !sf.Initialize(true, SESSION_OVERLAP, 0))
   {
      if(sf != NULL) delete sf;
      return false;
   }
   if(!g_timeManager.AddFilter(sf)) { delete sf; return false; }
   
   // NewsFilter: "USD,EUR" / "NFP,PMI" / 30min avant / 10min après
   NewsFilter* nf = new NewsFilter();
   if(nf == NULL || !nf.Initialize(true, "USD,EUR", "NFP,PMI", 30, 10, 7, NEWS_COMMA))
   {
      if(nf != NULL) delete nf;
      return false;
   }
   if(!g_timeManager.AddFilter(nf)) { delete nf; return false; }
   
   return true;
}

//+------------------------------------------------------------------+
//| Afficher les informations de démarrage                          |
//+------------------------------------------------------------------+
void DisplayStartupInfo()
{
   if(g_chartManager == NULL) return;
   
   string lines[];
   ArrayResize(lines, 6);
   lines[0] = "🧪 TEST TRADING TIME MANAGER";
   lines[1] = "";
   lines[2] = "Config: " + GetConfigName(g_currentConfig);
   lines[3] = "Status: Initializing...";
   lines[4] = "";
   lines[5] = "Checking filters...";
   
   g_chartManager.ShowMultiLineInfo(lines, CORNER_LEFT_UPPER, 10, 30, 20, clrBlack, 10, "MainInfo");
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage sur le graphique                      |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   if(g_timeManager == NULL || g_chartManager == NULL) return;
   
   // Obtenir les informations actuelles
   bool isAllowed = g_timeManager.IsTradingAllowed();
   ENUM_TRADING_STATUS status = g_timeManager.GetCurrentStatus();
   string statusDesc = g_timeManager.GetStatusDescription();
   
   // Informations temporelles
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   string dayNames[] = {"Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"};
   string dayName = (dt.day_of_week >= 0 && dt.day_of_week < 7) ? dayNames[dt.day_of_week] : "Unknown";
   string timeStr = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
   
   // Construire les lignes d'affichage
   string lines[];
   int lineCount = 0;
   ArrayResize(lines, 20);
   
   lines[lineCount++] = "🧪 TEST TRADING TIME MANAGER";
   lines[lineCount++] = "";
   lines[lineCount++] = "Config: " + GetConfigName(g_currentConfig);
   lines[lineCount++] = "";
   
   // Statut avec couleur appropriée
   color statusColor = isAllowed ? clrLime : clrRed;
   string statusIcon = isAllowed ? "✅" : "🚫";
   lines[lineCount++] = statusIcon + " Status: " + statusDesc;
   lines[lineCount++] = "";
   
   // Informations temporelles
   lines[lineCount++] = "Heure: " + timeStr;
   lines[lineCount++] = "Jour: " + dayName;
   lines[lineCount++] = "";
   
   // Filtres actifs (récupérer depuis GetDetailedInfo)
   string detailedInfo = g_timeManager.GetDetailedInfo();
   string filterLines[];
   int filterCount = StringSplit(detailedInfo, '\n', filterLines);
   
   lines[lineCount++] = "Filtres Actifs:";
   for(int i = 0; i < filterCount && lineCount < 18; i++)
   {
      string line = filterLines[i];
      if(StringFind(line, "✓") >= 0 || StringFind(line, "Active") >= 0)
      {
         lines[lineCount++] = "  " + line;
      }
   }
   
   // Statistiques
   lines[lineCount++] = "";
   lines[lineCount++] = "Changements: " + IntegerToString(g_statusChangeCount);
   
   // Redimensionner le tableau au nombre réel de lignes
   ArrayResize(lines, lineCount);
   
   // Afficher
   g_chartManager.ShowMultiLineInfo(lines, CORNER_LEFT_UPPER, 10, 30, 18, clrBlack, 9, "MainInfo");
   
   // Afficher le statut en haut à droite
   string statusText = statusIcon + " " + (isAllowed ? "TRADING ACTIVE" : "TRADING BLOCKED");
   g_chartManager.ShowStatusLabel(statusText, CORNER_RIGHT_UPPER, 10, 10, 14);
}

