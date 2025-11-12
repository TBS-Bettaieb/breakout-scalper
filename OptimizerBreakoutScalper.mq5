//+------------------------------------------------------------------+
//|                                   OptimizerBreakoutScalper.mq5   |
//|                    Optimizer Breakout Scalper EA                 |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict

// Include required enums and types BEFORE input declarations
#include "Shared/TradingEnums.mqh"
#include "Shared/TrailingTP_System.mqh"



// Include required files
#include "ScalpingFx/Core/ForexScalperBot.mqh"
#include "ScalpingFx/common/ConfigLoader.mqh"
#include "Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - All configurable                              |
//+------------------------------------------------------------------+

input group "🎯 SYMBOL CONFIGURATION"
input string   InpSymbolToTrade = "";  // Symbol to trade (empty = use chart symbol)

input group "🎯 STRATEGY IDENTITY"
input string   InpStrategyName = "";        // Strategy Name (empty = use config default)
input string   InpStrategyComment = "";     // Strategy Comment (empty = use config default)
input int      InpBaseMagicNumber = -1;     // Base Magic Number (-1 = use config default)

input group "📊 SYMBOLS CONFIGURATION"  
input string   InpSymbolsList = "";         // Symbols List (empty = use config default)
input int      InpUseAllMarketWatch = -1;   // Use All Market Watch Symbols (-1=config, 0=false, 1=true)
input ENUM_TIMEFRAMES InpTradingTimeframe = PERIOD_CURRENT; // Trading Timeframe (PERIOD_CURRENT = use config)

input group "💰 RISK MANAGEMENT"
input double   InpRiskPercent = -1.0;       // Risk Percent (-1 = use config default)
input int      InpTpPoints = -1;            // Take Profit Points (-1 = use config default)
input int      InpSlPoints = -1;            // Stop Loss Points (-1 = use config default)

input group "🎯 TRAILING STOP CONFIGURATION"
input int      InpTslTriggerPoints = -1;    // TSL Trigger Points (-1 = use config default)
input int      InpTslPoints = -1;           // TSL Points (-1 = use config default)
input int      InpUseDynamicTSLTrigger = -1; // Use Dynamic TSL Trigger (-1=config, 0=false, 1=true)
input double   InpTslCostMultiplier = -1.0; // TSL Cost Multiplier (-1 = use config default)
input int      InpTslMinTriggerPoints = -1; // TSL Min Trigger Points (-1 = use config default)

input group "⏰ TRADING HOURS"
input string   InpTradingTimeRanges = "";   // Trading Time Ranges (empty = use config default)
input int      InpStartHour = -1;           // Start Hour (legacy, -1 = use config default)
input int      InpEndHour = -1;             // End Hour (legacy, -1 = use config default)

input group "📈 STRATEGY PARAMETERS"
input int      InpBarsAnalysis = -1;        // Bars Analysis (-1 = use config default)
input int      InpExpirationBars = -1;      // Expiration Bars (-1 = use config default)
input int      InpOrderDistancePoints = -1; // Order Distance Points (-1 = use config default)
input int      InpSlippagePoints = -1;      // Slippage Tolerance Points (-1 = use config default)
input int      InpEntryOffsetPoints = -1;  // Entry Offset Points (-1 = use config default)

input group "🎯 TRAILING TAKE PROFIT"
input int      InpUseTrailingTP = -1;       // Use Trailing TP (-1=config, 0=false, 1=true)
input int      InpTrailingTPMode = -1;     // Trailing TP Mode (-1=config, 0=LINEAR, 1=STEPPED, 2=EXPONENTIAL, 3=CUSTOM)
input string   InpCustomTPLevels = "";      // Custom TP Levels (empty = use config default)

input group "🚀 RISK MULTIPLIER (BOOST PERIOD)"
input int      InpUseRiskMultiplier = -1;   // Use Risk Multiplier (-1=config, 0=false, 1=true)
input string   InpRiskMultTimeRanges = "";   // Risk Multiplier Time Ranges (empty = use config default)
input double   InpRiskMultiplier = -1.0;     // Risk Multiplier Value (-1 = use config default)
input string   InpRiskMultDescription = "";  // Risk Multiplier Description (empty = use config default)
input int      InpRiskMultStartHour = -1;    // Risk Multiplier Start Hour (legacy, -1 = use config default)
input int      InpRiskMultStartMinute = -1;  // Risk Multiplier Start Minute (legacy, -1 = use config default)
input int      InpRiskMultEndHour = -1;      // Risk Multiplier End Hour (legacy, -1 = use config default)
input int      InpRiskMultEndMinute = -1;   // Risk Multiplier End Minute (legacy, -1 = use config default)

