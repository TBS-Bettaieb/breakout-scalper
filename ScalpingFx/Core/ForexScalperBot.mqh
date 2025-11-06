//+------------------------------------------------------------------+
//|                                           ForexScalperBot.mqh    |
//|                                Bot Engine - All Logic Here       |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/TradingUtils.mqh"
#include "../../Shared/TradingTimeManager.mqh"
#include "../../Shared/ChartManager.mqh"
#include "../../Shared/Logger.mqh"
#include "../common/BotConfig.mqh"
#include "../common/ForexSymbolTrader.mqh"
#include "../common/ForexSymbolManager.mqh"
#include "../common/RiskMultiplierManager.mqh"

//+------------------------------------------------------------------+
//| Main Bot Class                                                   |
//+------------------------------------------------------------------+
class ForexScalperBot
{
private:
   BotConfig         m_config;
   ChartManager*     m_chartManager;
   TradingTimeManager* m_timeManager;
   RiskMultiplierManager* m_riskMultiplierManager;
   ForexSymbolTrader* m_symbolTraders[];
   string            m_symbols[];
   int               m_totalSymbols;
   int               m_tickCount;
   
public:
   //--- Constructor
   ForexScalperBot(BotConfig &config)
   {
      m_config = config;
      m_chartManager = NULL;
      m_timeManager = NULL;
      m_riskMultiplierManager = NULL;
      m_totalSymbols = 0;
      m_tickCount = 0;
   }
   
   //--- Destructor
   ~ForexScalperBot()
   {
      // Cleanup is done in Deinitialize
   }
   
   //--- Initialize bot
   bool Initialize()
   {
      Logger::Initialize(m_config.logLevel, "[" + m_config.strategyName + "] ");
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🚀 Initializing " + m_config.strategyName);
      Logger::Info("═══════════════════════════════════════");
      
      // Step 1: Validate Trailing TP if needed
      if(!ValidateTrailingTP())
         return false;
      
      // Step 2: Parse and validate symbols
      if(!ParseSymbols())
         return false;
      
      // Step 3: Validate historical data
      if(!ValidateHistoricalData())
         return false;
      
      // Step 4: Calculate risk
      double riskPerSymbol = CalculateRiskPerSymbol(m_config.riskPercent, m_totalSymbols);
      Logger::Info("💰 Risk per symbol: " + DoubleToString(riskPerSymbol, 2) + "% (Total: " + 
            DoubleToString(m_config.riskPercent, 2) + "%)");
      
      // Step 5: Create symbol traders
      if(!CreateSymbolTraders(riskPerSymbol))
         return false;
      
      // Step 6: Initialize Chart Manager
      if(!InitializeChartManager())
         return false;
      
      // Step 7: Initialize Time Manager (includes NewsFilter)
      if(!InitializeTimeManager())
         return false;
      
      // Step 8: Initialize Risk Multiplier Manager
      if(!InitializeRiskMultiplier())
         return false;
      
      // Final summary
      PrintInitializationSummary();
      
      return true;
   }
   
   //--- Deinitialize bot
   void Deinitialize(const int reason)
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🛑 " + m_config.strategyName + " stopping...");
      Logger::Info("Reason: " + IntegerToString(reason));
      Logger::Info("═══════════════════════════════════════");
      
      // Cleanup symbol traders
      if(ArraySize(m_symbolTraders) > 0)
      {
         for(int i = 0; i < ArraySize(m_symbolTraders); i++)
         {
            if(m_symbolTraders[i] != NULL)
            {
               delete m_symbolTraders[i];
               m_symbolTraders[i] = NULL;
            }
         }
         ArrayFree(m_symbolTraders);
         Logger::Success("✅ Symbol Traders cleaned up");
      }
      
      // Cleanup Risk Multiplier Manager
      if(m_riskMultiplierManager != NULL)
      {
         delete m_riskMultiplierManager;
         m_riskMultiplierManager = NULL;
         Logger::Success("✅ Risk Multiplier Manager cleaned up");
      }
      
