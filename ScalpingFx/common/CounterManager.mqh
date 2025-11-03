#property strict
#include <Trade\PositionInfo.mqh> 
#include <Trade\OrderInfo.mqh> 
#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/Logger.mqh"
class CounterManager
{
private:
   string m_symbol;
   int    m_magic;
   int    m_buyTotal;
   int    m_sellTotal;
   
   int    m_buyTotalPendingStop;
   int    m_sellTotalPendingStop;
   int    m_buyTotalPendingLimit;
   int    m_sellTotalPendingLimit;

      // Statistiques
    double            m_totalProfit;         // Profit total pour ce symbole
   CPositionInfo m_position;

public:
   void Init(const string symbol, const int magic, CPositionInfo &position)
   {
      m_symbol    = symbol;
      m_magic     = magic;
      m_position  = position;

      Reset();

   }

   void Reset()
   {
      m_buyTotal  = 0;
      m_sellTotal = 0;
      m_buyTotalPendingStop = 0;
      m_sellTotalPendingStop = 0;
      m_buyTotalPendingLimit = 0;
      m_sellTotalPendingLimit = 0;
      m_totalProfit = 0;
   }

   void Recalculate()
   {
    m_buyTotal = 0;
    m_sellTotal = 0;
    m_buyTotalPendingStop = 0;
    m_sellTotalPendingStop = 0;
    m_buyTotalPendingLimit = 0;
    m_sellTotalPendingLimit = 0;
    // Compter les positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
       if(m_position.SelectByIndex(i))
       {
          if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magic)
          {
             if(m_position.PositionType() == POSITION_TYPE_BUY) m_buyTotal++;
             if(m_position.PositionType() == POSITION_TYPE_SELL) m_sellTotal++;
          }
       }
    }
    
    // Compter les ordres en attente
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
       ulong ticket = OrderGetTicket(i);
       if(OrderSelect(ticket))
       {
          if(OrderGetString(ORDER_SYMBOL) == m_symbol && OrderGetInteger(ORDER_MAGIC) == m_magic)
          {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) m_buyTotalPendingStop++;
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP) m_sellTotalPendingStop++;
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT) m_buyTotalPendingLimit++;
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT) m_sellTotalPendingLimit++;
          }
       }
    }
   }

   int GetBuy()  { return m_buyTotal; }
   int GetSell() { return m_sellTotal; }
   int GetTotalPositions() { return m_buyTotal + m_sellTotal; }
   int GetTotalPendingStop() { return m_buyTotalPendingStop + m_sellTotalPendingStop; }
   int GetTotalPendingLimit() { return m_buyTotalPendingLimit + m_sellTotalPendingLimit; }
   int GetBuyPendingStop() { return m_buyTotalPendingStop; }
   int GetSellPendingStop() { return m_sellTotalPendingStop; }
   int GetBuyPendingLimit() { return m_buyTotalPendingLimit; }
   int GetSellPendingLimit() { return m_sellTotalPendingLimit; }

   // Méthodes booléennes pour vérifier si un ordre peut être envoyé
   bool CanSendBuyLimitOrder() { return (m_buyTotalPendingLimit <= 0); }
   bool CanSendSellLimitOrder() { return (m_sellTotalPendingLimit <= 0); }

   bool CanSendBuyStopOrder()  { return (m_buyTotalPendingStop+m_sellTotalPendingLimit <= 0); }
   bool CanSendSellStopOrder()  { return (m_sellTotalPendingStop +m_buyTotalPendingLimit <= 0); }
   
   void DisplayCounters(const long chart_id = 0, const string name = "CounterInfo", const int corner = CORNER_LEFT_UPPER)
   {
      string label = name + "_" + m_symbol;
      if(ObjectFind(chart_id, label) < 0)
      {
         ObjectCreate(chart_id, label, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(chart_id, label, OBJPROP_CORNER, corner);
         ObjectSetInteger(chart_id, label, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(chart_id, label, OBJPROP_YDISTANCE, 40);
         ObjectSetInteger(chart_id, label, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(chart_id, label, OBJPROP_FONTSIZE, 9);
      }
      string text = StringFormat("%s | BUY: %d | SELL: %d | BUY STOP: %d | SELL STOP: %d | BUY LIMIT: %d | SELL LIMIT: %d", m_symbol, m_buyTotal, m_sellTotal, m_buyTotalPendingStop, m_sellTotalPendingStop, m_buyTotalPendingLimit, m_sellTotalPendingLimit);
      ObjectSetString(chart_id, label, OBJPROP_TEXT, text);
   }



   string GetStatusInfo()
   {
      string status = m_symbol + ": ";
      
      if(m_buyTotal + m_sellTotal == 0)
         status += "IDLE";
      else
      {
         status += "ACTIVE | Pos: " + IntegerToString(m_buyTotal + m_sellTotal);
         status += " (B:" + IntegerToString(m_buyTotal) + " S:" + IntegerToString(m_sellTotal) + ")";
         
         if(m_totalProfit != 0)
         {
            status += " | P/L: " + DoubleToString(m_totalProfit, 2);
         }
      }
      
      return status;
   }



   double GetTotalProfit()
   {
      m_totalProfit = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol)
            {
               m_totalProfit += m_position.Profit() + m_position.Swap() + m_position.Commission();
            }
         }
      }
      
      return m_totalProfit;
   }
};


