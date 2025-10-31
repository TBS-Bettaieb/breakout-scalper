//+------------------------------------------------------------------+
//|                                       UnifiedScalper.mq5         |
//|                    Unified Multi-Symbol Scalper EA               |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.1"
#property strict

// User Input Parameters
input string   InpSymbolToTrade = "";  // Symbol to trade (empty = use chart symbol)
input double   InpRiskPercent = -1.0;  // Risk per trade (%) (-1 = use group default)

// Include required files
#include "../ScalpingFx/Core/ForexScalperBot.mqh"
#include "../ScalpingFx/common/ConfigLoader.mqh"
#include "../Shared/Logger.mqh"

// Global variables
CConfigManager* configManager = NULL;
ForexScalperBot* bot = NULL;
string currentSymbol = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 🔧 AJOUTER AU DÉBUT : Empêcher réinit si juste changement de timeframe
   static bool alreadyInitialized = false;
   static string lastSymbol = "";
   
   if(alreadyInitialized && lastSymbol == Symbol())
   {
      Logger::Info("⚠️ Chart timeframe changed - EA configuration unchanged");
      return(INIT_SUCCEEDED);  // Ne pas réinitialiser
   }
   
   // Initialize Logger first
   Logger::Initialize(LOG_INFO, "[BreakoutScalper] ");
   
   // Determine which symbol to use
   if(InpSymbolToTrade == "")
   {
      currentSymbol = Symbol();
   }
   else
   {
      currentSymbol = InpSymbolToTrade;
   }
   
   Logger::Info("=== INITIALIZING UNIFIED SCALPER ===");
   Logger::Info("Target Symbol: " + currentSymbol);
   
   // Initialize configuration manager
   configManager = new CConfigManager();
   if(configManager == NULL)
   {
      Logger::Error("❌ ERROR: Failed to create configuration manager");
      return(INIT_FAILED);
   }
   
   if(!configManager.Initialize())
   {
      Logger::Error("❌ ERROR: Configuration manager initialization failed");
      delete configManager;
      configManager = NULL;
      return(INIT_FAILED);
   }
   
   // Get configuration for the target symbol
   BotConfig config;
   if(!configManager.GetConfigForSymbol(currentSymbol, config))
   {
      Logger::Error("❌ ERROR: No configuration found for symbol: " + currentSymbol);
      Logger::Info("Available symbols are:");
      string allSymbols[];
      int symbolCount = configManager.GetAllSymbols(allSymbols);
      for(int i = 0; i < symbolCount; i++)
      {
         Logger::Info("  - " + allSymbols[i]);
      }
      
      delete configManager;
      configManager = NULL;
      return(INIT_FAILED);
   }
   
   // Override risk percent if specified in input
   if(InpRiskPercent > 0)
   {
      config.riskPercent = InpRiskPercent;
      Logger::Warning("⚠️ Risk percent overridden to: " + DoubleToString(InpRiskPercent, 1) + "%");
   }
   
   // Validate symbol is available before creating bot
   if(!ValidateSymbolAvailable(currentSymbol))
   {
      Logger::Error("❌ ERROR: Symbol " + currentSymbol + " is not available for trading");
      delete configManager;
      configManager = NULL;
      return(INIT_FAILED);
   }
   
   // Initialize bot with configuration
   bot = new ForexScalperBot(config);
   if(bot == NULL)
   {
      Logger::Error("❌ ERROR: Failed to create bot instance");
      delete configManager;
      configManager = NULL;
      return(INIT_FAILED);
   }
   
   if(!bot.Initialize())
   {
      Logger::Error("❌ ERROR: Bot initialization failed");
      delete bot;
      bot = NULL;
      delete configManager;
      configManager = NULL;
      return(INIT_FAILED);
   }
   
   // Display configuration info
   DisplayConfigurationInfo(config);
   
   Logger::Success("✅ UNIFIED SCALPER INITIALIZED SUCCESSFULLY");
   Logger::Info("Symbol: " + currentSymbol);
   Logger::Info("Strategy: " + config.strategyName);
   Logger::Info("Magic: " + IntegerToString(config.baseMagic));
   Logger::Info("Risk: " + DoubleToString(config.riskPercent, 1) + "%");
   
   // 🔧 AJOUTER À LA FIN avant le return :
   alreadyInitialized = true;
   lastSymbol = currentSymbol;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(bot != NULL)
   {
      bot.Deinitialize(reason);
      delete bot;
      bot = NULL;
   }
   
   if(configManager != NULL)
   {
      delete configManager;
      configManager = NULL;
   }
   
   Logger::Info("=== UNIFIED SCALPER DEINITIALIZED ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(bot != NULL)
   {
      bot.OnTick();
   }
}