      // Cleanup Time Manager (includes NewsFilter now)
      if(m_timeManager != NULL)
      {
         delete m_timeManager;
         m_timeManager = NULL;
         Logger::Success("✅ Time Manager cleaned up");
      }
      
      // Cleanup Chart Manager
      if(m_chartManager != NULL)
      {
         delete m_chartManager;
         m_chartManager = NULL;
         Logger::Success("✅ Chart Manager cleaned up");
      }
      
      ArrayFree(m_symbols);
      Logger::Success("✅ All resources cleaned up successfully");
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Main tick handler
   void OnTick()
   {
      // Validate objects
      if(m_chartManager == NULL || m_timeManager == NULL || ArraySize(m_symbolTraders) == 0)
         return;
      
      // 🆕 Vérifier changement de Risk Multiplier
      if(m_riskMultiplierManager != NULL && m_riskMultiplierManager.HasStatusChanged())
      {
         double currentMultiplier = m_riskMultiplierManager.GetCurrentMultiplier();
         AdjustAllPositionSizes(currentMultiplier);
      }
      
      // Check trading permissions (NewsFilter is now integrated in TradingTimeManager)
      bool tradingAllowed = m_timeManager.IsTradingAllowed();
      
      // 🔍 DEBUG: Logger les permissions de trading (toutes les 100 ticks pour éviter spam)
      static int debugTickCount = 0;
      debugTickCount++;
      if(debugTickCount % 100 == 0 || !tradingAllowed)
      {
         Print("[ForexScalperBot] 🔍 DEBUG OnTick:");
         Print("   useNewsFilter = ", m_config.useNewsFilter);
         Print("   tradingAllowed = ", tradingAllowed);
         Print("   status = ", m_timeManager.GetStatusDescription());
      }
      
      // 🆕 Obtenir multiplicateur actuel
      double currentRiskMultiplier = 1.0;
      if(m_riskMultiplierManager != NULL)
         currentRiskMultiplier = m_riskMultiplierManager.GetCurrentMultiplier();
      
      // Process all symbols
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            // 🆕 Mettre à jour le multiplicateur
            m_symbolTraders[i].SetRiskMultiplier(currentRiskMultiplier);
            
            if(tradingAllowed)
            {
               m_symbolTraders[i].OnTick();
            }
            else
            {
               m_symbolTraders[i].CancelAllPendingOrders();
            }
            
            m_symbolTraders[i].TrailStop();
            m_symbolTraders[i].ApplyTrailingTP();
         }
      }
      
      // Update chart display
      UpdateChartInfo();
   }
   
   //--- Get ChartManager for external access
   ChartManager* GetChartManager() const { return m_chartManager; }

