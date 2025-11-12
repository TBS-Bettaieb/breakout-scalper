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
   bool              m_firstCheck;

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
      m_firstCheck = true;
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
      m_firstCheck = true;
      
      // Parse key news into array
      string sep_str = (m_separator == COMMA) ? "," : ";";
      ushort sep_code = StringGetCharacter(sep_str, 0);
      int count = StringSplit(m_keyNews, sep_code, m_newsToAvoid);
      ArrayResize(m_newsToAvoid, count);
   }
   
   //--- Main check function (port from IsUpcomingNews)
   bool IsNewsBlocking()
   {
      if(!m_enabled)
         return false;
      
      // Check if we're still in the "wait after news" period (like original TrDisabledNews logic)
      if(m_isBlocked && m_lastNewsTime > 0 && 
         TimeGMT() - m_lastNewsTime < m_startAfterMin * 60)
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
      
      bool hasKeywords = (ArraySize(m_newsToAvoid) > 0);
      
      // Get calendar events
      MqlCalendarValue values[];
      datetime starttime = TimeGMT();
      datetime endtime = starttime + 86400 * m_daysLookup;
      
      if(!CalendarValueHistory(values, starttime, endtime))
      {
         Print("[NewsFilterManager] ⚠️ Could not retrieve calendar events");
         return false;
      }
      
      // DEBUG: Logger les keywords parsés (seulement si changement d'état ou première fois)
      if(m_firstCheck || m_isBlocked != m_previousBlockedState)
      {
         if(hasKeywords)
         {
            string kwList = "";
            for(int x = 0; x < ArraySize(m_newsToAvoid); x++)
               kwList += "[" + m_newsToAvoid[x] + "] ";
            Print("[NewsFilterManager] 🔍 DEBUG: Parsed ", IntegerToString(ArraySize(m_newsToAvoid)), " keywords: ", kwList);
         }
         else
         {
            Print("[NewsFilterManager] 🔍 DEBUG: No keywords - will block ALL events for currencies: ", m_currencies);
         }
         Print("[NewsFilterManager] 🔍 DEBUG: Checking ", IntegerToString(ArraySize(values)), " calendar events");
         m_firstCheck = false;
      }
      
      // Check each calendar event
      for(int i = 0; i < ArraySize(values); i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event)) continue;
         
         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country)) continue;
         
         // Check if currency matches our filter
         if(StringFind(m_currencies, country.currency) < 0) continue;
         
         datetime newsTime = values[i].time;
         int secondsBefore = m_stopBeforeMin * 60;
         int timeDiff = (int)(newsTime - TimeGMT());
         
         if(timeDiff < 0) continue; // Event already passed
         
         // Si pas de keywords, bloquer tous les événements des devises surveillées
         if(!hasKeywords)
         {
            if(timeDiff < secondsBefore)
            {
               m_lastNewsTime = newsTime;
               m_isBlocked = true;
               m_blockMessage = "Trading disabled (all events): " + country.currency +
                               " " + event.name + " at " +
                               TimeToString(newsTime, TIME_MINUTES);
               Print("[NewsFilterManager] 🚨 BLOCKING TRADING: ", m_blockMessage);
               Print("[NewsFilterManager] 🔍 DEBUG Event (no keywords): ", event.name, 
                     " | Time: ", TimeToString(newsTime), 
                     " | TimeDiff: ", IntegerToString(timeDiff/60), " min",
                     " | Threshold: ", IntegerToString(secondsBefore/60), " min");
               return true;
            }
         }
         else
         {
            // Check if event name matches any of our keywords (case-insensitive)
            for(int j = 0; j < ArraySize(m_newsToAvoid); j++)
            {
               // Matching case-insensitive
               string eventNameUpper = event.name;
               StringToUpper(eventNameUpper);
               string keywordUpper = m_newsToAvoid[j];
               StringToUpper(keywordUpper);
               
               if(StringFind(eventNameUpper, keywordUpper) >= 0)
               {
                  if(timeDiff < secondsBefore)
                  {
                     m_lastNewsTime = newsTime;
                     m_isBlocked = true;
                     m_blockMessage = "Trading disabled: " + country.currency +
                                     " " + event.name + " at " +
                                     TimeToString(newsTime, TIME_MINUTES);
                     Print("[NewsFilterManager] 🚨 BLOCKING TRADING: ", m_blockMessage);
                     Print("[NewsFilterManager] 🔍 DEBUG Event: ", event.name, 
                           " | Time: ", TimeToString(newsTime), 
                           " | TimeDiff: ", IntegerToString(timeDiff/60), " min",
                           " | Threshold: ", IntegerToString(secondsBefore/60), " min");
                     return true;
                  }
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
