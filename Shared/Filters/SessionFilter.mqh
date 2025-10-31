//+------------------------------------------------------------------+
//|                                             SessionFilter.mqh    |
//|                   Filtre par sessions de trading pour le trading  |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Dans votre fichier .mq5 principal, ajoutez ces inputs :       |
//|    input group "=== Session Filter ==="                          |
//|    input bool UseSessionFilter = true;                           |
//|    input ENUM_TRADING_SESSION AllowedSession = SESSION_OVERLAP;  |
//|    input int AvoidOpeningMinutes = 30;                           |
//|                                                                   |
//| 2. Incluez ce fichier : #include "../Shared/SessionFilter.mqh"      |
//|                                                                   |
//| 3. Utilisez les fonctions :                                       |
//|    - IsSessionAllowed() : utilise UseSessionFilter/AllowedSession/AvoidOpeningMinutes |
//|    - IsSessionAllowed(session, avoidMinutes) : paramètres explicites |
//|    - GetCurrentSession() : session actuelle                      |
//|                                                                   |
//| SESSIONS DISPONIBLES :                                           |
//| - SESSION_LONDON : 8:00-12:00 (session London)                  |
//| - SESSION_US : 13:00-17:00 (session US)                         |
//| - SESSION_OVERLAP : 13:00-16:00 (chevauchement London + US)     |
//| - SESSION_ASIA : 22:00-6:00 (session Asia, traverse minuit)     |
//| - SESSION_ALL : 24/7 (toujours autorisé)                        |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Énumération des sessions de trading                              |
//+------------------------------------------------------------------+
enum ENUM_TRADING_SESSION
{
   SESSION_LONDON,    // 8:00-12:00
   SESSION_US,        // 13:00-17:00
   SESSION_OVERLAP,   // 13:00-16:00 (London + US)
   SESSION_ASIA,      // 22:00-6:00
   SESSION_ALL        // 24/7
};

//---------------------------- Inputs (reusable) ---------------------
// ATTENTION DEVELOPPEUR : Pour utiliser ce SessionFilter dans votre EA, 
// vous devez AJOUTER ces inputs dans votre fichier .mq5 principal :
//
// input group "=== Session Filter ==="
// input bool UseSessionFilter = true;                               // Activer filtre par session
// input ENUM_TRADING_SESSION AllowedSession = SESSION_OVERLAP;     // Session autorisée
// input int AvoidOpeningMinutes = 30;                              // Minutes à éviter à l'ouverture
//
// Ces inputs ne peuvent PAS être définis dans un fichier .mqh (include)
// Ils doivent être dans le fichier .mq5 principal de votre EA.
//
// Exemple d'utilisation dans votre EA :
// 1. Ajoutez les inputs ci-dessus dans votre .mq5
// 2. Incluez ce fichier : #include "../Shared/SessionFilter.mqh"
// 3. Utilisez les fonctions : IsSessionAllowed(), GetCurrentSession(), etc.
//
// Ces variables sont commentées ici car elles causeraient des erreurs de compilation
// si définies dans un fichier include (.mqh)
// input group "=== Session Filter ==="
// input bool UseSessionFilter = true;                               // Activer filtre par session
// input ENUM_TRADING_SESSION AllowedSession = SESSION_OVERLAP;     // Session autorisée
// input int AvoidOpeningMinutes = 30;                              // Minutes à éviter à l'ouverture

//+------------------------------------------------------------------+
//| Helpers globaux - Fonctions utilitaires                         |
//+------------------------------------------------------------------+
ENUM_TRADING_SESSION GetCurrentSession()
{
   MqlDateTime dt; 
   TimeToStruct(TimeCurrent(), dt);
   int currentTimeMinute = dt.hour * 100 + dt.min;
   
   // SESSION_ASIA : 22:00-6:00 (traverse minuit)
   if(currentTimeMinute >= 2200 || currentTimeMinute < 600)
      return SESSION_ASIA;
   
   // SESSION_LONDON : 8:00-12:00
   if(currentTimeMinute >= 800 && currentTimeMinute < 1200)
      return SESSION_LONDON;
   
   // SESSION_OVERLAP : 13:00-16:00
   if(currentTimeMinute >= 1300 && currentTimeMinute < 1600)
      return SESSION_OVERLAP;
   
   // SESSION_US : 13:00-17:00
   if(currentTimeMinute >= 1300 && currentTimeMinute < 1700)
      return SESSION_US;
   
   // Par défaut, aucune session active
   return SESSION_ALL; // Retourner SESSION_ALL pour les heures non couvertes
}

