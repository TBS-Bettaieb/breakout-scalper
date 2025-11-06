//+------------------------------------------------------------------+
//|                                               NewsFilter.mqh     |
//|                   Filtre par actualités économiques pour le trading |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Dans votre fichier .mq5 principal, ajoutez ces inputs :       |
//|    input group "=== News Filter ==="                             |
//|    input bool NewsFilterOn = false;                              |
//|    input string NewsCurrencies = "USD,EUR,GBP";                 |
//|    input string KeyNews = "NFP,JOLTS,Nonfarm,PMI,Interest Rate"; |
//|    input int StopBeforeMin = 30;                                 |
//|    input int StartTradingMin = 10;                               |
//|    input int DaysNewsLookup = 7;                                 |
//|    input ENUM_NEWS_SEPARATOR NewsSeparator = NEWS_COMMA;         |
//|                                                                   |
//| 2. Incluez ce fichier : #include "../Shared/NewsFilter.mqh"       |
//|                                                                   |
//| 3. Utilisez les fonctions :                                       |
//|    - IsNewsAllowed() : utilise NewsFilterOn/NewsCurrencies/KeyNews/etc |
//|    - IsNewsAllowed(currencies, keywords, stopBefore, startAfter, days, separator) : paramètres explicites |
//|    - CheckUpcomingNews() : vérification directe des actualités   |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - NewsCurrencies="USD,EUR" : surveiller USD et EUR               |
//| - KeyNews="NFP,PMI,Interest Rate" : actualités importantes       |
//| - StopBeforeMin=30 : arrêter 30 min avant l'actualité           |
//| - StartTradingMin=10 : reprendre 10 min après l'actualité       |
//+------------------------------------------------------------------+
#property strict
// New architecture include
#include "ITimeFilter.mqh"

//+------------------------------------------------------------------+
//| Énumération des séparateurs de liste                             |
//+------------------------------------------------------------------+
enum ENUM_NEWS_SEPARATOR
{
   NEWS_COMMA = 0,      // Comma (,)
   NEWS_SEMICOLON = 1   // Semicolon (;)
};

//---------------------------- Inputs (reusable) ---------------------
// ATTENTION DEVELOPPEUR : Pour utiliser ce NewsFilter dans votre EA, 
// vous devez AJOUTER ces inputs dans votre fichier .mq5 principal :
//
// input group "=== News Filter ==="
// input bool NewsFilterOn = false;                              // Activer filtre actualités
// input string NewsCurrencies = "USD,EUR,GBP";                 // Devises à surveiller
// input string KeyNews = "NFP,JOLTS,Nonfarm,PMI,Interest Rate"; // Actualités importantes
// input int StopBeforeMin = 30;                                // Minutes avant actualité
// input int StartTradingMin = 10;                              // Minutes après actualité
// input int DaysNewsLookup = 7;                                // Jours à vérifier
// input ENUM_NEWS_SEPARATOR NewsSeparator = NEWS_COMMA;        // Séparateur de liste
//
// Ces inputs ne peuvent PAS être définis dans un fichier .mqh (include)
// Ils doivent être dans le fichier .mq5 principal de votre EA.
//
// Exemple d'utilisation dans votre EA :
// 1. Ajoutez les inputs ci-dessus dans votre .mq5
// 2. Incluez ce fichier : #include "../Shared/NewsFilter.mqh"
// 3. Utilisez les fonctions : IsNewsAllowed(), CheckUpcomingNews(), etc.
//
// Ces variables sont commentées ici car elles causeraient des erreurs de compilation
// si définies dans un fichier include (.mqh)
// input group "=== News Filter ==="
// input bool NewsFilterOn = false;                              // Activer filtre actualités
// input string NewsCurrencies = "USD,EUR,GBP";                 // Devises à surveiller
// input string KeyNews = "NFP,JOLTS,Nonfarm,PMI,Interest Rate"; // Actualités importantes
// input int StopBeforeMin = 30;                                // Minutes avant actualité
// input int StartTradingMin = 10;                              // Minutes après actualité
// input int DaysNewsLookup = 7;                                // Jours à vérifier
// input ENUM_NEWS_SEPARATOR NewsSeparator = NEWS_COMMA;        // Séparateur de liste

