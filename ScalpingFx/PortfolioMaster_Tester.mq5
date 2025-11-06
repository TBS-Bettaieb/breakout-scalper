//+------------------------------------------------------------------+
//|                                    PortfolioMaster_Tester.mq5    |
//|                         Portfolio Master EA - Config Loader      |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict
#property description "🎯 Master EA pour tester un portefeuille complet"
#property description "📊 Charge automatiquement les configs de chaque symbole"
#property description "💰 Gestion du risque global partagé"

// Include Logger before input parameters to define ENUM_LOG_LEVEL
#include "../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - SIMPLIFIED                                    |
//+------------------------------------------------------------------+

input group "📊 PORTFOLIO SYMBOLS"
input string   InpSymbolsList = "EURUSD,GBPUSD,USDJPY,XAUUSD,GER40.cash,US100.cash,US30.cash,US500.cash"; // Symbols List (comma separated)
input string   InpSymbolsInfo = "Configs loaded automatically per symbol"; // Info (read-only)

input group "💰 GLOBAL RISK OVERRIDE (Optional)"
input double   InpGlobalRiskPercent = -1.0;  // Global Risk % (-1 = use individual configs)
input string   InpRiskInfo = "If > 0: overrides all symbol configs"; // Risk Info

input group "📊 TESTING OPTIONS"
input bool     InpShowDetailedLogs = true;   // Show Detailed Logs
input bool     InpSaveConfiguration = true;  // Save Test Results

input group "🔧 LOGGING"
input ENUM_LOG_LEVEL InpLogLevel = LOG_INFO;  // Log Level (DEBUG/INFO/WARNING/ERROR)

//+------------------------------------------------------------------+

// Include required files
#include "../ScalpingFx/Core/ForexScalperBot.mqh"
#include "../ScalpingFx/common/ConfigLoader.mqh"

// Global variables
CConfigManager* configManager = NULL;
ForexScalperBot* bots[];
string symbols[];
int totalSymbolsGlobal = 0;

