//+------------------------------------------------------------------+
//|                                         ForexScalper_Tester.mq5  |
//|                                    Forex Scalper - Test Version   |
//|                                                     Version 3.00  |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

// Include required enums and types BEFORE input declarations
#include <Trade\Trade.mqh>
#include "../../EA/Shared/TradingEnums.mqh"
#include "../../EA/Shared/TrailingTP_System.mqh"
#include "../../EA/Shared/TradingUtils.mqh"
#include "../../EA/Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS FOR TESTING                                     |
//+------------------------------------------------------------------+

input group "🎯 STRATEGY IDENTITY"
input string   InpStrategyName = "Forex Scalper V1.1";        // Strategy Name
input string   InpStrategyComment = "Scalping Robot";         // Strategy Comment
input int      InpBaseMagicNumber = 298347;                  // Base Magic Number

input group "📊 SYMBOLS CONFIGURATION"  
input string   InpDefaultSymbols = "EURUSD,GBPUSD";  // Symbols List (comma separated)
input bool     InpUseAllMarketWatch = false;                 // Use All Market Watch Symbols
input ENUM_TIMEFRAMES InpTradingTimeframe = PERIOD_M5;       // Trading Timeframe

input group "💰 RISK MANAGEMENT"
input double   InpRiskPercent = 4.0;                        // Risk Percent (% of capital divided by symbol count)
input int      InpTpPoints = 200;                           // Take Profit Points (10 points = 1 pip)
input int      InpSlPoints = 180;                           // Stop Loss Points (10 points = 1 pip)

input group "🎯 TRAILING STOP CONFIGURATION"
input int      InpTslTriggerPoints = 10;                    // TSL Trigger Points (profit before TSL activates)
input int      InpTslPoints = 10;                           // TSL Points (trailing stop distance)

input group "⏰ TRADING HOURS (0 = Inactive)"
input int      InpStartHour = 7;                            // Start Hour
input int      InpEndHour = 20;                             // End Hour

input group "📈 STRATEGY PARAMETERS"
input int      InpBarsAnalysis = 5;                         // Bars Analysis
input int      InpExpirationBars = 50;                      // Expiration Bars
input int      InpOrderDistancePoints = 80;                // Order Distance (Points)
input int      InpSlippagePoints = 10;                     // Slippage Tolerance (Points)
input int      InpEntryOffsetPoints = 0;                   // Entry Offset for Stop Orders (Points)
input ENUM_SWING_DETECTION_MODE InpSwingDetectionMode = SWING_DETECTION_WICK; // Swing Detection Mode

input group "🎯 TRAILING TAKE PROFIT"
input bool     InpUseTrailingTP = true;                     // Use Trailing TP
input ENUM_TRAILING_TP_MODE InpTrailingTPMode = TRAILING_TP_STEPPED; // Trailing TP Mode
input string   InpCustomTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150"; // Custom TP Levels

input group "🚀 RISK MULTIPLIER (BOOST PERIOD)"
input bool     InpUseRiskMultiplier = false;                 // Use Risk Multiplier
input int      InpRiskMultStartHour = 13;                   // Risk Multiplier Start Hour
input int      InpRiskMultStartMinute = 0;                  // Risk Multiplier Start Minute
input int      InpRiskMultEndHour = 17;                     // Risk Multiplier End Hour
input int      InpRiskMultEndMinute = 0;                    // Risk Multiplier End Minute
input double   InpRiskMultiplier = 1.5;                     // Risk Multiplier Value
input string   InpRiskMultDescription = "London-NY Overlap"; // Risk Multiplier Description