//+------------------------------------------------------------------+
//| Validate symbol is available for trading                         |
//+------------------------------------------------------------------+
bool ValidateSymbolAvailable(string symbol)
{
   if(!SymbolSelect(symbol, true))
   {
      Logger::Error("❌ ERROR: Symbol " + symbol + " not found in Market Watch");
      return false;
   }
   
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
   {
      Logger::Error("❌ ERROR: Symbol " + symbol + " not available for trading");
      return false;
   }
   
   // Check if symbol info is valid
   if(SymbolInfoDouble(symbol, SYMBOL_BID) <= 0)
   {
      Logger::Error("❌ ERROR: Invalid price data for symbol " + symbol);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Display configuration information                                |
//+------------------------------------------------------------------+
void DisplayConfigurationInfo(BotConfig &config)
{
   string strategyTypeStr = "BREAKOUT";
   string trailingTPStr = "Disabled";
   
   if(config.useTrailingTP)
   {
      switch((int)config.trailingTPMode)
      {
         case TRAILING_TP_LINEAR: trailingTPStr = "LINEAR"; break;
         case TRAILING_TP_STEPPED: trailingTPStr = "STEPPED"; break;
         case TRAILING_TP_EXPONENTIAL: trailingTPStr = "EXPONENTIAL"; break;
         case TRAILING_TP_CUSTOM: trailingTPStr = "CUSTOM"; break;
         default: trailingTPStr = "UNKNOWN"; break;
      }
   }
   
   string riskMultStr = "OFF";
   if(config.useRiskMultiplier) {
      riskMultStr = StringFormat("x%.1f (%02d:%02d-%02d:%02d)", 
                                config.riskMultiplier,
                                config.riskMultStartHour, config.riskMultStartMinute,
                                config.riskMultEndHour, config.riskMultEndMinute);
   }
   
   string newsFilterStr = "OFF";
   if(config.useNewsFilter) {
      newsFilterStr = StringFormat("ON (%dmin/%dmin) - %s", 
                                  config.stopBeforeNewsMin, config.startAfterNewsMin, config.newsCurrencies);
   }
   
   string info = StringFormat(
      "=== %s ===\n" +
      "Symbol: %s\n" +
      "Magic: %d\n" +
      "Timeframe: %s\n" +
      "Risk: %.1f%%\n" +
      "TP/SL: %d/%d points\n" +
      "Strategy: %s\n" +
      "Bars Analysis: %d\n" +
      "Trading Hours: %02d:00-%02d:00\n" +
      "Trailing TP: %s\n" +
      "Risk Multiplier: %s\n" +
      "News Filter: %s",
      config.strategyName,
      currentSymbol,
      config.baseMagic,
      EnumToString(config.timeframe),
      config.riskPercent,
      config.tpPoints, config.slPoints,
      strategyTypeStr,
      config.barsN,
      config.startHour, config.endHour,
      trailingTPStr,
      riskMultStr,
      newsFilterStr
   );
   
   Comment(info);
   Logger::Info("=== CONFIGURATION INFO ===");
   Logger::Info(info);
   Logger::Info("==========================");
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(bot != NULL)
   {
      // Forward chart events to bot if needed
      // (Bot may implement OnChartEvent if required)
   }
}
