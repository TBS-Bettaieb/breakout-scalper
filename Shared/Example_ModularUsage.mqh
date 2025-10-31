//+------------------------------------------------------------------+
//|                                        Example_ModularUsage.mqh  |
//|                   Exemple d'utilisation de TradingTimeManager    |
//|                   avec l'architecture modulaire                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Exemple d'utilisation de TradingTimeManager modulaire           |
//+------------------------------------------------------------------+
void ExampleModularUsage()
{
   // Créer le ChartManager
   ChartManager* chartManager = new ChartManager(0, "Example");
   
   // Créer le TradingTimeManager
   TradingTimeManager* timeManager = new TradingTimeManager(chartManager);
   
   // ═══ EXEMPLE 1: Utilisation modulaire ═══
   // Activer uniquement TimeRange et DayRange
   timeManager.InitTimeRangeFilter(true, "8-18");        // 8h à 18h
   timeManager.InitDayRangeFilter(true, "1-5");          // Lundi à Vendredi
   
   // News et Session restent NULL = désactivés
   // Pas besoin de les initialiser
   
   // ═══ EXEMPLE 2: Utilisation complète ═══
   // Réinitialiser tous les filtres
   delete timeManager;
   timeManager = new TradingTimeManager(chartManager);
   
   // Activer tous les filtres
   timeManager.InitTimeRangeFilter(true, "8-18");
   timeManager.InitDayRangeFilter(true, "1-5");
   timeManager.InitSessionFilter(true, SESSION_OVERLAP, 30);
   timeManager.InitNewsFilter(true, "USD,EUR,GBP", "NFP,PMI,Interest Rate", 30, 10, 7, NEWS_COMMA);
   timeManager.InitTimeMinuteFilter(true, "8:30-10:45;16:00");
   
   // Configuration des alertes
   timeManager.SetVerboseLogging(true);
   timeManager.SetAlertMessages(
      "⏰ TRADING PAUSED - Outside Trading Hours",
      "📅 TRADING PAUSED - Outside Trading Days",
      "🚫 TRADING PAUSED - Multiple Filters Blocked"
   );
   
   // ═══ EXEMPLE 3: Compatibilité descendante ═══
   // Les EA existants peuvent continuer d'utiliser Initialize()
   delete timeManager;
   timeManager = new TradingTimeManager(chartManager);
   
   timeManager.Initialize(
      true,  // useTimeFilter
      "8-18", // hourRanges
      true,  // useDayFilter
      "1-5", // dayRanges
      true   // showVisualAlerts
   );
   
   // ═══ Exemple d'utilisation dans OnTick() ═══
   if(timeManager.IsTradingAllowed())
   {
      // Trading autorisé - tous les filtres actifs sont OK
      Print("✅ Trading allowed - All active filters passed");
   }
   else
   {
      // Trading bloqué - au moins un filtre bloque
      ENUM_TRADING_STATUS status = timeManager.GetCurrentStatus();
      Print("🚫 Trading blocked - Status: ", timeManager.GetStatusDescription());
   }
   
   // Nettoyer
   delete timeManager;
   delete chartManager;
}

//+------------------------------------------------------------------+
//| Exemple d'intégration dans un EA existant                        |
//+------------------------------------------------------------------+
void ExampleEAIntegration()
{
   // Dans OnInit() d'un EA existant :
   
   // 1. Créer le TimeManager
   TradingTimeManager* timeManager = new TradingTimeManager(chartManager);
   
   // 2. Initialiser UNIQUEMENT les filtres nécessaires
   
   // TimeRange Filter (si SHInput/EHInput sont définis)
   if(SHInput != 0 || EHInput != 0)
   {
      timeManager.InitTimeRangeFilter(
         true,
         IntegerToString(SHInput) + "-" + IntegerToString(EHInput)
      );
   }
   
   // DayRange Filter (exemple - à ajouter dans les inputs)
   // timeManager.InitDayRangeFilter(true, "1-5");  // Lundi-Vendredi
   
   // Session Filter (exemple - à ajouter dans les inputs)
   // timeManager.InitSessionFilter(true, SESSION_OVERLAP, 30);
   
   // News Filter (exemple - à ajouter dans les inputs)
   // timeManager.InitNewsFilter(
   //    true,
   //    "USD,EUR,GBP",
   //    "NFP,PMI,Interest Rate",
   //    30,  // stop 30min before
   //    10,  // resume 10min after
   //    7,   // check 7 days ahead
   //    NEWS_COMMA
   // );
   
   // TimeMinute Filter (exemple - à ajouter dans les inputs)
   // timeManager.InitTimeMinuteFilter(true, "8:30-10:45;16:00");
   
   // 3. Configuration
   timeManager.SetVerboseLogging(true);
   timeManager.SetAlertMessages(HourBlockMsg, DayBlockMsg, BothBlockMsg);
   
   // Dans OnTick() :
   if(timeManager.IsTradingAllowed())
   {
      // Trading autorisé
      // ... logique de trading ...
   }
}
