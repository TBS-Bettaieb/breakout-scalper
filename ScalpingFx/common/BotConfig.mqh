//+------------------------------------------------------------------+
//|                                                BotConfig.mqh      |
//|                                    Bot Configuration Structure     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/TrailingTP_System.mqh"
#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Configuration structure                                          |
//+------------------------------------------------------------------+
struct BotConfig
{
   string            strategyName;
   string            strategyComment;
   int               baseMagic;
   string            symbolsList;
   bool              useAllSymbols;
   ENUM_TIMEFRAMES   timeframe;
   double            riskPercent;
   double            baseBalance;  // 🆕 Base balance for lot calculation (0 or negative = use account balance)
   int               tpPoints;
   int               slPoints;
   int               tslTriggerPoints;
   int               tslPoints;
   
   // 🆕 Dynamic TSL Parameters
   bool              useDynamicTSLTrigger;  // true = trigger auto basé sur coûts
   double            tslCostMultiplier;     // Multiplicateur (ex: 1.5 = trigger à 150% des coûts)
   int               tslMinTriggerPoints;   // Trigger minimum absolu (sécurité)
   
   int               startHour;
   int               endHour;
   string            tradingTimeRanges;  // Format unifié: "08:30-10:45; 15:30-18:00"
   int               barsN;
   int               expirationBars;
   int               orderDistPoints;
   int               slippagePoints;        // NEW: Slippage tolerance in points
   int               entryOffsetPoints;     // NEW: Entry price offset for Stop orders
   double            priceTolerancePercent; // NEW: Price tolerance percentage for FVG checks
   ENUM_SWING_DETECTION_MODE swingDetectionMode; // Mode de détection swing (WICK ou BODY)
   bool              useTrailingTP;
   ENUM_TRAILING_TP_MODE trailingTPMode;
   string            customTPLevels;
   string            hourBlockMsg;
   string            dayBlockMsg;
   string            bothBlockMsg;
   
   // RISK MULTIPLIER
   bool              useRiskMultiplier;
   int               riskMultStartHour;
   int               riskMultStartMinute;
   int               riskMultEndHour;
   int               riskMultEndMinute;
   double            riskMultiplier;
   string            riskMultDescription;
   string            riskMultTimeRanges;  // Format unifié: "08:30-10:45; 15:30-18:00"
   
   // NEWS FILTER
   bool              useNewsFilter;
   string            newsCurrencies;
   string            keyNewsEvents;
   int               stopBeforeNewsMin;
   int               startAfterNewsMin;
   int               newsLookupDays;
   ENUM_SEPARATOR    newsSeparator;
   string            newsBlockMsg;
   
   // 🆕 FVG FILTER
   bool              useFvgFilter;
   
   // LOGGING
   ENUM_LOG_LEVEL    logLevel;
};
