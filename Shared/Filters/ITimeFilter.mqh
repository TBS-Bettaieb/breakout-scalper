//+------------------------------------------------------------------+
//|                             ITimeFilter.mqh                      |
//|                 Base interface for all time filters              |
//+------------------------------------------------------------------+
#property strict

class ITimeFilter
{
public:
   virtual ~ITimeFilter() {}

   // Main method - must be implemented
   virtual bool IsTradingAllowed() = 0;

   // Common methods with defaults
   virtual string GetStatusMessage() const { return ""; }
   virtual string GetDescription() const { return "Filter"; }
   virtual bool IsEnabled() const = 0;

   // Configuration logging
   virtual void SetLogPrefix(string prefix) { m_logPrefix = prefix; }

protected:
   string   m_logPrefix;
   bool     m_lastLoggedState;
   datetime m_lastLogTime;

   // Anti-spam logging helper
   void LogIfChanged(bool currentState, string message)
   {
      if(currentState != m_lastLoggedState || TimeGMT() - m_lastLogTime > 300)
      {
         Print(m_logPrefix + message);
         m_lastLoggedState = currentState;
         m_lastLogTime = TimeGMT();
      }
   }
};