//+------------------------------------------------------------------+
//| Fonction helper globale pour vérifier si l'heure est dans la session |
//+------------------------------------------------------------------+
bool IsInSessionRangeGlobal(int hour, int minute, ENUM_TRADING_SESSION session)
{
   int currentTimeMinute = hour * 100 + minute;
   
   switch(session)
   {
      case SESSION_LONDON:
         return (currentTimeMinute >= 800 && currentTimeMinute < 1200);
         
      case SESSION_US:
         return (currentTimeMinute >= 1300 && currentTimeMinute < 1700);
         
      case SESSION_OVERLAP:
         return (currentTimeMinute >= 1300 && currentTimeMinute < 1600);
         
      case SESSION_ASIA:
         return (currentTimeMinute >= 2200 || currentTimeMinute < 600);
         
      case SESSION_ALL:
         return true;
         
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Fonction helper globale pour vérifier si on évite les minutes d'ouverture |
//+------------------------------------------------------------------+
bool IsAvoidingOpeningGlobal(int hour, int minute, ENUM_TRADING_SESSION session, int avoidMinutes)
{
   if(avoidMinutes <= 0) return false;
   
   int currentTimeMinute = hour * 100 + minute;
   
   switch(session)
   {
      case SESSION_LONDON:
         // Éviter 8:00-8:XX (ouverture London)
         return (currentTimeMinute >= 800 && currentTimeMinute < (800 + avoidMinutes));
         
      case SESSION_US:
         // Éviter 13:00-13:XX (ouverture US)
         return (currentTimeMinute >= 1300 && currentTimeMinute < (1300 + avoidMinutes));
         
      case SESSION_OVERLAP:
         // Éviter 13:00-13:XX (ouverture US, car c'est le début de l'overlap)
         return (currentTimeMinute >= 1300 && currentTimeMinute < (1300 + avoidMinutes));
         
      case SESSION_ASIA:
         // Éviter 22:00-22:XX (ouverture Asia)
         return (currentTimeMinute >= 2200 && currentTimeMinute < (2200 + avoidMinutes));
         
      case SESSION_ALL:
         return false; // SESSION_ALL n'a pas d'ouverture spécifique
         
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Fonction principale de vérification par session                 |
//| IMPORTANT: Cette fonction utilise les variables UseSessionFilter |
//| AllowedSession et AvoidOpeningMinutes qui doivent être définies |
//| dans le fichier .mq5                                            |
//+------------------------------------------------------------------+
/*
bool IsSessionAllowed()
{
   // Si le filtre est désactivé, autoriser le trading
   if(!UseSessionFilter) return true;
   
   return IsSessionAllowedCustom((ENUM_TRADING_SESSION)AllowedSession, AvoidOpeningMinutes);
}
*/

//+------------------------------------------------------------------+
//| Fonction alternative avec paramètres explicites                 |
//| Utilisez cette fonction si vous préférez passer les paramètres  |
//| directement plutôt que d'utiliser les inputs globaux            |
//+------------------------------------------------------------------+
bool IsSessionAllowedCustom(ENUM_TRADING_SESSION session, int avoidMinutes)
{
   MqlDateTime dt; 
   TimeToStruct(TimeCurrent(), dt);
   int currentTimeMinute = dt.hour * 100 + dt.min;
   
   // SESSION_ALL : toujours autorisé
   if(session == SESSION_ALL) return true;
   
   // Vérifier si on est dans la session autorisée
   if(!IsInSessionRangeGlobal(dt.hour, dt.min, session)) return false;
   
   // Vérifier si on évite les minutes d'ouverture
   if(IsAvoidingOpeningGlobal(dt.hour, dt.min, session, avoidMinutes)) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres par session                       |
//+------------------------------------------------------------------+
class SessionFilter
{
private:
   // Configuration
   bool                    m_useFilter;
   ENUM_TRADING_SESSION    m_allowedSession;
   int                     m_avoidOpeningMinutes;
   
   // Logging (anti-spam)
   int                     m_lastLoggedHour;
   int                     m_lastLoggedMinute;
   string                  m_logPrefix;
   string                  m_lastBlockReason;

   // Noms des sessions pour l'affichage
   static string           m_sessionNames[];

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   SessionFilter()
   {
      m_useFilter = false;
      m_allowedSession = SESSION_ALL;
      m_avoidOpeningMinutes = 0;
      m_lastLoggedHour = -1;
      m_lastLoggedMinute = -1;
      m_logPrefix = "[SessionFilter] ";
      m_lastBlockReason = "";
      
      // Initialiser les noms des sessions si pas encore fait
      if(ArraySize(m_sessionNames) == 0)
      {
         ArrayResize(m_sessionNames, 5);
         m_sessionNames[0] = "London";
         m_sessionNames[1] = "US";
         m_sessionNames[2] = "Overlap";
         m_sessionNames[3] = "Asia";
         m_sessionNames[4] = "All";
      }
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void SetSession(ENUM_TRADING_SESSION session, int avoidOpeningMinutes)
   {
      m_allowedSession = session;
      m_avoidOpeningMinutes = avoidOpeningMinutes;
   }

   void SetFilter(bool enabled, ENUM_TRADING_SESSION session, int avoidMinutes)
   {
      m_useFilter = enabled;
      m_allowedSession = session;
      m_avoidOpeningMinutes = avoidMinutes;
   }

   void SetLogPrefix(string prefix)
   {
      m_logPrefix = prefix;
   }

   // Chargement rapide depuis une configuration simple
   void InitFromInputs(bool useFilter, ENUM_TRADING_SESSION session, int avoidMinutes)
   {
      m_useFilter = useFilter;
      m_allowedSession = session;
      m_avoidOpeningMinutes = avoidMinutes;
   }

   //+------------------------------------------------------------------+
   //| Vérifications principales                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      if(!m_useFilter) return true;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentTimeMinute = dt.hour * 100 + dt.min;
      
      // SESSION_ALL : toujours autorisé
      if(m_allowedSession == SESSION_ALL) return true;
      
      // Vérifier si on est dans la session autorisée
      if(!IsInSessionRangeGlobal(dt.hour, dt.min, m_allowedSession))
      {
         // Logging anti-spam : une fois par minute seulement
         if(m_lastLoggedHour != dt.hour || m_lastLoggedMinute != dt.min)
         {
            string sessionName = GetSessionName(m_allowedSession);
            Print(m_logPrefix + "Session non autorisée: ", sessionName, " | Heure actuelle: ", 
                  dt.hour, ":", (dt.min < 10 ? "0" : ""), dt.min);
            m_lastLoggedHour = dt.hour;
            m_lastLoggedMinute = dt.min;
            m_lastBlockReason = "Not in allowed session";
         }
         return false;
      }
      
      // Vérifier si on évite les minutes d'ouverture
      if(IsAvoidingOpeningGlobal(dt.hour, dt.min, m_allowedSession, m_avoidOpeningMinutes))
      {
         // Logging anti-spam : une fois par minute seulement
         if(m_lastLoggedHour != dt.hour || m_lastLoggedMinute != dt.min)
         {
            string sessionName = GetSessionName(m_allowedSession);
            Print(m_logPrefix + "Évitement ouverture: ", sessionName, " | Heure actuelle: ", 
                  dt.hour, ":", (dt.min < 10 ? "0" : ""), dt.min, " (éviter ", m_avoidOpeningMinutes, " min)");
            m_lastLoggedHour = dt.hour;
            m_lastLoggedMinute = dt.min;
            m_lastBlockReason = "Avoiding opening minutes";
         }
         return false;
      }
      
      // Reset du logging si autorisé
      if(m_lastBlockReason != "")
      {
         m_lastBlockReason = "";
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Helpers publics                                                  |
   //+------------------------------------------------------------------+
   ENUM_TRADING_SESSION GetCurrentSession()
   {
      MqlDateTime dt; 
      TimeToStruct(TimeCurrent(), dt);
      int currentTimeMinute = dt.hour * 100 + dt.min;
      
      // SESSION_ASIA : 22:00-6:00 (traverse minuit)
      if(currentTimeMinute >= 2200 || currentTimeMinute < 600)
         return SESSION_ASIA;
      
      // SESSION_LONDON : 8:00-12:00
      if(currentTimeMinute >= 800 && currentTimeMinute < 1200)
         return SESSION_LONDON;
      
      // SESSION_OVERLAP : 13:00-16:00
      if(currentTimeMinute >= 1300 && currentTimeMinute < 1600)
         return SESSION_OVERLAP;
      
      // SESSION_US : 13:00-17:00
      if(currentTimeMinute >= 1300 && currentTimeMinute < 1700)
         return SESSION_US;
      
      // Par défaut, aucune session active
      return SESSION_ALL;
   }

   // Obtenir le nom de la session actuelle
   string GetCurrentSessionName()
   {
      return GetSessionName(GetCurrentSession());
   }

   // Obtenir le nom d'une session par son énumération
   string GetSessionName(ENUM_TRADING_SESSION session) const
   {
      int index = (int)session;
      return (index >= 0 && index < 5) ? m_sessionNames[index] : "Unknown";
   }

   // Raison du blocage lors du dernier appel à IsTradingAllowed()
   string GetLastBlockReason() const
   {
      return m_lastBlockReason;
   }

   // Représentation humaine de la configuration
   string Describe() const
   {
      if(!m_useFilter) return "Session filter disabled";
      return "Session: " + GetSessionName(m_allowedSession) + " (éviter " + IntegerToString(m_avoidOpeningMinutes) + " min)";
   }

   // Obtenir la session autorisée
   ENUM_TRADING_SESSION GetAllowedSession() const
   {
      return m_allowedSession;
   }

   // Obtenir les minutes d'évitement
   int GetAvoidOpeningMinutes() const
   {
      return m_avoidOpeningMinutes;
   }

   // Vérifier si le filtre est activé
   bool IsEnabled() const
   {
      return m_useFilter;
   }

private:
};

// Initialisation statique des noms de sessions
static string SessionFilter::m_sessionNames[];
