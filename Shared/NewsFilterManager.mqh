//+------------------------------------------------------------------+
//|                                           NewsFilterManager.mqh  |
//|                                    News Filter for Trading Bots  |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "TradingEnums.mqh"

//+------------------------------------------------------------------+
//| News Filter Manager Class                                       |
//+------------------------------------------------------------------+
class NewsFilterManager
{
private:
   bool              m_enabled;
   string            m_currencies;        // Ex: "USD,EUR,GBP"
   string            m_keyNews;           // Ex: "NFP,JOLTS,PMI"
   int               m_stopBeforeMin;     // Minutes avant news
   int               m_startAfterMin;     // Minutes après news
   int               m_daysLookup;        // Jours à vérifier
   ENUM_SEPARATOR    m_separator;         // COMMA ou SEMICOLON
   
   bool              m_isBlocked;
   datetime          m_lastNewsTime;
   string            m_blockMessage;
   string            m_newsToAvoid[];
   bool              m_previousBlockedState;

public:
   //--- Constructor
   NewsFilterManager()
   {
      m_enabled = false;
      m_currencies = "";
      m_keyNews = "";
      m_stopBeforeMin = 30;
      m_startAfterMin = 10;
      m_daysLookup = 7;
      m_separator = COMMA;
      m_isBlocked = false;
      m_lastNewsTime = 0;
      m_blockMessage = "";
      m_previousBlockedState = false;
   }
   
   //--- Initialize with parameters
   void Initialize(bool enabled, string currencies, string keyNews, 
                   int stopBefore, int startAfter, int daysLookup, 
                   ENUM_SEPARATOR sep)
   {
      m_enabled = enabled;
      m_currencies = currencies;
      m_keyNews = keyNews;
      m_stopBeforeMin = stopBefore;
      m_startAfterMin = startAfter;
      m_daysLookup = daysLookup;
      m_separator = sep;
      m_isBlocked = false;
      m_lastNewsTime = 0;
      m_blockMessage = "";
      m_previousBlockedState = false;
      
      // Parse key news into array
      string sep_str = (m_separator == COMMA) ? "," : ";";
      ushort sep_code = StringGetCharacter(sep_str, 0);
      int count = StringSplit(m_keyNews, sep_code, m_newsToAvoid);
      ArrayResize(m_newsToAvoid, count);
   }
   
   //--- Main check function (port from IsUpcomingNews)
   bool IsNewsBlocking()
   {
      if(!m_enabled) return false;
      
      // Check if we're still in the "wait after news" period (like original TrDisabledNews logic)
      if(m_isBlocked && m_lastNewsTime > 0 && 
         TimeCurrent() - m_lastNewsTime < m_startAfterMin * 60)
      {
         m_blockMessage = "Waiting " + IntegerToString(m_startAfterMin) +
                         "min after news before trading";
         return true;
      }
      
      // Reset blocked state (like original TrDisabledNews = false)
      m_isBlocked = false;
      
      // Parse news keywords if not already done
      if(ArraySize(m_newsToAvoid) <= 0)
      {
         string sep_str = (m_separator == COMMA) ? "," : ";";
         ushort sep_code = StringGetCharacter(sep_str, 0);
         int count = StringSplit(m_keyNews, sep_code, m_newsToAvoid);
         ArrayResize(m_newsToAvoid, count);
      }
      
      if(ArraySize(m_newsToAvoid) <= 0) return false;
      
      // Get calendar events
      MqlCalendarValue values[];
      datetime starttime = TimeCurrent();
      datetime endtime = starttime + 86400 * m_daysLookup;
      
      if(!CalendarValueHistory(values, starttime, endtime)) 
         return false;
      
      // Check each calendar event
      for(int i = 0; i < ArraySize(values); i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event)) continue;
         
         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country)) continue;
         
         // Check if currency matches our filter
         if(StringFind(m_currencies, country.currency) < 0) continue;
         
         // Check if event name matches any of our keywords
         for(int j = 0; j < ArraySize(m_newsToAvoid); j++)
         {
            if(StringFind(event.name, m_newsToAvoid[j]) >= 0)
            {
               datetime newsTime = values[i].time;
               int secondsBefore = m_stopBeforeMin * 60;
               
               // Check if news is within our "stop before" window
               if(newsTime - TimeCurrent() < secondsBefore)
               {
                  m_lastNewsTime = newsTime;
                  m_isBlocked = true;
                  m_blockMessage = "Trading disabled: " + country.currency +
                                  " " + event.name + " at " +
                                  TimeToString(newsTime, TIME_MINUTES);
                  return true;
               }
            }
         }
      }
      
      return false;
   }
   
   //--- Get current status message
   string GetStatusMessage()
   {
      return m_blockMessage;
   }
   
   //--- Check if status changed (for alerts)
   bool HasStatusChanged()
   {
      bool currentState = IsNewsBlocking();
      bool hasChanged = (currentState != m_previousBlockedState);
      m_previousBlockedState = currentState;
      return hasChanged;
   }
   
   //--- Get detailed info
   string GetDetailedInfo()
   {
      if(!m_enabled)
         return "📰 NEWS FILTER: Disabled";
      
      return StringFormat("📰 NEWS FILTER: Enabled | Currencies: %s | Events: %s | Stop: %dmin | Resume: %dmin", 
                         m_currencies, m_keyNews, m_stopBeforeMin, m_startAfterMin);
   }
   
   //--- Check if currently in blocked state
   bool IsCurrentlyBlocked()
   {
      return m_isBlocked;
   }
};
//+------------------------------------------------------------------+