// Statistics tracking
struct PortfolioStats
{
   double initialBalance;
   double peakBalance;
   double lowestBalance;
   int totalTrades;
   datetime startTime;
};
PortfolioStats g_stats;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Logger::Initialize(InpLogLevel, "[PortfolioMaster] ");
   Logger::Info("═══════════════════════════════════════════════════");
   Logger::Info("🎯 PORTFOLIO MASTER EA - CONFIG LOADER MODE");
   Logger::Info("═══════════════════════════════════════════════════");
   
   // Initialize statistics
   g_stats.initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_stats.peakBalance = g_stats.initialBalance;
   g_stats.lowestBalance = g_stats.initialBalance;
   g_stats.totalTrades = 0;
   g_stats.startTime = TimeGMT();
   
   Logger::Info("💰 Initial Capital: $" + DoubleToString(g_stats.initialBalance, 2));
   
   // Parse symbols list
   totalSymbolsGlobal = ParseSymbolsList(InpSymbolsList, symbols);
   
   if(totalSymbolsGlobal <= 0)
   {
      Logger::Error("❌ ERROR: No valid symbols found in list: " + InpSymbolsList);
      return(INIT_FAILED);
   }
   
   Logger::Info("📊 Portfolio Size: " + IntegerToString(totalSymbolsGlobal) + " symbols");
   Logger::Info("───────────────────────────────────────────────────");
   
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
   
   Logger::Success("✅ Configuration Manager initialized");
   Logger::Info("───────────────────────────────────────────────────");
   
   // Create bot instances for each symbol
   ArrayResize(bots, totalSymbolsGlobal);
   
   for(int i = 0; i < totalSymbolsGlobal; i++)
   {
      string symbol = symbols[i];
      
      Logger::Info("🔍 Loading configuration for: " + symbol);
      
      // Validate symbol availability
      if(!ValidateSymbolAvailable(symbol))
      {
         Logger::Warning("⚠️ WARNING: Symbol " + symbol + " not available - skipping");
         bots[i] = NULL;
         continue;
      }
      
      // Get configuration for this symbol
      BotConfig config;
      if(!configManager.GetConfigForSymbol(symbol, config))
      {
         Logger::Warning("⚠️ WARNING: No configuration found for " + symbol + " - skipping");
         bots[i] = NULL;
         continue;
      }
      
      // Override risk if global risk is specified
      if(InpGlobalRiskPercent > 0)
      {
         double originalRisk = config.riskPercent;
         config.riskPercent = InpGlobalRiskPercent / totalSymbolsGlobal;
         Logger::Info("   ⚙️ Risk override: " + DoubleToString(originalRisk, 2) + "% → " + 
               DoubleToString(config.riskPercent, 2) + "%");
      }
      
      // Override symbols list to ensure only this symbol is traded
      config.symbolsList = symbol;
      config.useAllSymbols = false;
      
      // Create bot instance
      bots[i] = new ForexScalperBot(config);
      
      if(bots[i] == NULL)
      {
         Logger::Error("❌ ERROR: Failed to create bot for " + symbol);
         continue;
      }
      
      if(!bots[i].Initialize())
      {
         Logger::Error("❌ ERROR: Bot initialization failed for " + symbol);
         delete bots[i];
         bots[i] = NULL;
         continue;
      }
      
      // Display bot info
      Logger::Success("   ✅ Bot initialized:");
      Logger::Info("      Strategy: " + config.strategyName);
      Logger::Info("      Magic: " + IntegerToString(config.baseMagic));
      Logger::Info("      Risk: " + DoubleToString(config.riskPercent, 2) + "%");
      Logger::Info("      TP/SL: " + IntegerToString(config.tpPoints) + "/" + IntegerToString(config.slPoints) + " pts");
      Logger::Info("      Mode: BREAKOUT");
      Logger::Info("───────────────────────────────────────────────────");
   }
   
   // Count active bots
   int activeBots = 0;
   for(int i = 0; i < totalSymbolsGlobal; i++)
   {
      if(bots[i] != NULL) activeBots++;
   }
   
   if(activeBots == 0)
   {
      Logger::Error("❌ ERROR: No bots successfully initialized");
      CleanupBots();
      return(INIT_FAILED);
   }
   
   Logger::Info("═══════════════════════════════════════════════════");
   Logger::Success("✅ Portfolio Master initialized successfully");
   Logger::Info("📊 Active Bots: " + IntegerToString(activeBots) + "/" + IntegerToString(totalSymbolsGlobal));
   Logger::Success("🚀 Ready to test portfolio trading");
   Logger::Info("═══════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Logger::Info("═══════════════════════════════════════════════════");
   Logger::Info("🛑 PORTFOLIO MASTER EA - STOPPING");
   Logger::Info("═══════════════════════════════════════════════════");
   
   // Calculate final statistics
   double finalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double finalEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double totalProfit = finalBalance - g_stats.initialBalance;
   double profitPercent = (totalProfit / g_stats.initialBalance) * 100;
   double maxDrawdownAbs = g_stats.peakBalance - g_stats.lowestBalance;
   double maxDrawdownPct = (maxDrawdownAbs / g_stats.peakBalance) * 100;
   
   datetime endTime = TimeGMT();
   int testDuration = (int)((endTime - g_stats.startTime) / 86400); // Days
   
   Logger::Info("📊 FINAL PORTFOLIO STATISTICS");
   Logger::Info("───────────────────────────────────────────────────");
   Logger::Info("⏱️ Test Duration: " + IntegerToString(testDuration) + " days");
   Logger::Info("💰 Initial Balance: $" + DoubleToString(g_stats.initialBalance, 2));
   Logger::Info("💰 Final Balance: $" + DoubleToString(finalBalance, 2));
   Logger::Info("💰 Final Equity: $" + DoubleToString(finalEquity, 2));
   Logger::Info("───────────────────────────────────────────────────");
   Logger::Info("📈 Total Profit: $" + DoubleToString(totalProfit, 2) + 
         " (" + DoubleToString(profitPercent, 2) + "%)");
   Logger::Info("📉 Max Drawdown: $" + DoubleToString(maxDrawdownAbs, 2) +
         " (" + DoubleToString(maxDrawdownPct, 2) + "%)");
   Logger::Info("📊 Peak Balance: $" + DoubleToString(g_stats.peakBalance, 2));
   Logger::Info("📉 Lowest Balance: $" + DoubleToString(g_stats.lowestBalance, 2));
   Logger::Info("═══════════════════════════════════════════════════");
   
   // Performance rating
   string rating = GetPerformanceRating(profitPercent, maxDrawdownPct);
   Logger::Info("🏆 PERFORMANCE RATING: " + rating);
   Logger::Info("═══════════════════════════════════════════════════");
   
   // Display per-symbol statistics
   DisplayPerSymbolStats();
   
   // Save configuration if enabled
   if(InpSaveConfiguration)
   {
      SaveTestConfiguration(totalProfit, profitPercent, maxDrawdownPct);
   }
   
   // Cleanup
   CleanupBots();
   
   if(configManager != NULL)
   {
      delete configManager;
      configManager = NULL;
   }
   
   Logger::Success("✅ Portfolio Master EA stopped successfully");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Process each bot
   for(int i = 0; i < totalSymbolsGlobal; i++)
   {
      if(bots[i] != NULL)
      {
         bots[i].OnTick();
      }
   }
   
   // Update statistics periodically
   UpdateStatistics();
}