private:
   //--- Validate Trailing TP configuration
   bool ValidateTrailingTP()
   {
      if(m_config.useTrailingTP && m_config.trailingTPMode == TRAILING_TP_CUSTOM)
      {
         Logger::Debug("🔍 Validation Custom Trailing TP...");
         string errorMessage;
         bool isValid = CTrailingTPValidator::ValidateCustomLevelsString(
            m_config.customTPLevels, errorMessage);
         
         if(!isValid)
         {
            Logger::Error("❌ ERREUR: " + errorMessage);
            Logger::Info("💡 Exemple: \"50:0:0, 75:25:50, 100:50:100\"");
            return false;
         }
         
         CTrailingTPValidator::PrintParsedLevels(m_config.customTPLevels);
         Logger::Info(errorMessage);
      }
      return true;
   }
   
   //--- Parse symbols list
   bool ParseSymbols()
   {
      if(m_config.useAllSymbols)
      {
         m_totalSymbols = GetSymbolsFromMarketWatch(m_symbols);
         Logger::Info("📊 Using all symbols from Market Watch: " + IntegerToString(m_totalSymbols) + " symbols");
      }
      else
      {
         m_totalSymbols = ParseSymbolsList(m_config.symbolsList, m_symbols);
         Logger::Info("📊 Using custom symbols list: " + IntegerToString(m_totalSymbols) + " symbols");
      }
      
      if(m_totalSymbols <= 0)
      {
         Logger::Error("❌ ERROR: No valid symbols found");
         return false;
      }
      
      return true;
   }
   
   //--- Validate historical data
   bool ValidateHistoricalData()
   {
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(!CheckHistoricalData(m_symbols[i], m_config.timeframe))
         {
            Logger::Warning("⚠️ Warning: Limited historical data for " + m_symbols[i]);
         }
      }
      return true;
   }
   
   //--- Create symbol traders
   bool CreateSymbolTraders(double riskPerSymbol)
   {
      ArrayResize(m_symbolTraders, m_totalSymbols);
      
      // Afficher le mapping des magic numbers
      PrintMagicNumberMapping(m_symbols, m_config.baseMagic, m_config.timeframe);
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         // Générer un magic number unique par symbole
         int symbolMagic = GenerateSymbolMagicNumber(
            m_config.baseMagic, 
            m_symbols[i], 
            m_config.timeframe
         );
         
         Logger::Info("✅ Creating trader for " + m_symbols[i] + " with magic " + IntegerToString(symbolMagic));
         
         m_symbolTraders[i] = new ForexSymbolTrader(
            m_symbols[i],
            symbolMagic,  // ✅ CORRECTION : magic unique
            m_config.timeframe,
            riskPerSymbol,
            m_config.tpPoints,
            m_config.slPoints,
            m_config.tslTriggerPoints,
            m_config.tslPoints,
            m_config.barsN,
            m_config.expirationBars,
            m_config.orderDistPoints,
            m_config.slippagePoints,        // NEW
            m_config.entryOffsetPoints,     // NEW
            m_config.strategyComment,
            m_config.useTrailingTP,
            m_config.trailingTPMode,
            m_config.customTPLevels,
            m_config.useDynamicTSLTrigger,      // 🆕 AJOUTER
            m_config.tslCostMultiplier,         // 🆕 AJOUTER
            m_config.tslMinTriggerPoints,       // 🆕 AJOUTER
            m_config.priceTolerancePercent,
            m_config.useFvgFilter               // 🆕 FVG FILTER
         );
         
         if(m_symbolTraders[i] == NULL)
         {
            Logger::Error("❌ ERROR: Failed to create ForexSymbolTrader for " + m_symbols[i]);
            // Cleanup already created traders to avoid memory leaks
            for(int j = 0; j < i; j++)
            {
               if(m_symbolTraders[j] != NULL)
               {
                  delete m_symbolTraders[j];
                  m_symbolTraders[j] = NULL;
               }
            }
            return false;
         }
      }
      
      return true;
   }
   
   //--- Initialize Chart Manager
   bool InitializeChartManager()
   {
      m_chartManager = new ChartManager(0, "ForexScalpBot");
      
      if(m_chartManager != NULL)
      {
         m_chartManager.SetupChart();
         m_chartManager.ShowStrategyName(m_config.strategyName);
         PrintSymbolsInfo(m_symbols, m_config.baseMagic, m_config.timeframe, "ScalpingRobot");
         return true;
      }
      else
      {
         Logger::Warning("⚠️ Warning: Chart Manager initialization failed");
         return true; // Non-critical
      }
   }
   
   //--- Initialize Time Manager
   bool InitializeTimeManager()
   {
      m_timeManager = new TradingTimeManager(m_chartManager);
      if(m_timeManager == NULL)
      {
         Logger::Error("❌ Failed to create TradingTimeManager");
         return false;
      }
      
      // ✅ NOUVEAU SYSTÈME UNIQUEMENT - pas d'ancien Initialize()
      
      // Déterminer la chaîne de plage horaire à utiliser
      string timeRangeStr = "";
      if(m_config.tradingTimeRanges != "")
      {
         timeRangeStr = m_config.tradingTimeRanges;
      }
      else if(m_config.startHour != 0 || m_config.endHour != 0)
      {
         // Fallback vers l'ancien format
         timeRangeStr = IntegerToString(m_config.startHour) + "-" + 
                       IntegerToString(m_config.endHour);
      }
      
      // Ajouter TimeRange Filter si configuré
      if(timeRangeStr != "")
      {
         TimeRangeFilter* trf = new TimeRangeFilter();
         if(trf == NULL)
         {
            Logger::Error("❌ Failed to create TimeRangeFilter");
            return false;
         }
         
         if(!trf.Initialize(true, timeRangeStr))
         {
            Logger::Error("❌ Invalid TimeRange format: " + timeRangeStr);
            delete trf;  // Supprimer seulement si Initialize() échoue
            return false;
         }
         
         if(!m_timeManager.AddFilter(trf))
         {
            Logger::Error("❌ Failed to add TimeRange Filter to TradingTimeManager");
            delete trf;  // Supprimer si AddFilter() échoue (filtre non ajouté)
            return false;
         }
         // Si AddFilter() réussit, TradingTimeManager possède maintenant le filtre
         
         Logger::Info("✅ TimeRange Filter initialized: " + timeRangeStr);
      }
      
      // 🆕 AJOUTER : NewsFilter dans TradingTimeManager
      if(m_config.useNewsFilter)
      {
         NewsFilter* nf = new NewsFilter();
         if(nf == NULL)
         {
            Logger::Error("❌ Failed to create NewsFilter");
            return false;
         }
         
         // Convertir ENUM_SEPARATOR vers ENUM_NEWS_SEPARATOR
         ENUM_NEWS_SEPARATOR newsSep = (m_config.newsSeparator == COMMA) ? NEWS_COMMA : NEWS_SEMICOLON;
         
         if(!nf.Initialize(
            true,  // enabled
            m_config.newsCurrencies,
            m_config.keyNewsEvents,
            m_config.stopBeforeNewsMin,
            m_config.startAfterNewsMin,
            m_config.newsLookupDays,
            newsSep
         ))
         {
            Logger::Error("❌ Failed to initialize NewsFilter");
            delete nf;  // Supprimer seulement si Initialize() échoue
            return false;
         }
         
         if(!m_timeManager.AddFilter(nf))
         {
            Logger::Error("❌ Failed to add NewsFilter to TradingTimeManager");
            delete nf;  // Supprimer si AddFilter() échoue (filtre non ajouté)
            return false;
         }
         // Si AddFilter() réussit, TradingTimeManager possède maintenant le filtre
         
         Logger::Info("✅ NewsFilter added to TradingTimeManager");
         Logger::Info("   Currencies: " + m_config.newsCurrencies);
         Logger::Info("   Events: " + m_config.keyNewsEvents);
         Logger::Info("   Stop Before: " + IntegerToString(m_config.stopBeforeNewsMin) + " min");
         Logger::Info("   Resume After: " + IntegerToString(m_config.startAfterNewsMin) + " min");
      }
      
      // Configuration finale
      m_timeManager.SetVerboseLogging(true);
      m_timeManager.SetAlertMessages(m_config.hourBlockMsg, m_config.dayBlockMsg, 
                                     m_config.bothBlockMsg);
      
      Logger::Info("⏰ Time Manager Configuration:");
      Logger::Info(m_timeManager.GetDetailedInfo());
      
      return true;
   }
   
   //--- Initialize Risk Multiplier Manager
   bool InitializeRiskMultiplier()
   {
      m_riskMultiplierManager = new RiskMultiplierManager();
      if(m_riskMultiplierManager == NULL)
      {
         Logger::Warning("⚠️ Warning: Risk Multiplier Manager creation failed");
         return true; // Non-critical
      }
      
      // Utiliser le nouveau format unifié si disponible
      if(m_config.riskMultTimeRanges != "")
      {
         m_riskMultiplierManager.InitializeUnified(
            m_config.useRiskMultiplier,
            m_config.riskMultTimeRanges,
            m_config.riskMultiplier,
            m_config.riskMultDescription
         );
      }
      else
      {
         // Fallback vers l'ancien format (rétro-compatibilité)
         m_riskMultiplierManager.Initialize(
            m_config.useRiskMultiplier,
            m_config.riskMultStartHour,
            m_config.riskMultStartMinute,
            m_config.riskMultEndHour,
            m_config.riskMultEndMinute,
            m_config.riskMultiplier,
            m_config.riskMultDescription
         );
      }
      
      return true;
   }
   
   //--- Print initialization summary
   void PrintInitializationSummary()
   {
      Logger::Success("✅ Initialization completed successfully!");
      Logger::Info("📈 Trading " + IntegerToString(m_totalSymbols) + " symbols simultaneously");
      Logger::Info("🕒 Timeframe: " + EnumToString(m_config.timeframe));
      
      if(m_config.useTrailingTP)
      {
         Logger::Info("🎯 TRAILING TP: " + EnumToString(m_config.trailingTPMode));
         if(m_config.trailingTPMode == TRAILING_TP_CUSTOM)
            Logger::Info("   Niveaux: " + m_config.customTPLevels);
      }
      
      if(m_config.useRiskMultiplier && m_riskMultiplierManager != NULL)
      {
         Logger::Info("🚀 RISK MULTIPLIER: " + m_riskMultiplierManager.GetDetailedInfo());
      }
      
      // NewsFilter info is now included in TradingTimeManager.GetDetailedInfo()
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Ajuster toutes les positions
   void AdjustAllPositionSizes(double multiplier)
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🔄 AJUSTEMENT DES POSITIONS - Multiplier: x" + DoubleToString(multiplier, 2));
      Logger::Info("═══════════════════════════════════════");
      
      int adjustedCount = 0;
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            int adjusted = m_symbolTraders[i].AdjustPositionSizes(multiplier);
            adjustedCount += adjusted;
         }
      }
      
      if(adjustedCount > 0)
         Logger::Info("✅ " + IntegerToString(adjustedCount) + " position(s) ajustée(s)");
      else
         Logger::Info("ℹ️ Aucune position à ajuster");
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Update chart information
   void UpdateChartInfo()
   {
      if(m_chartManager == NULL || ArraySize(m_symbolTraders) == 0) return;
      
      m_tickCount++;
      
      // Update every 100 ticks
      if(m_tickCount % 100 != 0) return;
      
      // Build global status
      string globalStatus = GetGlobalSymbolsStatus(m_symbols, m_symbolTraders);
      string timeStatus = m_timeManager.GetStatusDescription();
      
      // Determine color and build status
      color statusColor = clrGreen;
      ENUM_TRADING_STATUS status = m_timeManager.GetCurrentStatus();
      
      // 🆕 Ajouter status Risk Multiplier
      string riskMultStatus = "";
      if(m_riskMultiplierManager != NULL && m_config.useRiskMultiplier)
      {
         riskMultStatus = m_riskMultiplierManager.GetStatusDescription();
      }
      
      // Build combined status (News status is now included in timeStatus)
      globalStatus = timeStatus + " | " + globalStatus;
      
      if(riskMultStatus != "")
         globalStatus = riskMultStatus + " | " + globalStatus;
      
      // Determine color based on status
      if(status == TRADING_BLOCKED_NEWS)
         statusColor = clrRed;
      else if(status != TRADING_ACTIVE)
         statusColor = clrOrange;
      else if(m_riskMultiplierManager != NULL && m_riskMultiplierManager.IsInActivePeriod())
         statusColor = clrYellow;
      else
      {
         int plPos = StringFind(globalStatus, "P/L: ");
         if(plPos >= 0)
         {
            if(plPos + 5 < StringLen(globalStatus) &&
               StringGetCharacter(globalStatus, plPos + 5) == '-')
               statusColor = clrRed;
            else
               statusColor = clrLime;
         }
      }
      
      // Update main label
      m_chartManager.UpdateLabelText("TopRight", globalStatus);
      m_chartManager.UpdateLabelColor("TopRight", statusColor);
      
      // Update details every 500 ticks
      if(m_tickCount % 500 == 0)
      {
         UpdateDetailedInfo();
      }
   }
   
   //--- Update detailed information
   void UpdateDetailedInfo()
   {
      // Refresh swing points only
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            m_symbolTraders[i].RefreshSwingDisplay();
         }
      }
   }
};
//+------------------------------------------------------------------+