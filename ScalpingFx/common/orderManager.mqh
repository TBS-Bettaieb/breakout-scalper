//+------------------------------------------------------------------+
//|                                                  orderManager.mqh |
//|                         Order management (calc lots, send orders) |
//|                                      (c) 2025 - Public Domain     |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Order parameter bundle                                           |
//+------------------------------------------------------------------+
struct OrderParams
{
   string            symbol;
   ENUM_TIMEFRAMES   timeframe; 
   int               magicNumber;
   double            point;
   int               tpPoints;
   int               slPoints;
   int               entryOffsetPoints;
   int               orderDistPoints;
   int               expirationBars;
   double            riskPercent;
   double            currentRiskMultiplier;
   string            tradeComment;
   CTrade           *trade; // pointer for compatibility with MQL5 passing
};

//+------------------------------------------------------------------+
//| Order manager with static helpers                                |
//+------------------------------------------------------------------+
class OrderManager
{
public:
   // Factory to create parameters
   static OrderParams CreateParams(const string symbol,
                                   const ENUM_TIMEFRAMES timeframe,
											  const	int magicNumber,
                                   const double point,
                                   const int tpPoints,
                                   const int slPoints,
                                   const int entryOffsetPoints,
                                   const int orderDistPoints,
                                   const int expirationBars,
                                   const double riskPercent,
                                   const double currentRiskMultiplier,
                                   const string tradeComment,
                                   CTrade &trade)
   {
      OrderParams p;
      p.symbol = symbol;
      p.timeframe = timeframe;
		p.magicNumber=magicNumber;
      p.point = point;
      p.tpPoints = tpPoints;
      p.slPoints = slPoints;
      p.entryOffsetPoints = entryOffsetPoints;
      p.orderDistPoints = orderDistPoints;
      p.expirationBars = expirationBars;
      p.riskPercent = riskPercent;
      p.currentRiskMultiplier = currentRiskMultiplier;
      p.tradeComment = tradeComment;
      p.trade = &trade;
      return p;
   }


   //+------------------------------------------------------------------+
   //| Envoyer un ordre Limit (délègue aux variantes BUY/SELL)         |
   //+------------------------------------------------------------------+
   static bool SendLimitOrder(const OrderParams &params, bool isBuy, double entry, const string tradeCommentSuffix = "")
   {
      return isBuy ? SendBuyLimitOrder(params, entry, tradeCommentSuffix) : SendSellLimitOrder(params, entry, tradeCommentSuffix);
   }

