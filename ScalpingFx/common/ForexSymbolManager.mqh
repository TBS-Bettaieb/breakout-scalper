//+------------------------------------------------------------------+
//|                                        ForexSymbolManager.mqh    |
//|                Gestionnaire de symboles multi-trading Forex     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/TradingUtils.mqh"
#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Afficher les informations sur les symboles configurés           |
//+------------------------------------------------------------------+
void PrintSymbolsInfo(string &symbolArray[], int baseMagic, ENUM_TIMEFRAMES timeframe, string strategyName = "")
{
   int count = ArraySize(symbolArray);
   
   Logger::Info("═══════════════════════════════════════");
   Logger::Info("🔧 FOREX SYMBOLS CONFIGURATION");
   Logger::Info("═══════════════════════════════════════");
   Logger::Info("Total symbols: " + IntegerToString(count));
   Logger::Info("Strategy: " + strategyName);
   Logger::Info("Timeframe: " + EnumToString(timeframe));
   
   for(int i = 0; i < count; i++)
   {
      string symbol = symbolArray[i];
      
      // Informations sur le symbole
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      Logger::Info("  [" + IntegerToString(i+1) + "] " + symbol + " | Magic: " + IntegerToString(baseMagic));
      Logger::Info("      Point: " + DoubleToString(point, 5) + " | Spread: " + DoubleToString(spread, 0));
      Logger::Info("      Lots: " + DoubleToString(minLot, 2) + " - " + DoubleToString(maxLot, 2));
   }
   
   Logger::Info("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Obtenir les statistiques globales des symboles                  |
//+------------------------------------------------------------------+
string GetGlobalSymbolsStatus(string &symbolArray[], ForexSymbolTrader* &traders[])
{
   if(ArraySize(symbolArray) != ArraySize(traders))
      return "ERROR: Array size mismatch";
   
   int symbolCount = ArraySize(symbolArray);
   int activeSymbols = 0;
   int totalPositions = 0;
   double totalProfit = 0;
   
   for(int i = 0; i < symbolCount; i++)
   {
      if(traders[i] != NULL)
      {
         int positions = traders[i].GetTotalPositions();
         double profit = traders[i].GetTotalProfit();
         
         if(positions > 0) activeSymbols++;
         totalPositions += positions;
         totalProfit += profit;
      }
   }
   
   string status = "FOREX GLOBAL: ";
   status += "Symbols: " + IntegerToString(activeSymbols) + "/" + IntegerToString(symbolCount);
   status += " | Positions: " + IntegerToString(totalPositions);
   
   if(totalProfit != 0)
   {
      status += " | P/L: " + DoubleToString(totalProfit, 2);
   }
   
   return status;
}