input group "📰 NEWS FILTER"
input int      InpUseNewsFilter = -1;       // Use News Filter (-1=config, 0=false, 1=true)
input string   InpNewsCurrencies = "";        // Affected Currencies (empty = use config default)
input string   InpKeyNewsEvents = "";         // High Impact Events (empty = use config default)
input int      InpStopBeforeNewsMin = -1;    // Minutes Before News (-1 = use config default)
input int      InpStartAfterNewsMin = -1;    // Minutes After News (-1 = use config default)
input int      InpNewsLookupDays = -1;       // Days Ahead to Check News (-1 = use config default)
input int      InpNewsSeparator = -1;       // List Separator (-1=config, 0=COMMA, 1=SEMICOLON)
input string   InpNewsBlockMsg = "";         // News Block Message (empty = use config default)

input group "🆕 FVG FILTER"
input int      InpUseFvgFilter = -1;        // Use FVG Filter (-1=config, 0=false, 1=true)
input double   InpPriceTolerancePercent = -1.0; // Price Tolerance Percent (-1 = use config default, 0.01 = 0.01%)

input group "🚨 ALERT MESSAGES"
input string   InpHourBlockMsg = "";         // Hour Block Message (empty = use config default)
input string   InpDayBlockMsg = "";          // Day Block Message (empty = use config default)
input string   InpBothBlockMsg = "";         // Both Block Message (empty = use config default)

input group "🔧 LOGGING"
input int      InpLogLevel = -1;            // Log Level (-1=config, 0=NONE, 1=ERROR, 2=WARNING, 3=INFO, 4=DEBUG)

input group "🔍 FVG MEMORY DEBUG"
input bool     InpFVGMemoryDebug = true;   // 🔍 FVG Memory Debug Mode

// Global variables
CConfigManager* configManager = NULL;
ForexScalperBot* bot = NULL;
string currentSymbol = "";

// Helper: cleanup resources and fail initialization
int CleanupAndFail(string errorMsg)
{
   Logger::Error("❌ " + errorMsg);
   if(bot != NULL) { delete bot; bot = NULL; }
   if(configManager != NULL) { delete configManager; configManager = NULL; }
   return(INIT_FAILED);
}

//+------------------------------------------------------------------+
//| Helper function to convert int to bool with -1 = use config     |
//+------------------------------------------------------------------+
bool IntToBoolWithConfig(int value, bool configValue)
{
   if(value == -1)
      return configValue;  // Use config default
   return (value == 1);    // 0 = false, 1 = true
}

//+------------------------------------------------------------------+
//| Helper function to convert int to TrailingTPMode with -1 = use config |
//+------------------------------------------------------------------+
ENUM_TRAILING_TP_MODE IntToTrailingTPMode(int value, ENUM_TRAILING_TP_MODE configValue)
{
   if(value == -1)
      return configValue;  // Use config default
   if(value >= 0 && value <= 3)
      return (ENUM_TRAILING_TP_MODE)value;  // 0=LINEAR, 1=STEPPED, 2=EXPONENTIAL, 3=CUSTOM
   return configValue;  // Invalid value, use config
}

//+------------------------------------------------------------------+
//| Helper function to convert int to Separator with -1 = use config |
//+------------------------------------------------------------------+
ENUM_SEPARATOR IntToSeparator(int value, ENUM_SEPARATOR configValue)
{
   if(value == -1)
      return configValue;  // Use config default
   if(value >= 0 && value <= 1)
      return (ENUM_SEPARATOR)value;  // 0=COMMA, 1=SEMICOLON
   return configValue;  // Invalid value, use config
}