   //+------------------------------------------------------------------+
   //| Envoyer un ordre Buy Limit                                       |
   //+------------------------------------------------------------------+
   static bool SendBuyLimitOrder(const OrderParams &params, double entry, const string tradeCommentSuffix = "")
   {
      // Calculer TP et SL avec offset (pour Buy Limit: entry est en dessous du prix actuel)
      double adjustedEntry = entry - (params.entryOffsetPoints * params.point);
      double adjustedTP = adjustedEntry + params.tpPoints * params.point;
      double adjustedSL = adjustedEntry - params.slPoints * params.point;

      datetime expiration = iTime(params.symbol, params.timeframe, 0) + params.expirationBars * PeriodSeconds(params.timeframe);

      double lots = 0.01;
      if(params.riskPercent > 0.0)
         lots = CalcLots(params, adjustedEntry - adjustedSL);

      string comment = params.tradeComment;
      if(tradeCommentSuffix != "")
         comment = params.tradeComment + "_" + tradeCommentSuffix;

      if(params.trade.BuyLimit(lots, adjustedEntry, params.symbol, adjustedSL, adjustedTP, ORDER_TIME_SPECIFIED, expiration, comment))
      {
         Print("✓ Buy Limit order sent for ", params.symbol, " at ", adjustedEntry, " | Lots: ", lots);
         return true;
      }
      else
      {
         Print("✗ Failed to send Buy Limit order for ", params.symbol, " | Error: ", GetLastError());
         return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Envoyer un ordre Sell Limit                                      |
   //+------------------------------------------------------------------+
   static bool SendSellLimitOrder(const OrderParams &params, double entry, const string tradeCommentSuffix = "")
   {
      // Calculer TP et SL avec offset (pour Sell Limit: entry est au-dessus du prix actuel)
      double adjustedEntry = entry + (params.entryOffsetPoints * params.point);
      double adjustedTP = adjustedEntry - params.tpPoints * params.point;
      double adjustedSL = adjustedEntry + params.slPoints * params.point;

      datetime expiration = iTime(params.symbol, params.timeframe, 0) + params.expirationBars * PeriodSeconds(params.timeframe);

      double lots = 0.01;
      if(params.riskPercent > 0.0)
         lots = CalcLots(params, adjustedSL - adjustedEntry);

      string comment = params.tradeComment;
      if(tradeCommentSuffix != "")
         comment = params.tradeComment + "_" + tradeCommentSuffix;

      if(params.trade.SellLimit(lots, adjustedEntry, params.symbol, adjustedSL, adjustedTP, ORDER_TIME_SPECIFIED, expiration, comment))
      {
         Print("✓ Sell Limit order sent for ", params.symbol, " at ", adjustedEntry, " | Lots: ", lots);
         return true;
      }
      else
      {
         Print("✗ Failed to send Sell Limit order for ", params.symbol, " | Error: ", GetLastError());
         return false;
      }
   }
  
   // Calculate lot size based on risk
   static double CalcLots(const OrderParams &params, const double slPoints)
   {
      double effectiveRisk = params.riskPercent * params.currentRiskMultiplier;
      double risk = AccountInfoDouble(ACCOUNT_BALANCE) * effectiveRisk / 100.0;

      double ticksize = SymbolInfoDouble(params.symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickvalue = SymbolInfoDouble(params.symbol, SYMBOL_TRADE_TICK_VALUE);
      double lotstep = SymbolInfoDouble(params.symbol, SYMBOL_VOLUME_STEP);
      double maxvolume = SymbolInfoDouble(params.symbol, SYMBOL_VOLUME_MAX);
      double minvolume = SymbolInfoDouble(params.symbol, SYMBOL_VOLUME_MIN);
      double volumelimit = SymbolInfoDouble(params.symbol, SYMBOL_VOLUME_LIMIT);

      double moneyPerLotstep = (slPoints / ticksize) * tickvalue * lotstep;
      if(moneyPerLotstep <= 0.0) return 0.0;

      double lots = MathFloor(risk / moneyPerLotstep) * lotstep;

      if(volumelimit != 0.0) lots = MathMin(lots, volumelimit);
      if(maxvolume != 0.0)   lots = MathMin(lots, maxvolume);
      if(minvolume != 0.0)   lots = MathMax(lots, minvolume);
      lots = NormalizeDouble(lots, 2);

      return lots;
   }

   // Send Buy (Stop) order with same logic as original
   static void SendBuyOrder(const OrderParams &params, const double entry)
   {
      double ask = SymbolInfoDouble(params.symbol, SYMBOL_ASK);
      double lots = 0.01;
      // BREAKOUT: BuyStop (wait for breakout)
      double adjustedEntry = entry - (params.entryOffsetPoints * params.point);
      double adjustedTP = adjustedEntry + params.tpPoints * params.point;
      double adjustedSL = adjustedEntry - params.slPoints * params.point;

      if(params.riskPercent > 0.0) lots = CalcLots(params, adjustedEntry - adjustedSL);

      datetime expiration = iTime(params.symbol, params.timeframe, 0) + params.expirationBars * PeriodSeconds(params.timeframe);


      if(ask > adjustedEntry - params.orderDistPoints * params.point) return;

      if(params.trade.BuyStop(lots, adjustedEntry, params.symbol, adjustedSL, adjustedTP,
                              ORDER_TIME_SPECIFIED, expiration, params.tradeComment))
      {
         Print("✓ Buy Stop order sent for ", params.symbol, " at ", adjustedEntry,
               " (offset: ", params.entryOffsetPoints, " pts) | Lots: ", lots);
      }
      else
      {
         Print("✗ Failed to send Buy Stop order for ", params.symbol, " | Error: ", GetLastError());
      }
   }

   // Send Sell (Stop) order with same logic as original
   static void SendSellOrder(const OrderParams &params, const double entry)
   {
      double bid = SymbolInfoDouble(params.symbol, SYMBOL_BID);
      double lots = 0.01;
      // BREAKOUT: SellStop (wait for breakout)
      double adjustedEntryS = entry + (params.entryOffsetPoints * params.point);
      double adjustedTPS = adjustedEntryS - params.tpPoints * params.point;
      double adjustedSLS = adjustedEntryS + params.slPoints * params.point;

      if(params.riskPercent > 0.0) lots = CalcLots(params, adjustedSLS - adjustedEntryS);


      datetime expiration = iTime(params.symbol, params.timeframe, 0) + params.expirationBars * PeriodSeconds(params.timeframe);

      

      if(bid < adjustedEntryS + params.orderDistPoints * params.point) return;

      if(params.trade.SellStop(lots, adjustedEntryS, params.symbol, adjustedSLS, adjustedTPS,
                               ORDER_TIME_SPECIFIED, expiration, params.tradeComment))
      {
         Print("✓ Sell Stop order sent for ", params.symbol, " at ", adjustedEntryS,
               " (offset: ", params.entryOffsetPoints, " pts) | Lots: ", lots);
      }
      else
      {
         Print("✗ Failed to send Sell Stop order for ", params.symbol, " | Error: ", GetLastError());
      }
   }

   // Cancel a pending order by ticket for given symbol/magic
   static bool CancelOrderById(const OrderParams &params, const ulong ticket)
   {
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == params.magicNumber && OrderGetString(ORDER_SYMBOL) == params.symbol)
         {
            if(params.trade.OrderDelete(ticket))
            {
               Print("✓ Ordre #", ticket, " annulé pour ", params.symbol);
               return true;
            }
            else
            {
               Print("✗ Échec de l'annulation de l'ordre #", ticket, " | Erreur: ", GetLastError());
               return false;
            }
         }
         else
         {
            Print("✗ Ticket #", ticket, " ne correspond pas au symbole ou au magic number.");
            return false;
         }
      }
      else
      {
         Print("✗ Impossible de sélectionner l'ordre #", ticket, " pour annulation.");
         return false;
      }
   }
};