//+------------------------------------------------------------------+
//| Cleanup all bot instances                                        |
//+------------------------------------------------------------------+
void CleanupBots()
{
   for(int i = 0; i < ArraySize(bots); i++)
   {
      if(bots[i] != NULL)
      {
         bots[i].Deinitialize(REASON_REMOVE);
         delete bots[i];
         bots[i] = NULL;
      }
   }
   ArrayFree(bots);
   Logger::Success("✅ All bots cleaned up");
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
//| Update portfolio statistics                                      |
//+------------------------------------------------------------------+
void UpdateStatistics()
{
   static int tickCount = 0;
   tickCount++;
   
   // Update every 100 ticks
   if(tickCount % 100 != 0) return;
   
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(currentBalance > g_stats.peakBalance)
   {
      g_stats.peakBalance = currentBalance;
      
      if(InpShowDetailedLogs && tickCount % 1000 == 0)
      {
         Logger::Info("📈 New Peak Balance: $" + DoubleToString(currentBalance, 2));
      }
   }
   
   if(currentBalance < g_stats.lowestBalance)
   {
      g_stats.lowestBalance = currentBalance;
      double drawdown = ((g_stats.peakBalance - currentBalance) / g_stats.peakBalance) * 100;
      
      if(InpShowDetailedLogs && tickCount % 1000 == 0)
      {
         Logger::Info("📉 Drawdown: " + DoubleToString(drawdown, 2) + "%");
      }
   }
}

//+------------------------------------------------------------------+
//| Display per-symbol statistics                                    |
//+------------------------------------------------------------------+
void DisplayPerSymbolStats()
{
   Logger::Info("═══════════════════════════════════════════════════");
   Logger::Info("📊 PER-SYMBOL PERFORMANCE");
   Logger::Info("═══════════════════════════════════════════════════");
   
 // for(int i = 0; i < totalSymbols; i++)
 // {
 //    if(bots[i] != NULL)
 //    {
 //       string symbol = symbols[i];
 //       double profit = bots[i].GetTotalProfit();
 //       int positions = bots[i].GetTotalPositions();
 //       
 //       Print(symbol, ": P/L=$", DoubleToString(profit, 2), 
 //             " | Positions:", positions);
 //    }
 // }
   
   Logger::Info("═══════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Get performance rating                                           |
//+------------------------------------------------------------------+
string GetPerformanceRating(double profitPercent, double maxDrawdownPct)
{
   if(profitPercent < 0)
      return "❌ FAILED (Negative Return)";
   
   if(maxDrawdownPct > 50)
      return "⚠️ POOR (High Risk - DD > 50%)";
   
   if(profitPercent < 10 && maxDrawdownPct > 30)
      return "⚠️ POOR (Low Return + High Risk)";
   
   if(profitPercent < 20 && maxDrawdownPct < 20)
      return "📊 ACCEPTABLE (Conservative)";
   
   if(profitPercent >= 20 && profitPercent < 50 && maxDrawdownPct < 25)
      return "✅ GOOD (Balanced Risk/Reward)";
   
   if(profitPercent >= 50 && profitPercent < 100 && maxDrawdownPct < 20)
      return "🌟 VERY GOOD (Strong Performance)";
   
   if(profitPercent >= 100 && maxDrawdownPct < 15)
      return "🏆 EXCELLENT (Outstanding Performance)";
   
   return "📊 MODERATE";
}

//+------------------------------------------------------------------+
//| Save test configuration                                          |
//+------------------------------------------------------------------+
void SaveTestConfiguration(double totalProfit, double profitPercent, double maxDrawdownPct)
{
   datetime currentTime = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   string timestamp = StringFormat("%04d%02d%02d_%02d%02d", 
                                  dt.year, dt.mon, dt.day, dt.hour, dt.min);
   
   string filename = "PortfolioMasterConfigs\\PortfolioTest_" + timestamp + ".txt";
   
   int fileHandle = FileOpen(filename, FILE_WRITE|FILE_COMMON|FILE_TXT);
   if(fileHandle == INVALID_HANDLE)
   {
      Logger::Error("❌ ERROR: Cannot create configuration file: " + filename);
      return;
   }
   
   string content = "";
   content += "=== PORTFOLIO MASTER TEST RESULTS ===\n";
   content += "Test Date: " + TimeToString(currentTime) + "\n";
   content += "\n";
   content += "PORTFOLIO COMPOSITION:\n";
   content += "Symbols: " + InpSymbolsList + "\n";
   content += "Total Symbols: " + IntegerToString(totalSymbolsGlobal) + "\n";
   
   if(InpGlobalRiskPercent > 0)
   {
      content += "Global Risk: " + DoubleToString(InpGlobalRiskPercent, 2) + "% (total)\n";
      content += "Risk per Symbol: " + DoubleToString(InpGlobalRiskPercent / totalSymbolsGlobal, 2) + "%\n";
   }
   else
   {
      content += "Risk Management: Individual per symbol\n";
   }
   
   content += "\n";
   content += "GLOBAL RESULTS:\n";
   content += "Initial Balance: $" + DoubleToString(g_stats.initialBalance, 2) + "\n";
   content += "Final Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   content += "Total Profit: $" + DoubleToString(totalProfit, 2) + " (" + DoubleToString(profitPercent, 2) + "%)\n";
   content += "Max Drawdown: " + DoubleToString(maxDrawdownPct, 2) + "%\n";
   content += "Peak Balance: $" + DoubleToString(g_stats.peakBalance, 2) + "\n";
   content += "Rating: " + GetPerformanceRating(profitPercent, maxDrawdownPct) + "\n";
   
   content += "\n";
   content += "PER-SYMBOL BREAKDOWN:\n";
  // for(int i = 0; i < totalSymbols; i++)
  // {
  //    if(bots[i] != NULL)
  //    {
  //       string symbol = symbols[i];
  //       double profit = bots[i].GetTotalProfit();
  //       int positions = bots[i].GetTotalPositions();
  //       
  //       content += symbol + ": P/L=$" + DoubleToString(profit, 2) + " | Positions:" + IntegerToString(positions) + "\n";
  //    }
  // }
   
   content += "\n";
   content += "====================================\n";
   
   FileWriteString(fileHandle, content);
   FileClose(fileHandle);
   
   Logger::Success("✅ Test configuration saved: " + filename);
}

//+------------------------------------------------------------------+