//+------------------------------------------------------------------+
//| Helper function to convert int to LogLevel with -1 = use config |
//+------------------------------------------------------------------+
ENUM_LOG_LEVEL IntToLogLevel(int value, ENUM_LOG_LEVEL configValue)
{
   if(value == -1)
      return configValue;  // Use config default
   if(value >= 0 && value <= 4)
      return (ENUM_LOG_LEVEL)value;  // 0=NONE, 1=ERROR, 2=WARNING, 3=INFO, 4=DEBUG
   return configValue;  // Invalid value, use config
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   
   
   // Initialize Logger first with default or input value
   // (will be updated later with config value if InpLogLevel == -1)
   ENUM_LOG_LEVEL initialLogLevel = (InpLogLevel == -1) ? LOG_INFO : (ENUM_LOG_LEVEL)InpLogLevel;
   Logger::Initialize(initialLogLevel, "[OptimizerBreakoutScalper] ");
   
   // Determine which symbol to use
   if(InpSymbolToTrade == "")
   {
      currentSymbol = Symbol();
   }
   else
   {
      currentSymbol = InpSymbolToTrade;
   }
   
   Logger::Info("=== INITIALIZING OPTIMIZER BREAKOUT SCALPER ===");
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
   
   // Apply input overrides - Strategy Identity
   if(InpStrategyName != "")
      config.strategyName = InpStrategyName;
   if(InpStrategyComment != "")
      config.strategyComment = InpStrategyComment;
   if(InpBaseMagicNumber >= 0)
      config.baseMagic = InpBaseMagicNumber;
   
   // Symbols Configuration
   if(InpSymbolsList != "")
      config.symbolsList = InpSymbolsList;
   config.useAllSymbols = IntToBoolWithConfig(InpUseAllMarketWatch, config.useAllSymbols);
   if(InpTradingTimeframe != PERIOD_CURRENT)
      config.timeframe = InpTradingTimeframe;
   
   // Risk Management
   if(InpRiskPercent > 0.0)
      config.riskPercent = InpRiskPercent;
   if(InpTpPoints >= 0)
      config.tpPoints = InpTpPoints;
   if(InpSlPoints >= 0)
      config.slPoints = InpSlPoints;
   
   // Trailing Stop Configuration
   if(InpTslTriggerPoints >= 0)
      config.tslTriggerPoints = InpTslTriggerPoints;
   if(InpTslPoints >= 0)
      config.tslPoints = InpTslPoints;
   config.useDynamicTSLTrigger = IntToBoolWithConfig(InpUseDynamicTSLTrigger, config.useDynamicTSLTrigger);
   if(InpTslCostMultiplier >= 0.0)
      config.tslCostMultiplier = InpTslCostMultiplier;
   if(InpTslMinTriggerPoints >= 0)
      config.tslMinTriggerPoints = InpTslMinTriggerPoints;
   
   // Trading Hours
   if(InpTradingTimeRanges != "")
      config.tradingTimeRanges = InpTradingTimeRanges;
   if(InpStartHour >= 0)
      config.startHour = InpStartHour;
   if(InpEndHour >= 0)
      config.endHour = InpEndHour;
   
   // Strategy Parameters
   if(InpBarsAnalysis >= 0)
      config.barsN = InpBarsAnalysis;
   if(InpExpirationBars >= 0)
      config.expirationBars = InpExpirationBars;
   if(InpOrderDistancePoints >= 0)
      config.orderDistPoints = InpOrderDistancePoints;
   if(InpPriceTolerancePercent >= 0.0)
      config.priceTolerancePercent = InpPriceTolerancePercent;
   if(InpSlippagePoints >= 0)
      config.slippagePoints = InpSlippagePoints;
   if(InpEntryOffsetPoints >= 0)
      config.entryOffsetPoints = InpEntryOffsetPoints;
   
   // Trailing Take Profit
   config.useTrailingTP = IntToBoolWithConfig(InpUseTrailingTP, config.useTrailingTP);
   config.trailingTPMode = IntToTrailingTPMode(InpTrailingTPMode, config.trailingTPMode);
   if(InpCustomTPLevels != "")
      config.customTPLevels = InpCustomTPLevels;
   
   // Risk Multiplier
   config.useRiskMultiplier = IntToBoolWithConfig(InpUseRiskMultiplier, config.useRiskMultiplier);
   if(InpRiskMultTimeRanges != "")
      config.riskMultTimeRanges = InpRiskMultTimeRanges;
   if(InpRiskMultiplier >= 0.0)
      config.riskMultiplier = InpRiskMultiplier;
   if(InpRiskMultDescription != "")
      config.riskMultDescription = InpRiskMultDescription;
   if(InpRiskMultStartHour >= 0)
      config.riskMultStartHour = InpRiskMultStartHour;
   if(InpRiskMultStartMinute >= 0)
      config.riskMultStartMinute = InpRiskMultStartMinute;
   if(InpRiskMultEndHour >= 0)
      config.riskMultEndHour = InpRiskMultEndHour;
   if(InpRiskMultEndMinute >= 0)
      config.riskMultEndMinute = InpRiskMultEndMinute;
   
   // News Filter
   config.useNewsFilter = IntToBoolWithConfig(InpUseNewsFilter, config.useNewsFilter);
   if(InpNewsCurrencies != "")
      config.newsCurrencies = InpNewsCurrencies;
   if(InpKeyNewsEvents != "")
      config.keyNewsEvents = InpKeyNewsEvents;
   if(InpStopBeforeNewsMin >= 0)
      config.stopBeforeNewsMin = InpStopBeforeNewsMin;
   if(InpStartAfterNewsMin >= 0)
      config.startAfterNewsMin = InpStartAfterNewsMin;
   if(InpNewsLookupDays >= 0)
      config.newsLookupDays = InpNewsLookupDays;
   config.newsSeparator = IntToSeparator(InpNewsSeparator, config.newsSeparator);
   if(InpNewsBlockMsg != "")
      config.newsBlockMsg = InpNewsBlockMsg;
   
   // FVG Filter
   config.useFvgFilter = IntToBoolWithConfig(InpUseFvgFilter, config.useFvgFilter);
   
   // Alert Messages
   if(InpHourBlockMsg != "")
      config.hourBlockMsg = InpHourBlockMsg;
   if(InpDayBlockMsg != "")
      config.dayBlockMsg = InpDayBlockMsg;
   if(InpBothBlockMsg != "")
      config.bothBlockMsg = InpBothBlockMsg;
   
   // Logging
   config.logLevel = IntToLogLevel(InpLogLevel, config.logLevel);
   
   // Update logger level if it was using default (InpLogLevel == -1)
   if(InpLogLevel == -1)
   {
      Logger::SetLevel(config.logLevel);
   }
    
   
   // Log which values were overridden
   LogInputOverrides();
   
   // Validate symbol is available before creating bot
   if(!ValidateSymbolAvailable(currentSymbol))
   {
      return(CleanupAndFail("ERROR: Symbol " + currentSymbol + " is not available for trading"));
   }
   
   // Initialize bot with configuration
bot = new ForexScalperBot(config);
   if(bot == NULL)
   {
      return(CleanupAndFail("ERROR: Failed to create bot instance"));
   }
   
   if(!bot.Initialize())
   {
      return(CleanupAndFail("ERROR: Bot initialization failed"));
   }

   if(config.orderDistPoints<=config.entryOffsetPoints)
   {

      return(CleanupAndFail("ERROR: Bot orderDistPoints underor equal entryOffsetPoints"));
   }
   
   // Display configuration info
   DisplayConfigurationInfo(config);
   
   Logger::Success("✅ OPTIMIZER BREAKOUT SCALPER INITIALIZED SUCCESSFULLY");
   Logger::Info("Symbol: " + currentSymbol);
   Logger::Info("Strategy: " + config.strategyName);
   Logger::Info("Magic: " + IntegerToString(config.baseMagic));
   Logger::Info("Risk: " + DoubleToString(config.riskPercent, 1) + "%");
   
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
   
   Logger::Info("=== OPTIMIZER BREAKOUT SCALPER DEINITIALIZED ===");
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
      riskMultStr = StringFormat("x%.1f (%s)", 
                                config.riskMultiplier,
                                config.riskMultTimeRanges != "" ? config.riskMultTimeRanges : 
                                StringFormat("%02d:%02d-%02d:%02d", 
                                           config.riskMultStartHour, config.riskMultStartMinute,
                                           config.riskMultEndHour, config.riskMultEndMinute));
   }
   
   string newsFilterStr = "OFF";
   if(config.useNewsFilter) {
      newsFilterStr = StringFormat("ON (%dmin/%dmin) - %s", 
                                  config.stopBeforeNewsMin, config.startAfterNewsMin, config.newsCurrencies);
   }
   
   string fvgFilterStr = "OFF";
   if(config.useFvgFilter) {
      fvgFilterStr = "ON";
   }
   
   string info = StringFormat(
      "=== %s ===\n" +
      "Symbol: %s\n" +
      "Magic: %d\n" +
      "Timeframe: %s\n" +
      "Risk: %.1f%%\n" +
      "TP/SL: %d/%d points\n" +
      "Strategy: %s\n" +
      "Order Distance: %d pts | Price Tolerance: %.3f%%\n" +
      "Bars Analysis: %d\n" +
      "Trading Hours: %s\n" +
      "Trailing TP: %s\n" +
      "Risk Multiplier: %s\n" +
      "News Filter: %s\n" +
      "FVG Filter: %s",
      config.strategyName,
      currentSymbol,
      config.baseMagic,
      EnumToString(config.timeframe),
      config.riskPercent,
      config.tpPoints, config.slPoints,
      strategyTypeStr,
      config.orderDistPoints,
      config.priceTolerancePercent,
      config.barsN,
      config.tradingTimeRanges != "" ? config.tradingTimeRanges : 
         StringFormat("%02d:00-%02d:00", config.startHour, config.endHour),
      trailingTPStr,
      riskMultStr,
      newsFilterStr,
      fvgFilterStr
   );
   
   Comment(info);
   Logger::Info("=== CONFIGURATION INFO ===");
   Logger::Info(info);
   Logger::Info("==========================");
}

