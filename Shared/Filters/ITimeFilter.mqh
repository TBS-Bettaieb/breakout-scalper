//+------------------------------------------------------------------+
//|                             ITimeFilter.mqh                      |
//|                 Base interface for all time filters              |
//+------------------------------------------------------------------+
#property strict

class ITimeFilter
{
public:
   virtual ~ITimeFilter() {}
   virtual bool IsTradingAllowed() = 0;
   virtual string GetStatusMessage() const { return ""; }
   virtual string GetDescription() const { return "Filter"; }
   virtual bool IsEnabled() const = 0;

protected:
   string m_logPrefix;
   bool m_lastLoggedState;
   datetime m_lastLogTime;
   
   ITimeFilter()
   {
      m_logPrefix = "";
      m_lastLoggedState = true;
      m_lastLogTime = 0;
   }
   
   void LogIfChanged(bool currentState, string message)
   {
      if(currentState != m_lastLoggedState || TimeGMT() - m_lastLogTime > 300)
      {
         if(m_logPrefix != "") Print(m_logPrefix + message);
         m_lastLoggedState = currentState;
         m_lastLogTime = TimeGMT();
      }
   }
};