input group "📰 NEWS FILTER"
input bool     InpUseNewsFilter = false;                        // Use News Filter
input string   InpNewsCurrencies = "USD,EUR,GBP";               // Affected Currencies (comma separated)
input string   InpKeyNewsEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP"; // High Impact Events
input int      InpStopBeforeNewsMin = 30;                       // Minutes Before News to Stop Trading
input int      InpStartAfterNewsMin = 10;                       // Minutes After News to Resume Trading
input int      InpNewsLookupDays = 7;                           // Days Ahead to Check News
input ENUM_SEPARATOR InpNewsSeparator = COMMA;                  // List Separator (COMMA or SEMICOLON)
input string   InpNewsBlockMsg = "📰 TRADING PAUSED - High Impact News Event"; // News Block Message

input group "🚨 ALERT MESSAGES"
input string   InpHourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";     // Hour Block Message
input string   InpDayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";      // Day Block Message
input string   InpBothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule"; // Both Block Message

input group "🔧 LOGGING"
input ENUM_LOG_LEVEL InpLogLevel = LOG_INFO;  // Log Level (DEBUG/INFO/WARNING/ERROR)

//+------------------------------------------------------------------+

// Include the bot engine (all logic is here)
#include "core/ForexScalperBot.mqh"

// Global bot instance
ForexScalperBot* bot = NULL;