//+------------------------------------------------------------------+
//| Log which input values were overridden                           |
//+------------------------------------------------------------------+
void LogInputOverrides()
{
   int overrideCount = 0;
   string overrides = "📋 Input Overrides:\n";
   
   if(InpStrategyName != "") { overrides += "  - Strategy Name\n"; overrideCount++; }
   if(InpStrategyComment != "") { overrides += "  - Strategy Comment\n"; overrideCount++; }
   if(InpBaseMagicNumber >= 0) { overrides += "  - Base Magic\n"; overrideCount++; }
   if(InpSymbolsList != "") { overrides += "  - Symbols List\n"; overrideCount++; }
   if(InpUseAllMarketWatch != -1) { overrides += "  - Use All Market Watch\n"; overrideCount++; }
   if(InpRiskPercent >= 0.0) { overrides += "  - Risk Percent\n"; overrideCount++; }
   if(InpTpPoints >= 0) { overrides += "  - TP Points\n"; overrideCount++; }
   if(InpSlPoints >= 0) { overrides += "  - SL Points\n"; overrideCount++; }
   if(InpTslTriggerPoints >= 0) { overrides += "  - TSL Trigger Points\n"; overrideCount++; }
   if(InpTslPoints >= 0) { overrides += "  - TSL Points\n"; overrideCount++; }
   if(InpUseDynamicTSLTrigger != -1) { overrides += "  - Use Dynamic TSL Trigger\n"; overrideCount++; }
   if(InpTslCostMultiplier >= 0.0) { overrides += "  - TSL Cost Multiplier\n"; overrideCount++; }
   if(InpTslMinTriggerPoints >= 0) { overrides += "  - TSL Min Trigger Points\n"; overrideCount++; }
   if(InpTradingTimeRanges != "") { overrides += "  - Trading Time Ranges\n"; overrideCount++; }
   if(InpBarsAnalysis >= 0) { overrides += "  - Bars Analysis\n"; overrideCount++; }
   if(InpExpirationBars >= 0) { overrides += "  - Expiration Bars\n"; overrideCount++; }
   if(InpOrderDistancePoints >= 0) { overrides += "  - Order Distance Points\n"; overrideCount++; }
   if(InpPriceTolerancePercent >= 0.0) { overrides += "  - Price Tolerance Percent\n"; overrideCount++; }
   if(InpSlippagePoints >= 0) { overrides += "  - Slippage Points\n"; overrideCount++; }
   if(InpEntryOffsetPoints >= 0) { overrides += "  - Entry Offset Points\n"; overrideCount++; }
   if(InpUseTrailingTP != -1) { overrides += "  - Use Trailing TP\n"; overrideCount++; }
   if(InpTrailingTPMode != -1) { overrides += "  - Trailing TP Mode\n"; overrideCount++; }
   if(InpCustomTPLevels != "") { overrides += "  - Custom TP Levels\n"; overrideCount++; }
   if(InpUseRiskMultiplier != -1) { overrides += "  - Use Risk Multiplier\n"; overrideCount++; }
   if(InpRiskMultTimeRanges != "") { overrides += "  - Risk Mult Time Ranges\n"; overrideCount++; }
   if(InpRiskMultiplier >= 0.0) { overrides += "  - Risk Multiplier\n"; overrideCount++; }
   if(InpUseNewsFilter != -1) { overrides += "  - Use News Filter\n"; overrideCount++; }
   if(InpNewsCurrencies != "") { overrides += "  - News Currencies\n"; overrideCount++; }
   if(InpKeyNewsEvents != "") { overrides += "  - Key News Events\n"; overrideCount++; }
   if(InpStopBeforeNewsMin >= 0) { overrides += "  - Stop Before News Min\n"; overrideCount++; }
   if(InpStartAfterNewsMin >= 0) { overrides += "  - Start After News Min\n"; overrideCount++; }
   if(InpNewsLookupDays >= 0) { overrides += "  - News Lookup Days\n"; overrideCount++; }
   if(InpNewsSeparator != -1) { overrides += "  - News Separator\n"; overrideCount++; }
   if(InpUseFvgFilter != -1) { overrides += "  - Use FVG Filter\n"; overrideCount++; }
   if(InpLogLevel != -1) { overrides += "  - Log Level\n"; overrideCount++; }
   
   if(overrideCount == 0)
   {
      Logger::Info("ℹ️ No input overrides - using full configuration defaults");
   }
   else
   {
      Logger::Info("✅ " + IntegerToString(overrideCount) + " input value(s) overridden:");
      Logger::Info(overrides);
   }
}