//+------------------------------------------------------------------+
//| Fonction helper globale pour vérifier les actualités à venir    |
//+------------------------------------------------------------------+
bool CheckUpcomingNews(
   string currencies,
   string keywords,
   int stopBeforeMin,
   int startTradingMin,
   int daysLookup,
   ENUM_NEWS_SEPARATOR separator
)
{
   // Parser les keywords
   string sep = (separator == NEWS_COMMA) ? "," : ";";
   ushort sep_code = StringGetCharacter(sep, 0);
   
   string newsToAvoid[];
   int k = StringSplit(keywords, sep_code, newsToAvoid);
   if(k <= 0) return false;
   
   // Récupérer le calendrier économique
   MqlCalendarValue values[];
   datetime starttime = TimeGMT();
   datetime endtime = starttime + 86400 * daysLookup;
   
   if(!CalendarValueHistory(values, starttime, endtime)) 
      return false;
   
   // Parcourir les événements
   for(int i = 0; i < ArraySize(values); i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event)) 
         continue;
      
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country)) 
         continue;
      
      // Vérifier si la devise nous intéresse
      if(StringFind(currencies, country.currency) < 0) 
         continue;
      
      // Vérifier si c'est une actualité clé
      for(int j = 0; j < k; j++)
      {
         if(StringFind(event.name, newsToAvoid[j]) >= 0)
         {
            datetime newsTime = values[i].time;
            int secondsBefore = stopBeforeMin * 60;
            
            if(newsTime - TimeGMT() < secondsBefore)
            {
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Fonction principale de vérification par actualités              |
//| IMPORTANT: Cette fonction utilise les variables NewsFilterOn    |
//| NewsCurrencies, KeyNews, StopBeforeMin, StartTradingMin,        |
//| DaysNewsLookup et NewsSeparator qui doivent être définies       |
//| dans le fichier .mq5                                            |
//+------------------------------------------------------------------+
/*
bool IsNewsAllowed()
{
   // Si le filtre est désactivé, autoriser le trading
   if(!NewsFilterOn) return true;
   
   return !CheckUpcomingNews(NewsCurrencies, KeyNews, StopBeforeMin, 
                            StartTradingMin, DaysNewsLookup, NewsSeparator);
}
*/

//+------------------------------------------------------------------+
//| Fonction alternative avec paramètres explicites                 |
//| Utilisez cette fonction si vous préférez passer les paramètres  |
//| directement plutôt que d'utiliser les inputs globaux            |
//+------------------------------------------------------------------+
bool IsNewsAllowed(
   string currencies,
   string keywords, 
   int stopBefore,
   int startAfter,
   int daysLookup,
   ENUM_NEWS_SEPARATOR separator
)
{
   return !CheckUpcomingNews(currencies, keywords, stopBefore, 
                            startAfter, daysLookup, separator);
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres par actualités                    |
//+------------------------------------------------------------------+
class NewsFilter : public ITimeFilter
{
private:
   // Configuration
   bool                    m_useFilter;
   string                  m_currencies;       // "USD,EUR,GBP"
   string                  m_keywords;         // "NFP,JOLTS,..."
   int                     m_stopBeforeMin;
   int                     m_startTradingMin;
   int                     m_daysLookup;
   ENUM_NEWS_SEPARATOR     m_separator;
   
   // État
   bool                    m_tradingDisabledNews;
   datetime                m_lastNewsAvoided;
   string                  m_lastNewsMessage;
   string                  m_newsToAvoid[];
   
   // Logging
   string                  m_lastBlockReason;

   // Mode CSV (tester)
   bool                    m_useCSV;           // Utiliser CSV en mode Strategy Tester
   string                  m_csvFileName;      // Nom du fichier CSV
   bool                    m_csvLoaded;        // CSV chargé avec succès

   // Événements issus du CSV
   struct NewsEvent
   {
      datetime time;
      string   currency;
      string   eventName;
      string   impact;
   };
   NewsEvent               m_newsEvents[];

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   NewsFilter()
   {
      m_useFilter = false;
      m_currencies = "";
      m_keywords = "";
      m_stopBeforeMin = 30;
      m_startTradingMin = 10;
      m_daysLookup = 7;
      m_separator = NEWS_COMMA;
      m_tradingDisabledNews = false;
      m_lastNewsAvoided = 0;
      m_lastNewsMessage = "";
      m_lastLogTime = 0;
      m_logPrefix = "[NewsFilter] ";
      m_lastLoggedState = true;
      m_lastLogTime = 0;
      m_lastBlockReason = "";

      // CSV defaults and auto-detect tester mode
      m_useCSV = (bool)MQLInfoInteger(MQL_TESTER);
      m_csvFileName = "NewsCalendar_Optimized.csv";
      m_csvLoaded = false;
      ArrayResize(m_newsEvents, 0);
   }

   //+------------------------------------------------------------------+
   //| NOUVELLE MÉTHODE: Initialize pour cohérence avec autres filtres |
   //+------------------------------------------------------------------+
   bool Initialize(
      bool enabled,
      string currencies,
      string keywords,
      int stopBeforeMin,
      int startTradingMin,
      int daysLookup,
      ENUM_NEWS_SEPARATOR separator,
      string csvFileName = "NewsCalendar_Optimized.csv"
   )
   {
      m_useFilter = enabled;
      m_currencies = currencies;
      m_keywords = keywords;
      m_stopBeforeMin = stopBeforeMin;
      m_startTradingMin = startTradingMin;
      m_daysLookup = daysLookup;
      m_separator = separator;
      m_csvFileName = csvFileName;
      
      if(!enabled)
      {
         Print(m_logPrefix + "NewsFilter is DISABLED");
         return true;
      }

      // Auto-detect execution mode
      m_useCSV = (bool)MQLInfoInteger(MQL_TESTER);

      if(m_useCSV)
      {
         Print(m_logPrefix + "\xF0\x9F\x93\x8A TESTER MODE: Using CSV file: " + m_csvFileName);
         if(!LoadNewsFromCSV())
         {
            Print(m_logPrefix + "\xE2\x9A\xA0\xEF\xB8\x8F WARNING: Could not load CSV. NewsFilter inactive in backtest.");
            return false;
         }
         Print(m_logPrefix + "\xE2\x9C\x85 Loaded " + IntegerToString(ArraySize(m_newsEvents)) + " events from CSV");
      }
      else
      {
         Print(m_logPrefix + "\xF0\x9F\x94\xB4 LIVE MODE: Using Calendar API");
      }

      if(currencies != "" && keywords != "")
      {
         Print(m_logPrefix + "Initialized with currencies: " + currencies + 
               ", keywords: " + keywords + 
               ", stopBefore: " + IntegerToString(stopBeforeMin) + " min");
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void InitFromInputs(
      bool useFilter,
      string currencies,
      string keywords,
      int stopBefore,
      int startAfter,
      int daysLookup,
      ENUM_NEWS_SEPARATOR separator
   )
   {
      m_useFilter = useFilter;
      m_currencies = currencies;
      m_keywords = keywords;
      m_stopBeforeMin = stopBefore;
      m_startTradingMin = startAfter;
      m_daysLookup = daysLookup;
      m_separator = separator;
   }

   void SetLogPrefix(string prefix) { m_logPrefix = prefix; }

   //+------------------------------------------------------------------+
   //| Vérifications principales                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed() override
   {
      if(!m_useFilter) return true;

      // Vérifier si on attend après une actualité
      if(m_tradingDisabledNews && 
         TimeGMT() - m_lastNewsAvoided < m_startTradingMin * 60)
      {
         // Logging anti-spam
         if(TimeGMT() - m_lastLogTime >= 60)
         {
            LogIfChanged(false, StringFormat("Waiting %d min after news before resuming", m_startTradingMin));
            m_lastLogTime = TimeGMT();
            m_lastBlockReason = "Waiting after news event";
         }
         return false;
      }

      // Vérifier les actualités à venir
      bool hasUpcomingNews = CheckUpcomingNewsEvents();
      
      if(hasUpcomingNews)
      {
         m_lastBlockReason = "Upcoming news event";
         return false;
      }

      m_tradingDisabledNews = false;
      m_lastBlockReason = "";
      return true;
   }

   //+------------------------------------------------------------------+
   //| Helpers publics                                                  |
   //+------------------------------------------------------------------+
   string GetLastNewsMessage() const
   {
      return m_lastNewsMessage;
   }

   string GetLastBlockReason() const
   {
      return m_lastBlockReason;
   }

   string Describe() const
   {
      if(!m_useFilter) return "News filter disabled";
      return "News: " + m_currencies + " | Keywords: " + m_keywords;
   }

   bool IsEnabled() const override
   {
      return m_useFilter;
   }

   virtual string GetDescription() const override
   {
      if(!m_useFilter) return "News: Disabled";
      return "News: " + m_currencies + ", keywords: " + m_keywords;
   }

   virtual string GetStatusMessage() const override
   {
      if(!m_useFilter) return "NewsFilter: OFF";
      return "NewsFilter: ON [" + m_currencies + "]";
   }

   // Obtenir les devises surveillées
   string GetCurrencies() const
   {
      return m_currencies;
   }

   // Obtenir les mots-clés
   string GetKeywords() const
   {
      return m_keywords;
   }

   // Obtenir les minutes d'arrêt avant actualité
   int GetStopBeforeMinutes() const
   {
      return m_stopBeforeMin;
   }

   // Obtenir les minutes d'attente après actualité
   int GetStartTradingMinutes() const
   {
      return m_startTradingMin;
   }

   // Obtenir les jours de recherche
   int GetDaysLookup() const
   {
      return m_daysLookup;
   }

   // NOUVELLES méthodes publiques (CSV)
   string GetCSVFileName() const { return m_csvFileName; }
   bool IsUsingCSV() const { return m_useCSV; }
   void ForceCSVMode(bool useCSV) { m_useCSV = useCSV; m_csvLoaded = false; }
   void SetCSVFile(string fileName) { m_csvFileName = fileName; m_csvLoaded = false; }

private:
   //+------------------------------------------------------------------+
   //| Vérifier les actualités à venir                                |
   //+------------------------------------------------------------------+
   bool CheckUpcomingNewsEvents()
   {
      if(m_useCSV)
         return CheckUpcomingNewsFromCSV();
      return CheckUpcomingNewsFromAPI();
   }

   // Chargement des événements depuis un CSV
   bool LoadNewsFromCSV()
   {
      if(m_csvLoaded)
         return true;

      ArrayResize(m_newsEvents, 0);

      // Essayer Common/Files en priorité
      int fileHandle = FileOpen(m_csvFileName, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         // Fallback: MQL5/Files du terminal
         fileHandle = FileOpen(m_csvFileName, FILE_READ|FILE_CSV|FILE_ANSI, ',');
      }

      if(fileHandle == INVALID_HANDLE)
      {
         Print(m_logPrefix + "❌ ERROR: Could not open CSV file: " + m_csvFileName);
         Print(m_logPrefix + "Expected paths: " +
              TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + m_csvFileName + " OR " +
              TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + m_csvFileName);
         return false;
      }

      // Lire et ignorer l'en-tête
      if(FileIsEnding(fileHandle))
      {
         FileClose(fileHandle);
         return false;
      }
      // Consommer l'en-tête (4 colonnes)
      FileReadString(fileHandle); FileReadString(fileHandle); FileReadString(fileHandle); FileReadString(fileHandle);

      int count = 0;
      while(!FileIsEnding(fileHandle))
      {
         string dateTimeStr = FileReadString(fileHandle);
         string currency = FileReadString(fileHandle);
         string eventName = FileReadString(fileHandle);
         string impact = FileReadString(fileHandle);

         if(dateTimeStr == "")
            break;

         datetime eventTime = StringToTime(dateTimeStr);
         if(eventTime == 0)
         {
            Print(m_logPrefix + "⚠️ Invalid datetime: " + dateTimeStr);
            continue;
         }

         int size = ArraySize(m_newsEvents);
         ArrayResize(m_newsEvents, size + 1);
         m_newsEvents[size].time = eventTime;
         m_newsEvents[size].currency = currency;
         m_newsEvents[size].eventName = eventName;
         m_newsEvents[size].impact = impact;
         count++;
      }

      FileClose(fileHandle);
      m_csvLoaded = true;
      return count > 0;
   }

   // Vérification via CSV
   bool CheckUpcomingNewsFromCSV()
   {
      if(!m_csvLoaded)
         return false;

      string sep = (m_separator == NEWS_COMMA) ? "," : ";";
      ushort sep_code = StringGetCharacter(sep, 0);
      int k = StringSplit(m_keywords, sep_code, m_newsToAvoid);
      if(k <= 0)
         return false;

      datetime currentTime = TimeCurrent();
      int secondsBefore = m_stopBeforeMin * 60;

      for(int i = 0; i < ArraySize(m_newsEvents); i++)
      {
         if(StringFind(m_currencies, m_newsEvents[i].currency) < 0)
            continue;

         int timeDiff = (int)(m_newsEvents[i].time - currentTime);
         if(timeDiff < 0 || timeDiff > m_daysLookup * 86400)
            continue;

         for(int j = 0; j < k; j++)
         {
            if(StringFind(m_newsEvents[i].eventName, m_newsToAvoid[j]) >= 0)
            {
               if(timeDiff < secondsBefore)
               {
                  m_lastNewsAvoided = m_newsEvents[i].time;
                  m_tradingDisabledNews = true;
                  m_lastNewsMessage = m_newsEvents[i].currency + " " +
                                     m_newsEvents[i].eventName + " at " +
                                     TimeToString(m_newsEvents[i].time, TIME_MINUTES);

                  if(TimeCurrent() - m_lastLogTime >= 60)
                  {
                     LogIfChanged(false, "Trading disabled due to news: " + m_lastNewsMessage);
                     m_lastLogTime = TimeCurrent();
                  }
                  return true;
               }
            }
         }
      }
      return false;
   }

   // Vérification via API (ancienne implémentation)
   bool CheckUpcomingNewsFromAPI()
   {
      // Parser les keywords
      string sep = (m_separator == NEWS_COMMA) ? "," : ";";
      ushort sep_code = StringGetCharacter(sep, 0);
      
      int k = StringSplit(m_keywords, sep_code, m_newsToAvoid);
      if(k <= 0) return false;
      
      // Récupérer le calendrier économique
      MqlCalendarValue values[];
      datetime starttime = TimeGMT();
      datetime endtime = starttime + 86400 * m_daysLookup;
      
      if(!CalendarValueHistory(values, starttime, endtime)) 
         return false;
      
      // Parcourir les événements
      for(int i = 0; i < ArraySize(values); i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event)) 
            continue;
         
         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country)) 
            continue;
         
         // Vérifier si la devise nous intéresse
         if(StringFind(m_currencies, country.currency) < 0) 
            continue;
         
         // Vérifier si c'est une actualité clé
         for(int j = 0; j < k; j++)
         {
            if(StringFind(event.name, m_newsToAvoid[j]) >= 0)
            {
               datetime newsTime = values[i].time;
               int secondsBefore = m_stopBeforeMin * 60;
               
               if(newsTime - TimeGMT() < secondsBefore)
               {
                  m_lastNewsAvoided = newsTime;
                  m_tradingDisabledNews = true;
                  m_lastNewsMessage = country.currency + " " + 
                                     event.name + " at " +
                                     TimeToString(newsTime, TIME_MINUTES);
                  
                  // Logging anti-spam
                  if(TimeGMT() - m_lastLogTime >= 60)
                  {
                     LogIfChanged(false, "Trading disabled due to news: " + m_lastNewsMessage);
                     m_lastLogTime = TimeGMT();
                  }
                  
                  return true;
               }
            }
         }
      }
      
      return false;
   }
};