//+------------------------------------------------------------------+
//| 🧪 TEST MAGIC NUMBERS (à supprimer après validation)            |
//+------------------------------------------------------------------+
void TestMagicNumbers()
{
   string testSymbols[] = {"EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "US500.cash"};
   int baseMagic = InpBaseMagicNumber;
   
   Print("═══════════════════════════════════════");
   Print("🧪 TEST MAGIC NUMBER GENERATION");
   Print("═══════════════════════════════════════");
   
   for(int i = 0; i < ArraySize(testSymbols); i++)
   {
      int m1 = GenerateSymbolMagicNumber(baseMagic, testSymbols[i], InpTradingTimeframe);
      int m2 = GenerateSymbolMagicNumber(baseMagic, testSymbols[i], InpTradingTimeframe);
      int m3 = GenerateSymbolMagicNumber(baseMagic, testSymbols[i], PERIOD_H1);
      
      Print(StringFormat("%s %s: %d | H1: %d | Stable: %s", 
            testSymbols[i], EnumToString(InpTradingTimeframe), m1, m3, (m1 == m2 ? "✅" : "❌")));
   }
   
   // Test collision
   bool hasCollision = false;
   for(int i = 0; i < ArraySize(testSymbols); i++)
   {
      for(int j = i+1; j < ArraySize(testSymbols); j++)
      {
         int m_i = GenerateSymbolMagicNumber(baseMagic, testSymbols[i], InpTradingTimeframe);
         int m_j = GenerateSymbolMagicNumber(baseMagic, testSymbols[j], InpTradingTimeframe);
         if(m_i == m_j)
         {
            Print("❌ COLLISION: ", testSymbols[i], " vs ", testSymbols[j], " → ", m_i);
            hasCollision = true;
         }
      }
   }
   
   if(!hasCollision)
      Print("✅ Pas de collision détectée");
   
   Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize Logger first
   Logger::Initialize(InpLogLevel, "[ForexScalper_Tester] ");
   
   // Create bot configuration from input parameters
   BotConfig config;
   config.strategyName = InpStrategyName;
   config.strategyComment = InpStrategyComment;
   config.baseMagic = InpBaseMagicNumber;
   config.symbolsList = InpDefaultSymbols;
   config.useAllSymbols = InpUseAllMarketWatch;
   config.timeframe = InpTradingTimeframe;
   config.riskPercent = InpRiskPercent;
   config.tpPoints = InpTpPoints;
   config.slPoints = InpSlPoints;
   config.tslTriggerPoints = InpTslTriggerPoints;
   config.tslPoints = InpTslPoints;
   config.startHour = InpStartHour;
   config.endHour = InpEndHour;
   config.barsN = InpBarsAnalysis;
   config.expirationBars = InpExpirationBars;
   config.orderDistPoints = InpOrderDistancePoints;
   config.slippagePoints = InpSlippagePoints;
   config.entryOffsetPoints = InpEntryOffsetPoints;
   config.swingDetectionMode = InpSwingDetectionMode;
   config.useTrailingTP = InpUseTrailingTP;
   config.trailingTPMode = InpTrailingTPMode;
   config.customTPLevels = InpCustomTPLevels;
   config.hourBlockMsg = InpHourBlockMsg;
   config.dayBlockMsg = InpDayBlockMsg;
   config.bothBlockMsg = InpBothBlockMsg;
   
   // Risk Multiplier Configuration
   config.useRiskMultiplier = InpUseRiskMultiplier;
   config.riskMultStartHour = InpRiskMultStartHour;
   config.riskMultStartMinute = InpRiskMultStartMinute;
   config.riskMultEndHour = InpRiskMultEndHour;
   config.riskMultEndMinute = InpRiskMultEndMinute;
   config.riskMultiplier = InpRiskMultiplier;
   config.riskMultDescription = InpRiskMultDescription;
   
   // News Filter Configuration
   config.useNewsFilter = InpUseNewsFilter;
   config.newsCurrencies = InpNewsCurrencies;
   config.keyNewsEvents = InpKeyNewsEvents;
   config.stopBeforeNewsMin = InpStopBeforeNewsMin;
   config.startAfterNewsMin = InpStartAfterNewsMin;
   config.newsLookupDays = InpNewsLookupDays;
   config.newsSeparator = InpNewsSeparator;
   config.newsBlockMsg = InpNewsBlockMsg;
   
   // Logging Configuration
   config.logLevel = InpLogLevel;
   
   // 🧪 TEST MAGIC NUMBERS (à supprimer après validation)
   TestMagicNumbers();
   
   // Initialize bot
   bot = new ForexScalperBot(config);
   
   if(bot == NULL)
   {
      Logger::Error("❌ ERROR: Failed to create bot instance");
      return(INIT_FAILED);
   }
   
   // Initialize and validate
   if(!bot.Initialize())
   {
      Logger::Error("❌ ERROR: Bot initialization failed");
      delete bot;
      bot = NULL;
      return(INIT_FAILED);
   }
   
   // Display input parameters on chart
   DisplayInputParameters();
   
   // Save current configuration as header template
   SaveConfigurationTemplate();
   
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
//| Display input parameters on chart                                |
//+------------------------------------------------------------------+
void DisplayInputParameters()
{
   if(bot == NULL || bot.GetChartManager() == NULL)
   {
      Logger::Warning("⚠️ Warning: Cannot display parameters - bot or ChartManager not initialized");
      return;
   }
   
   string strategyTypeStr = "BREAKOUT";
   string trailingTPStr = "Disabled";
   
   if(InpUseTrailingTP)
   {
      int modeValue = (int)InpTrailingTPMode;
      switch(modeValue)
      {
         case TRAILING_TP_LINEAR: trailingTPStr = "LINEAR"; break;
         case TRAILING_TP_STEPPED: trailingTPStr = "STEPPED"; break;
         case TRAILING_TP_EXPONENTIAL: trailingTPStr = "EXPONENTIAL"; break;
         case TRAILING_TP_CUSTOM: trailingTPStr = "CUSTOM"; break;
         default: trailingTPStr = "UNKNOWN"; break;
      }
   }
   
   string riskMultStr = "OFF";
   if(InpUseRiskMultiplier) {
      riskMultStr = StringFormat("x%.1f (%02d:%02d-%02d:%02d)", 
                                InpRiskMultiplier,
                                InpRiskMultStartHour, InpRiskMultStartMinute,
                                InpRiskMultEndHour, InpRiskMultEndMinute);
   }
   
   string newsFilterStr = "OFF";
   if(InpUseNewsFilter) {
      newsFilterStr = StringFormat("ON (%dmin/%dmin) - %s", 
                                  InpStopBeforeNewsMin, InpStartAfterNewsMin, InpNewsCurrencies);
   }
   
   // Créer array pour affichage multi-lignes
   string inputLines[12];
   inputLines[0] = "=== " + InpStrategyName + " TESTER ===";
   inputLines[1] = "Magic: " + IntegerToString(InpBaseMagicNumber);
   inputLines[2] = "Symbols: " + (InpUseAllMarketWatch ? "All Market Watch" : InpDefaultSymbols);
   inputLines[3] = "Timeframe: " + EnumToString(InpTradingTimeframe);
   inputLines[4] = "Risk: " + DoubleToString(InpRiskPercent, 1) + "%";
   inputLines[5] = "TP/SL: " + IntegerToString(InpTpPoints) + "/" + IntegerToString(InpSlPoints) + " points";
   inputLines[6] = "Strategy: " + strategyTypeStr;
   inputLines[7] = "Bars Analysis: " + IntegerToString(InpBarsAnalysis);
   inputLines[8] = "Trading Hours: " + StringFormat("%02d:00-%02d:00", InpStartHour, InpEndHour);
   inputLines[9] = "Trailing TP: " + trailingTPStr;
   inputLines[10] = "Risk Multiplier: " + riskMultStr;
   inputLines[11] = "News Filter: " + newsFilterStr;
   
   // Position en haut à gauche
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int yTopLeft = 30;   // Position en haut
   int xTopLeft = 20;   // Position à gauche
   
   // Utiliser ChartManager pour affichage en haut à gauche
   bot.GetChartManager().ShowMultiLineInfo(inputLines, CORNER_LEFT_UPPER, xTopLeft, yTopLeft, 16, 
                                          clrBlack, 12, "InputParameters");
   
   // Garder l'ancien système pour compatibilité
   string inputs = StringFormat(
      "=== %s TESTER ===\n" +
      "Magic: %d\n" +
      "Symbols: %s\n" +
      "Timeframe: %s\n" +
      "Risk: %.1f%%\n" +
      "TP/SL: %d/%d points\n" +
      "Strategy: %s\n" +
      "Bars Analysis: %d\n" +
      "Trading Hours: %02d:00-%02d:00\n" +
      "Trailing TP: %s\n" +
      "Risk Multiplier: %s\n" +
      "News Filter: %s",
      InpStrategyName,
      InpBaseMagicNumber,
      InpUseAllMarketWatch ? "All Market Watch" : InpDefaultSymbols,
      EnumToString(InpTradingTimeframe),
      InpRiskPercent,
      InpTpPoints, InpSlPoints,
      strategyTypeStr,
      InpBarsAnalysis,
      InpStartHour, InpEndHour,
      trailingTPStr,
      riskMultStr,
      newsFilterStr
   );
   
   Logger::Info("=== TESTER INPUT PARAMETERS ===");
   Logger::Info(inputs);
   Logger::Info("================================");
}

//+------------------------------------------------------------------+
//| Save configuration as header template                             |
//+------------------------------------------------------------------+
void SaveConfigurationTemplate()
{
   // Generate timestamp and filename
   datetime currentTime = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   string timestamp = StringFormat("%04d%02d%02d_%02d%02d", 
                                  dt.year, 
                                  dt.mon, 
                                  dt.day,
                                  dt.hour, 
                                  dt.min);
   
   // Use COMMON_FILES directory with ForexScalperConfigs folder
   string filename = "ForexScalperConfigs\\ForexScalperConfig_" + timestamp + ".mqh";
   
   // Create configuration group class content
   string headerContent = CreateConfigGroupTemplate();
   
   // Check if file already exists (like JT_TradeTracker)
   int fileHandle = FileOpen(filename, FILE_READ|FILE_COMMON|FILE_TXT);
   bool fileExists = (fileHandle != INVALID_HANDLE);
   
   if(fileExists) {
      FileClose(fileHandle);
      Logger::Warning("⚠️ Configuration file already exists in Common Files: " + filename + " - Overwriting...");
   }
   
   // Write to COMMON_FILES directory with UTF-8 encoding for proper icon display
   fileHandle = FileOpen(filename, FILE_WRITE|FILE_COMMON|FILE_TXT);
   if(fileHandle == INVALID_HANDLE)
   {
      Logger::Error("❌ ERROR: Impossible de créer le fichier de config dans Common Files: " + filename);
      return;
   }
   
   FileWriteString(fileHandle, headerContent);
   FileClose(fileHandle);
   
   Logger::Success("✅ Configuration saved to Common Files: " + filename);
   Logger::Info("📁 Location: MetaTrader 5 Common Files directory");
}

//+------------------------------------------------------------------+
//| Create header template content                                    |
//+------------------------------------------------------------------+
string CreateHeaderTemplate()
{
   string strategyTypeStr = "STRATEGY_BREAKOUT";
   
   string trailingTPModeStr = "";
   switch((int)InpTrailingTPMode)
   {
      case TRAILING_TP_LINEAR: trailingTPModeStr = "TRAILING_TP_LINEAR"; break;
      case TRAILING_TP_STEPPED: trailingTPModeStr = "TRAILING_TP_STEPPED"; break;
      case TRAILING_TP_EXPONENTIAL: trailingTPModeStr = "TRAILING_TP_EXPONENTIAL"; break;
      case TRAILING_TP_CUSTOM: trailingTPModeStr = "TRAILING_TP_CUSTOM"; break;
      default: trailingTPModeStr = "TRAILING_TP_STEPPED"; break;
   }
   
   string timeframeStr = "";
   switch(InpTradingTimeframe)
   {
      case PERIOD_M1: timeframeStr = "PERIOD_M1"; break;
      case PERIOD_M5: timeframeStr = "PERIOD_M5"; break;
      case PERIOD_M15: timeframeStr = "PERIOD_M15"; break;
      case PERIOD_M30: timeframeStr = "PERIOD_M30"; break;
      case PERIOD_H1: timeframeStr = "PERIOD_H1"; break;
      case PERIOD_H4: timeframeStr = "PERIOD_H4"; break;
      case PERIOD_D1: timeframeStr = "PERIOD_D1"; break;
      default: timeframeStr = "PERIOD_M5"; break;
   }
   
   string newsSeparatorStr = "";
   switch((int)InpNewsSeparator)
   {
      case COMMA: newsSeparatorStr = "COMMA"; break;
      case SEMICOLON: newsSeparatorStr = "SEMICOLON"; break;
      default: newsSeparatorStr = "COMMA"; break;
   }
   
   
   string content = "//+------------------------------------------------------------------+\n";
   content += "//|                                    ForexScalperConfig.mqh\n";
   content += "//|                                    Configuration Template\n";
   content += "//|                                                     Version 3.00\n";
   content += "//+------------------------------------------------------------------+\n";
   content += "\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   content += "//   CONFIG BLOCK - PERSONNALISEZ ICI\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   content += "\n";
   content += "// IDENTITE DE LA STRATEGIE\n";
   content += "#define STRATEGY_NAME          \"" + InpStrategyName + "\"\n";
   content += "#define STRATEGY_COMMENT       \"" + InpStrategyComment + "\"\n";
   content += "#define BASE_MAGIC_NUMBER      " + IntegerToString(InpBaseMagicNumber) + "\n";
   content += "\n";
   content += "// CONFIGURATION DES SYMBOLES\n";
   content += "#define DEFAULT_SYMBOLS        \"" + InpDefaultSymbols + "\"\n";
   content += "#define USE_ALL_MARKET_WATCH   " + (InpUseAllMarketWatch ? "true" : "false") + "\n";
   content += "#define TRADING_TIMEFRAME      " + timeframeStr + "\n";
   content += "\n";
   content += "// GESTION DU RISQUE\n";
   content += "#define RISK_PERCENT           " + DoubleToString(InpRiskPercent, 1) + "\n";
   content += "\n";
   content += "// TAKE PROFIT / STOP LOSS (en points, 10 points = 1 pip)\n";
   content += "#define TAKE_PROFIT_POINTS     " + IntegerToString(InpTpPoints) + "\n";
   content += "#define STOP_LOSS_POINTS       " + IntegerToString(InpSlPoints) + "\n";
   content += "\n";
   content += "// TRAILING STOP LOSS\n";
   content += "#define TSL_TRIGGER_POINTS     " + IntegerToString(InpTslTriggerPoints) + "\n";
   content += "#define TSL_POINTS             " + IntegerToString(InpTslPoints) + "\n";
   content += "\n";
   content += "// HEURES DE TRADING (0 = inactif, 1-23 = actif)\n";
   content += "#define START_HOUR             " + IntegerToString(InpStartHour) + "\n";
   content += "#define END_HOUR               " + IntegerToString(InpEndHour) + "\n";
   content += "\n";
   content += "// PARAMETRES DE STRATEGIE\n";
   content += "#define STRATEGY_TYPE          " + strategyTypeStr + "\n";
   content += "#define BARS_ANALYSIS          " + IntegerToString(InpBarsAnalysis) + "\n";
   content += "#define EXPIRATION_BARS        " + IntegerToString(InpExpirationBars) + "\n";
   content += "#define ORDER_DISTANCE_POINTS  " + IntegerToString(InpOrderDistancePoints) + "\n";
   content += "\n";
   content += "// TRAILING TAKE PROFIT\n";
   content += "#define USE_TRAILING_TP        " + (InpUseTrailingTP ? "true" : "false") + "\n";
   content += "#define TRAILING_TP_MODE       " + trailingTPModeStr + "\n";
   content += "#define CUSTOM_TP_LEVELS       \"" + InpCustomTPLevels + "\"\n";
   content += "\n";
   content += "// RISK MULTIPLIER (BOOST PERIOD)\n";
   content += "#define USE_RISK_MULTIPLIER    " + (InpUseRiskMultiplier ? "true" : "false") + "\n";
   content += "#define RISK_MULT_START_HOUR   " + IntegerToString(InpRiskMultStartHour) + "\n";
   content += "#define RISK_MULT_START_MINUTE " + IntegerToString(InpRiskMultStartMinute) + "\n";
   content += "#define RISK_MULT_END_HOUR     " + IntegerToString(InpRiskMultEndHour) + "\n";
   content += "#define RISK_MULT_END_MINUTE   " + IntegerToString(InpRiskMultEndMinute) + "\n";
   content += "#define RISK_MULTIPLIER        " + DoubleToString(InpRiskMultiplier, 1) + "\n";
   content += "#define RISK_MULT_DESCRIPTION  \"" + InpRiskMultDescription + "\"\n";
   content += "\n";
   content += "// NEWS FILTER\n";
   content += "#define USE_NEWS_FILTER        " + (InpUseNewsFilter ? "true" : "false") + "\n";
   content += "#define NEWS_CURRENCIES        \"" + InpNewsCurrencies + "\"\n";
   content += "#define KEY_NEWS_EVENTS        \"" + InpKeyNewsEvents + "\"\n";
   content += "#define STOP_BEFORE_NEWS_MIN   " + IntegerToString(InpStopBeforeNewsMin) + "\n";
   content += "#define START_AFTER_NEWS_MIN   " + IntegerToString(InpStartAfterNewsMin) + "\n";
   content += "#define NEWS_LOOKUP_DAYS       " + IntegerToString(InpNewsLookupDays) + "\n";
   content += "#define NEWS_SEPARATOR         " + newsSeparatorStr + "\n";
   content += "#define NEWS_BLOCK_MSG         \"" + InpNewsBlockMsg + "\"\n";
   content += "\n";
   content += "// MESSAGES D'ALERTE\n";
   content += "#define HOUR_BLOCK_MSG         \"" + InpHourBlockMsg + "\"\n";
   content += "#define DAY_BLOCK_MSG          \"" + InpDayBlockMsg + "\"\n";
   content += "#define BOTH_BLOCK_MSG         \"" + InpBothBlockMsg + "\"\n";
   content += "\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   content += "//   FIN DU CONFIG BLOCK - NE PAS MODIFIER CI-DESSOUS\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   
   return content;
}

//+------------------------------------------------------------------+
//| Create configuration group class template                         |
//+------------------------------------------------------------------+
string CreateConfigGroupTemplate()
{
   string strategyTypeStr = "STRATEGY_BREAKOUT";
   
   string trailingTPModeStr = "";
   switch((int)InpTrailingTPMode)
   {
      case TRAILING_TP_LINEAR: trailingTPModeStr = "TRAILING_TP_LINEAR"; break;
      case TRAILING_TP_STEPPED: trailingTPModeStr = "TRAILING_TP_STEPPED"; break;
      case TRAILING_TP_EXPONENTIAL: trailingTPModeStr = "TRAILING_TP_EXPONENTIAL"; break;
      case TRAILING_TP_CUSTOM: trailingTPModeStr = "TRAILING_TP_CUSTOM"; break;
      default: trailingTPModeStr = "TRAILING_TP_STEPPED"; break;
   }
   
   string timeframeStr = "";
   switch(InpTradingTimeframe)
   {
      case PERIOD_M1: timeframeStr = "PERIOD_M1"; break;
      case PERIOD_M5: timeframeStr = "PERIOD_M5"; break;
      case PERIOD_M15: timeframeStr = "PERIOD_M15"; break;
      case PERIOD_M30: timeframeStr = "PERIOD_M30"; break;
      case PERIOD_H1: timeframeStr = "PERIOD_H1"; break;
      case PERIOD_H4: timeframeStr = "PERIOD_H4"; break;
      case PERIOD_D1: timeframeStr = "PERIOD_D1"; break;
      default: timeframeStr = "PERIOD_M5"; break;
   }
   
   string newsSeparatorStr = "";
   switch((int)InpNewsSeparator)
   {
      case COMMA: newsSeparatorStr = "COMMA"; break;
      case SEMICOLON: newsSeparatorStr = "SEMICOLON"; break;
      default: newsSeparatorStr = "COMMA"; break;
   }
   
   // Generate group name from strategy name
   string groupClassName = InpStrategyName;
   StringReplace(groupClassName, " ", "_");
   StringReplace(groupClassName, ".", "_");
   StringReplace(groupClassName, "V1_0", "");
   StringReplace(groupClassName, "V1.0", "");
   StringTrimRight(groupClassName);
   
   string content = "//+------------------------------------------------------------------+\n";
   content += "//|                                    " + groupClassName + "Group.mqh\n";
   content += "//|                                    Configuration Group Class\n";
   content += "//|                                                     Version 3.00\n";
   content += "//+------------------------------------------------------------------+\n";
   content += "#property strict\n\n";
   content += "#include \"../../ScalpingFx/common/ConfigLoader.mqh\"\n\n";
   
   content += "//+------------------------------------------------------------------+\n";
   content += "//| " + groupClassName + " Group Configuration                     |\n";
   content += "//+------------------------------------------------------------------+\n";
   content += "class C" + groupClassName + "Group : public CConfigGroup\n";
   content += "{\n";
   content += "public:\n";
   content += "   bool Initialize() override\n";
   content += "   {\n";
   content += "      m_groupName = \"" + groupClassName + "\";\n";
   content += "      AddSymbols(\"" + InpDefaultSymbols + "\");\n\n";
   content += "      // Generated configuration from tester\n";
   content += "      m_config.strategyName = \"" + InpStrategyName + "\";\n";
   content += "      m_config.strategyComment = \"" + InpStrategyComment + "\";\n";
   content += "      m_config.baseMagic = " + IntegerToString(InpBaseMagicNumber) + ";\n";
   content += "      m_config.useAllSymbols = " + (InpUseAllMarketWatch ? "true" : "false") + ";\n";
   content += "      m_config.timeframe = " + timeframeStr + ";\n";
   content += "      m_config.riskPercent = " + DoubleToString(InpRiskPercent, 1) + ";\n";
   content += "      m_config.tpPoints = " + IntegerToString(InpTpPoints) + ";\n";
   content += "      m_config.slPoints = " + IntegerToString(InpSlPoints) + ";\n";
   content += "      m_config.tslTriggerPoints = " + IntegerToString(InpTslTriggerPoints) + ";\n";
   content += "      m_config.tslPoints = " + IntegerToString(InpTslPoints) + ";\n";
   content += "      m_config.startHour = " + IntegerToString(InpStartHour) + ";\n";
   content += "      m_config.endHour = " + IntegerToString(InpEndHour) + ";\n";
   // Strategy mode removed in unified behavior
   content += "      m_config.barsN = " + IntegerToString(InpBarsAnalysis) + ";\n";
   content += "      m_config.expirationBars = " + IntegerToString(InpExpirationBars) + ";\n";
   content += "      m_config.orderDistPoints = " + IntegerToString(InpOrderDistancePoints) + ";\n";
   content += "      m_config.useTrailingTP = " + (InpUseTrailingTP ? "true" : "false") + ";\n";
   content += "      m_config.trailingTPMode = " + trailingTPModeStr + ";\n";
   content += "      m_config.customTPLevels = \"" + InpCustomTPLevels + "\";\n";
   content += "      m_config.useRiskMultiplier = " + (InpUseRiskMultiplier ? "true" : "false") + ";\n";
   content += "      m_config.riskMultStartHour = " + IntegerToString(InpRiskMultStartHour) + ";\n";
   content += "      m_config.riskMultStartMinute = " + IntegerToString(InpRiskMultStartMinute) + ";\n";
   content += "      m_config.riskMultEndHour = " + IntegerToString(InpRiskMultEndHour) + ";\n";
   content += "      m_config.riskMultEndMinute = " + IntegerToString(InpRiskMultEndMinute) + ";\n";
   content += "      m_config.riskMultiplier = " + DoubleToString(InpRiskMultiplier, 1) + ";\n";
   content += "      m_config.riskMultDescription = \"" + InpRiskMultDescription + "\";\n";
   content += "      m_config.useNewsFilter = " + (InpUseNewsFilter ? "true" : "false") + ";\n";
   content += "      m_config.newsCurrencies = \"" + InpNewsCurrencies + "\";\n";
   content += "      m_config.keyNewsEvents = \"" + InpKeyNewsEvents + "\";\n";
   content += "      m_config.stopBeforeNewsMin = " + IntegerToString(InpStopBeforeNewsMin) + ";\n";
   content += "      m_config.startAfterNewsMin = " + IntegerToString(InpStartAfterNewsMin) + ";\n";
   content += "      m_config.newsLookupDays = " + IntegerToString(InpNewsLookupDays) + ";\n";
   content += "      m_config.newsSeparator = " + newsSeparatorStr + ";\n";
   content += "      m_config.newsBlockMsg = \"" + InpNewsBlockMsg + "\";\n";
   content += "      m_config.hourBlockMsg = \"" + InpHourBlockMsg + "\";\n";
   content += "      m_config.dayBlockMsg = \"" + InpDayBlockMsg + "\";\n";
   content += "      m_config.bothBlockMsg = \"" + InpBothBlockMsg + "\";\n\n";
   content += "      return true;\n";
   content += "   }\n";
   content += "};\n\n";
   content += "//+------------------------------------------------------------------+\n";
   
   return content;
}
//+------------------------------------------------------------------+
