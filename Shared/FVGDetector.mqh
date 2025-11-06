//+------------------------------------------------------------------+
//| FVGDetector.mqh                                                   |
//| Classe réutilisable pour la détection des Fair Value Gaps       |
//| Compatible avec EA et indicateurs                                 |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#ifndef FVGDETECTOR_MQH
#define FVGDETECTOR_MQH

//+------------------------------------------------------------------+
//| Système de logging avec fallback                                 |
//+------------------------------------------------------------------+
#ifdef __MQL5__
   #ifdef LOGGER_AVAILABLE
      #include "Logger.mqh"
      #define LOG_ERROR(msg)   Logger::Error("[FVGDetector - " + m_symbol + "] " + msg)
      #define LOG_WARNING(msg) Logger::Warning("[FVGDetector - " + m_symbol + "] " + msg)
      #define LOG_INFO(msg)    Logger::Info("[FVGDetector - " + m_symbol + "] " + msg)
      #define LOG_DEBUG(msg)   Logger::Debug("[FVGDetector - " + m_symbol + "] " + msg)
   #else
      #define LOG_ERROR(msg)   Print("[ERROR] [FVGDetector - ", m_symbol, "] ", msg)
      #define LOG_WARNING(msg) Print("[WARN] [FVGDetector - ", m_symbol, "] ", msg)
      #define LOG_INFO(msg)    Print("[INFO] [FVGDetector - ", m_symbol, "] ", msg)
      #define LOG_DEBUG(msg)   do { } while(false) // safe no-op to avoid empty statement warnings
   #endif
#else
   // Définir les macros pour MQL4
   #define LOG_ERROR(msg)   Print("[ERROR] [FVGDetector - ", m_symbol, "] ", msg)
   #define LOG_WARNING(msg) Print("[WARN] [FVGDetector - ", m_symbol, "] ", msg)
   #define LOG_INFO(msg)    Print("[INFO] [FVGDetector - ", m_symbol, "] ", msg)
   #define LOG_DEBUG(msg)   do { } while(false) // safe no-op to avoid empty statement warnings
#endif

//+------------------------------------------------------------------+
//| Mode d'invalidation                                              |
//+------------------------------------------------------------------+
enum InvalidationSide 
{ 
   WICK_TOUCH = 0,    // Invalidation par touche des meches
   CLOSE_BODY = 1     // Invalidation par close dans le corps
};

//+------------------------------------------------------------------+
//| Structure d'information FVG                                      |
//+------------------------------------------------------------------+
struct FVGInfo
{
   datetime time;            // Bougie centrale
   datetime startTime;       // Bougie 1
   datetime endTime;         // Bougie 3
   double   top;             // Prix haut de zone
   double   bottom;          // Prix bas de zone
   bool     isBullish;       // Type de FVG
   ENUM_TIMEFRAMES timeframe; // Timeframe d'origine
   double   gapSize;         // Taille du gap
   bool     IsValid;         // Indique si le FVG est encore valide
   
   //+------------------------------------------------------------------+
   //| Vérifie si le FVG est valide                                    |
   //+------------------------------------------------------------------+
   bool IsValidFVG() const { return IsValid; }
};

//+------------------------------------------------------------------+
//| Configuration FVG                                                |
//+------------------------------------------------------------------+
struct FVGConfig
{
   int atrPeriod;              // Période ATR (défaut: 14)
   double minGapATRPercent;    // Gap minimum en % ATR (défaut: 5.0)
   double epsilonPts;          // Tolérance en points (défaut: 0.1)
   double invalidatePct;       // % de pénétration pour invalidation (défaut: 30.0)
   InvalidationSide mode;      // Mode d'invalidation (défaut: WICK_TOUCH)
   int lookbackBars;           // Fenêtre lookback (défaut: 300)
   bool debugMode;             // Mode debug (défaut: false)
   
   //+------------------------------------------------------------------+
   //| Constructeur avec valeurs par défaut                            |
   //+------------------------------------------------------------------+
   FVGConfig()
   {
      atrPeriod = 14;
      minGapATRPercent = 5.0;
      epsilonPts = 0.1;
      invalidatePct = 30.0;
      mode = WICK_TOUCH;
      lookbackBars = 300;
      debugMode = false;
   }
};

//+------------------------------------------------------------------+
//| Classe principale de détection FVG                                |
//+------------------------------------------------------------------+
class FVGDetector
{
private:
   string            m_symbol;              // Symbole analysé
   FVGInfo           m_fvgList[];          // Liste des FVG détectés
   int               m_atrHandles[];        // Handles ATR par timeframe
   ENUM_TIMEFRAMES   m_timeframes[];        // Timeframes configurés
   FVGConfig         m_config;              // Configuration
   double            m_point;               // Point du symbole
   bool              m_initialized;        // État d'initialisation
   
   // Cache par timeframe pour éviter les CopyRates inutiles
   datetime         m_lastBarTime[];       // Dernière barre vue par timeframe
   int              m_lastBarsCount[];     // Compteur de barres (optionnel)

   // HashSet O(1) pour l'existence des FVG (open addressing linear probing)
   ulong            m_fvgHashKeys[];       // Clés de hash
   uchar            m_fvgHashState[];      // 0=empty, 1=occupied, 2=deleted
   int              m_fvgHashSize;         // Nombre d'éléments
   int              m_fvgHashCap;          // Capacité du hashset
   
   // Métriques de performance basiques
   ulong            m_processTimeMs;       // Temps cumulé ProcessTimeframe
   ulong            m_invalidateTimeMs;    // Temps cumulé UpdateInvalidation
   int              m_cacheHits;           // Hits cache (ProcessTimeframe ignoré)
   int              m_cacheMisses;         // Miss cache (traitement effectué)
   int              m_memoryAllocs;        // Compteur grossier d'allocations

   // Cache des FVG valides préfiltrés (tous timeframes)
   FVGInfo          m_cachedBullish[];
   FVGInfo          m_cachedBearish[];
   bool             m_validCacheBuilt;
   
   //+------------------------------------------------------------------+
   //| Création d'un FVGInfo                                           |
   //+------------------------------------------------------------------+
   FVGInfo CreateFVGInfo(datetime time, datetime startTime, datetime endTime, 
                         double top, double bottom, bool isBullish, 
                         ENUM_TIMEFRAMES tf, double gapSize)
   {
      FVGInfo fvg;
      fvg.time = time;
      fvg.startTime = startTime;
      fvg.endTime = endTime;
      fvg.top = top;
      fvg.bottom = bottom;
      fvg.isBullish = isBullish;
      fvg.timeframe = tf;
      fvg.gapSize = gapSize;
      fvg.IsValid = true;
      return fvg;
   }
   
   //+------------------------------------------------------------------+
   //| Ajout d'un FVG à la liste                                      |
   //+------------------------------------------------------------------+
   void AddFVGToList(const FVGInfo &fvg)
   {
      int n = ArraySize(m_fvgList);
      ArrayResize(m_fvgList, n + 1);
      m_fvgList[n] = fvg;
      m_memoryAllocs++;
      HashInsert(HashFVG(fvg));
      m_validCacheBuilt = false; // invalider le cache des listes valides
   }

   // Reconstruit les caches bullish/bearish valides en une passe optimisée
   void RebuildValidCaches()
   {
      int total = ArraySize(m_fvgList);
      int nb = 0, ns = 0;
      for(int i=0;i<total;i++)
      {
         if(!m_fvgList[i].IsValid) continue;
         if(m_fvgList[i].isBullish) nb++; else ns++;
      }
      ArrayResize(m_cachedBullish, nb);
      ArrayResize(m_cachedBearish, ns);
      int ib=0,is=0;
      for(int i=0;i<total;i++)
      {
         if(!m_fvgList[i].IsValid) continue;
         if(m_fvgList[i].isBullish) { m_cachedBullish[ib++] = m_fvgList[i]; }
         else { m_cachedBearish[is++] = m_fvgList[i]; }
      }
      m_validCacheBuilt = true;
   }
   
   // Hash d'un FVG (FNV-1a 32-bit, renvoyé en ulong)
   ulong HashFVG(const FVGInfo &x) const
   {
      uint h = 2166136261;        // offset basis (FNV-1a 32-bit)
      uint a = (uint)(x.startTime ^ x.endTime);
      uint b = (uint)MathRound(x.top / m_point);
      uint c = (uint)MathRound(x.bottom / m_point);
      uint d = (uint)(x.isBullish ? 1 : 0);
      const uint FNV_PRIME = 16777619; // FNV prime (32-bit)
      h ^= a; h *= FNV_PRIME;
      h ^= b; h *= FNV_PRIME;
      h ^= c; h *= FNV_PRIME;
      h ^= d; h *= FNV_PRIME;
      return (ulong)h;
   }
   
   void EnsureHashCapacity(int minCap)
   {
      if(m_fvgHashCap >= minCap * 2) // garder du slack de charge
         return;
      int newCap = (m_fvgHashCap <= 0 ? 256 : m_fvgHashCap);
      while(newCap < minCap * 2) newCap <<= 1;
      ulong oldKeys[]; uchar oldState[];
      int oldCap = m_fvgHashCap;
      // sauvegarde
      if(oldCap > 0)
      {
         ArrayResize(oldKeys, oldCap);
         ArrayResize(oldState, oldCap);
         ArrayCopy(oldKeys, m_fvgHashKeys);
         ArrayCopy(oldState, m_fvgHashState);
      }
      ArrayResize(m_fvgHashKeys, newCap);      // init à 0
      ArrayResize(m_fvgHashState, newCap);     // init à 0
      m_fvgHashCap = newCap;
      m_memoryAllocs++;
      // rehash
      if(oldCap > 0)
      {
         m_fvgHashSize = 0;
         for(int i=0;i<oldCap;i++)
         {
            if(oldState[i]==1)
            {
               // réinsérer
               int idx = (int)(oldKeys[i] & (newCap - 1));
               while(m_fvgHashState[idx]==1) idx = (idx + 1) & (newCap - 1);
               m_fvgHashKeys[idx] = oldKeys[i];
               m_fvgHashState[idx] = 1;
               m_fvgHashSize++;
            }
         }
      }
   }
   
   bool HashContains(ulong key)
   {
      if(m_fvgHashCap==0) return false;
      int idx = (int)(key & (m_fvgHashCap - 1));
      while(true)
      {
         uchar st = m_fvgHashState[idx];
         if(st==0) return false;
         if(st==1 && m_fvgHashKeys[idx]==key) return true;
         idx = (idx + 1) & (m_fvgHashCap - 1);
      }
      return false;
   }
   
   void HashInsert(ulong key)
   {
      EnsureHashCapacity(m_fvgHashSize + 1);
      int idx = (int)(key & (m_fvgHashCap - 1));
      while(m_fvgHashState[idx]==1 && m_fvgHashKeys[idx]!=key)
         idx = (idx + 1) & (m_fvgHashCap - 1);
      if(m_fvgHashState[idx]!=1)
      {
         m_fvgHashKeys[idx] = key;
         m_fvgHashState[idx] = 1;
         m_fvgHashSize++;
      }
   }

   //+------------------------------------------------------------------+
   //| Vérifie si un FVG existe déjà                                   |
   //+------------------------------------------------------------------+
   bool ExistsFVG(const FVGInfo &x)
   {
      ulong h = HashFVG(x);
      return HashContains(h);
   }
   
   //+------------------------------------------------------------------+
   //| Détection gap haussier                                          |
   //+------------------------------------------------------------------+
   int DetectBullishGap(MqlRates &rates[], double &atr[], double eps, 
                        ENUM_TIMEFRAMES tf, int added)
   {
      for(int i = 1; i < ArraySize(rates) - 2; i++)
      {
         datetime t_old = rates[i + 2].time;
         datetime t_new = rates[i].time;
         datetime startTime = (t_old < t_new ? t_old : t_new);
         datetime endTime = (t_old < t_new ? t_new : t_old);
         
         double minGap = atr[i] * m_config.minGapATRPercent / 100.0;
         
         // Bullish: low[i] > high[i+2] + eps
         if((rates[i].low - rates[i + 2].high) > eps)
         {
            double rawTop = rates[i].low;
            double rawBot = rates[i + 2].high;
            double top = MathMax(rawTop, rawBot);
            double bottom = MathMin(rawTop, rawBot);
            double gapSz = top - bottom;
            
            if(gapSz >= minGap)
            {
               FVGInfo fvg = CreateFVGInfo(rates[i + 1].time, startTime, endTime, 
                                          top, bottom, true, tf, gapSz);
               if(!ExistsFVG(fvg))
               {
                  AddFVGToList(fvg);
                  added++;
               }
            }
         }
      }
      return added;
   }
   
   //+------------------------------------------------------------------+
   //| Détection gap baissier                                          |
   //+------------------------------------------------------------------+
   int DetectBearishGap(MqlRates &rates[], double &atr[], double eps, 
                        ENUM_TIMEFRAMES tf, int added)
   {
      for(int i = 1; i < ArraySize(rates) - 2; i++)
      {
         datetime t_old = rates[i + 2].time;
         datetime t_new = rates[i].time;
         datetime startTime = (t_old < t_new ? t_old : t_new);
         datetime endTime = (t_old < t_new ? t_new : t_old);
         
         double minGap = atr[i] * m_config.minGapATRPercent / 100.0;
         
         // Bearish: low[i+2] > high[i] + eps
         if((rates[i + 2].low - rates[i].high) > eps)
         {
            double rawTop = rates[i].high;
            double rawBot = rates[i + 2].low;
            double top = MathMax(rawTop, rawBot);
            double bottom = MathMin(rawTop, rawBot);
            double gapSz = top - bottom;
            
            if(gapSz >= minGap)
            {
               FVGInfo fvg = CreateFVGInfo(rates[i + 1].time, startTime, endTime, 
                                          top, bottom, false, tf, gapSz);
               if(!ExistsFVG(fvg))
               {
                  AddFVGToList(fvg);
                  added++;
               }
            }
         }
      }
      return added;
   }
   
   //+------------------------------------------------------------------+
   //| Tri des FVG par temps                                           |
   //+------------------------------------------------------------------+
   void SortFVGsByTime(FVGInfo &a[])
   {
      int n = ArraySize(a);
      if(n <= 1) return;
      
      for(int i = 0; i < n - 1; i++)
      {
         for(int j = 0; j < n - i - 1; j++)
         {
            if(a[j].time < a[j + 1].time)
            {
               FVGInfo t = a[j];
               a[j] = a[j + 1];
               a[j + 1] = t;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Vérifie l'invalidation d'un FVG                                 |
   //+------------------------------------------------------------------+
   bool CheckInvalidation(const FVGInfo &fvg, ENUM_TIMEFRAMES tf)
   {
      double top = fvg.top;
      double bottomVal = fvg.bottom;
      
      // Normalisation bornes si inversées
      if(top < bottomVal)
      {
         double tmp = top;
         top = bottomVal;
         bottomVal = tmp;
      }
      
      // Hauteur strictement positive
      const double height = top - bottomVal;
      if(height <= 0.0)
         return false;
      
      // Seuil d'invalidation
      const double threshold = height * m_config.invalidatePct / 100.0;
      
      // Index MT5 de la bougie correspondant à endTime
      int endIdx = iBarShift(m_symbol, tf, fvg.endTime, true);
      if(endIdx == WRONG_VALUE || endIdx <= 0)
         return false;
      
      // Balayage des bougies strictement postérieures à endTime
      for(int k = 0; k < endIdx; ++k)
      {
         double barLow = iLow(m_symbol, tf, k);
         double barHigh = iHigh(m_symbol, tf, k);
         double barClose = iClose(m_symbol, tf, k);
         
         bool invalidate = false;
         
         if(m_config.mode == WICK_TOUCH)
         {
            if(fvg.isBullish)
               invalidate = (barLow <= (top - threshold));
            else
               invalidate = (barHigh >= (bottomVal + threshold));
         }
         else // CLOSE_BODY
         {
            if(fvg.isBullish)
               invalidate = (barClose <= (top - threshold));
            else
               invalidate = (barClose >= (bottomVal + threshold));
         }
         
         if(invalidate)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Récupère l'index du handle ATR pour un timeframe                |
   //+------------------------------------------------------------------+
   int GetATRHandleIndex(ENUM_TIMEFRAMES tf)
   {
      for(int i = 0; i < ArraySize(m_timeframes); i++)
      {
         if(m_timeframes[i] == tf)
            return i;
      }
      return -1;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                     |
   //+------------------------------------------------------------------+
   FVGDetector()
   {
      m_symbol = "";
      m_point = 0.0;
      m_initialized = false;
      ArrayResize(m_fvgList, 0);
      ArrayResize(m_atrHandles, 0);
      ArrayResize(m_timeframes, 0);
      ArrayResize(m_lastBarTime, 0);
      ArrayResize(m_lastBarsCount, 0);
      ArrayResize(m_fvgHashKeys, 0);
      ArrayResize(m_fvgHashState, 0);
      m_fvgHashSize = 0;
      m_fvgHashCap = 0;
      m_processTimeMs = 0;
      m_invalidateTimeMs = 0;
      m_cacheHits = 0;
      m_cacheMisses = 0;
      m_memoryAllocs = 0;
      
      // 🆕 Initialiser les caches de FVG valides
      ArrayResize(m_cachedBullish, 0);
      ArrayResize(m_cachedBearish, 0);
      m_validCacheBuilt = false;
   }
   
   //+------------------------------------------------------------------+
   //| Destructeur                                                      |
   //+------------------------------------------------------------------+
   ~FVGDetector()
   {
      Deinit();
   }
   
   //+------------------------------------------------------------------+
   //| Initialisation avec symbol et timeframes                         |
   //+------------------------------------------------------------------+
   bool Init(string symbol, ENUM_TIMEFRAMES &timeframes[], const FVGConfig &config)
   {
      if(ArraySize(timeframes) == 0)
      {
         LOG_ERROR("No timeframes provided");
         return false;
      }
      
      m_symbol = symbol;
      m_config = config;
      m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(m_point <= 0)
      {
         LOG_ERROR("Invalid symbol point");
         return false;
      }
      
      // Copier les timeframes
      ArrayResize(m_timeframes, ArraySize(timeframes));
      ArrayCopy(m_timeframes, timeframes);
      
      // Créer les handles ATR pour chaque timeframe
      ArrayResize(m_atrHandles, ArraySize(timeframes));
      for(int i = 0; i < ArraySize(timeframes); i++)
      {
         m_atrHandles[i] = iATR(m_symbol, timeframes[i], m_config.atrPeriod);
         if(m_atrHandles[i] == INVALID_HANDLE)
         {
            LOG_ERROR("ATR creation failed for " + EnumToString(timeframes[i]) + " err=" + IntegerToString(GetLastError()));
            Deinit();
            return false;
         }
      }
      
      ArrayResize(m_fvgList, 0);
      // init cache TF
      ArrayResize(m_lastBarTime, ArraySize(timeframes));
      ArrayResize(m_lastBarsCount, ArraySize(timeframes));
      for(int i=0;i<ArraySize(timeframes);i++){ m_lastBarTime[i]=0; m_lastBarsCount[i]=0; }
      // init hash
      m_fvgHashSize = 0;
      m_fvgHashCap = 0;
      ArrayResize(m_fvgHashKeys, 0);
      ArrayResize(m_fvgHashState, 0);
      m_initialized = true;
      
      LOG_INFO("Initialized for " + symbol + " with " + IntegerToString(ArraySize(timeframes)) + " timeframe(s)");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Initialisation simplifiée avec un seul timeframe                 |
   //+------------------------------------------------------------------+
   bool Init(string symbol, ENUM_TIMEFRAMES tf, const FVGConfig &config)
   {
      ENUM_TIMEFRAMES tfs[1];
      tfs[0] = tf;
      return Init(symbol, tfs, config);
   }
   
   //+------------------------------------------------------------------+
   //| Désinitialisation                                               |
   //+------------------------------------------------------------------+
   void Deinit()
   {
      // Libérer les handles ATR
      for(int i = 0; i < ArraySize(m_atrHandles); i++)
      {
         if(m_atrHandles[i] != INVALID_HANDLE)
            IndicatorRelease(m_atrHandles[i]);
      }
      
      // Libérer tous les tableaux
      ArrayFree(m_fvgList);
      ArrayFree(m_atrHandles);
      ArrayFree(m_timeframes);
      
      // 🆕 Libérer les caches de timeframe
      ArrayFree(m_lastBarTime);
      ArrayFree(m_lastBarsCount);
      
      // 🆕 Libérer le HashSet
      ArrayFree(m_fvgHashKeys);
      ArrayFree(m_fvgHashState);
      m_fvgHashSize = 0;
      m_fvgHashCap = 0;
      
      // 🆕 Libérer les caches de FVG valides
      ArrayFree(m_cachedBullish);
      ArrayFree(m_cachedBearish);
      m_validCacheBuilt = false;
      
      // Réinitialiser les compteurs de performance
      m_processTimeMs = 0;
      m_invalidateTimeMs = 0;
      m_cacheHits = 0;
      m_cacheMisses = 0;
      m_memoryAllocs = 0;
      
      m_initialized = false;
   }
   
   //+------------------------------------------------------------------+
   //| Traitement d'un timeframe pour détecter les FVG                 |
   //+------------------------------------------------------------------+
   int ProcessTimeframe(ENUM_TIMEFRAMES tf)
   {
      if(!m_initialized)
      {
         LOG_ERROR("Not initialized");
         return 0;
      }
      
      int handleIdx = GetATRHandleIndex(tf);
      if(handleIdx < 0)
      {
         LOG_WARNING("Timeframe " + EnumToString(tf) + " not configured");
         return 0;
      }
      // Cache: ne recalculer que si nouvelle barre
      datetime cur = iTime(m_symbol, tf, 0);
      if(handleIdx >= 0)
      {
         if(m_lastBarTime[handleIdx] == cur && m_lastBarTime[handleIdx] != 0)
         {
            m_cacheHits++;
            return 0;
         }
      }
      m_cacheMisses++;
      ulong t0 = GetMicrosecondCount();

      int need = MathMax(m_config.lookbackBars + 10, 500);
      
      MqlRates rates[];
      int copied = CopyRates(m_symbol, tf, 0, need, rates);
      if(copied < 3)
      {
         LOG_WARNING("Not enough rates copied: " + IntegerToString(copied));
         return 0;
      }
      ArraySetAsSeries(rates, true);
      
      double atr[];
      if(CopyBuffer(m_atrHandles[handleIdx], 0, 0, copied, atr) <= 0)
      {
         LOG_WARNING("Failed to copy ATR buffer");
         return 0;
      }
      ArraySetAsSeries(atr, true);
      
      double eps = m_config.epsilonPts * m_point;
      int added = 0;
      
      // Détection bullish et bearish
      added = DetectBullishGap(rates, atr, eps, tf, added);
      added = DetectBearishGap(rates, atr, eps, tf, added);

      // Enregistrer les nouveaux FVG dans le hashset (parcours du bloc récemment ajouté)
      // Ici, comme AddFVGToList appelle déjà EnsureFvgCapacity et ajuste la taille,
      // on insère dans le hash juste après les insertions lors de Detect*.
      // Note: AddFVGToList n'insère pas dans le hash; le faire au moment de l'ajout.
      
      if(m_config.debugMode)
         LOG_DEBUG("FVG added: " + IntegerToString(added) + " total=" + IntegerToString(ArraySize(m_fvgList)));
      
      // Mettre à jour état cache
      if(handleIdx >= 0) m_lastBarTime[handleIdx] = cur;
      m_processTimeMs += (GetMicrosecondCount() - t0) / 1000;
      // Rebuild caches une seule fois par nouvelle bougie
      RebuildValidCaches();
      return added;
   }
   
   //+------------------------------------------------------------------+
   //| Mise à jour et invalidation des FVG                              |
   //+------------------------------------------------------------------+
   int UpdateInvalidation(ENUM_TIMEFRAMES tf)
   {
      if(!m_initialized)
         return 0;
      
      ulong t0 = GetMicrosecondCount();
      int invalidated = 0;
      
      for(int idx = 0; idx < ArraySize(m_fvgList); ++idx)
      {
         if(!m_fvgList[idx].IsValid)
            continue;
         
         // Filtrer par timeframe si spécifié
         if(m_fvgList[idx].timeframe != tf)
            continue;
         
         if(CheckInvalidation(m_fvgList[idx], tf))
         {
            m_fvgList[idx].IsValid = false;
            invalidated++;
         }
      }
      
      if(m_config.debugMode && invalidated > 0)
         LOG_DEBUG("Invalidated " + IntegerToString(invalidated) + " FVG(s)");
      m_invalidateTimeMs += (GetMicrosecondCount() - t0) / 1000;
      if(invalidated>0) RebuildValidCaches();
      return invalidated;
   }
   
   //+------------------------------------------------------------------+
   //| Filtrage par lookback window                                    |
   //+------------------------------------------------------------------+
   void FilterByLookback(ENUM_TIMEFRAMES tf, int lookbackBars)
   {
      if(lookbackBars <= 0) return;
      
      datetime tt[];
      int n = CopyTime(m_symbol, tf, 0, lookbackBars + 1, tt);
      if(n < 1) return;
      ArraySetAsSeries(tt, true);
      datetime threshold = tt[MathMin(lookbackBars, n - 1)];
      
      SortFVGsByTime(m_fvgList);
      
      FVGInfo kept[];
      for(int i = 0; i < ArraySize(m_fvgList); i++)
      {
         if(m_fvgList[i].timeframe == tf && m_fvgList[i].time >= threshold)
         {
            int k = ArraySize(kept);
            ArrayResize(kept, k + 1);
            kept[k] = m_fvgList[i];
         }
      }
      
      // Remplacer la liste
      ArrayResize(m_fvgList, 0);
      for(int i = 0; i < ArraySize(kept); i++)
      {
         int k = ArraySize(m_fvgList);
         ArrayResize(m_fvgList, k + 1);
         m_fvgList[k] = kept[i];
      }
   }
   
   //+------------------------------------------------------------------+
   //| Récupère la liste complète des FVG                               |
   //+------------------------------------------------------------------+
   void GetFVGList(FVGInfo &result[], bool validOnly = true)
   {
      if(validOnly && m_validCacheBuilt)
      {
         int nb = ArraySize(m_cachedBullish);
         int ns = ArraySize(m_cachedBearish);
         ArrayResize(result, nb+ns);
         if(nb>0) ArrayCopy(result, m_cachedBullish, 0, 0, nb);
         if(ns>0) ArrayCopy(result, m_cachedBearish, nb, 0, ns);
         return;
      }
      // Fallback: deux passes pour minimiser les reallocations
      int count = 0;
      for(int i=0;i<ArraySize(m_fvgList);i++) if(!validOnly || m_fvgList[i].IsValid) count++;
      ArrayResize(result, count);
      int k=0;
      for(int i=0;i<ArraySize(m_fvgList);i++) if(!validOnly || m_fvgList[i].IsValid) result[k++] = m_fvgList[i];
   }
   
   //+------------------------------------------------------------------+
   //| Récupère les FVG bullish                                        |
   //+------------------------------------------------------------------+
   void GetBullishFVGs(FVGInfo &result[], bool validOnly = true)
   {
      if(validOnly && m_validCacheBuilt)
      {
         int nb = ArraySize(m_cachedBullish);
         ArrayResize(result, nb);
         if(nb>0) ArrayCopy(result, m_cachedBullish);
         return;
      }
      int count = 0;
      for(int i=0;i<ArraySize(m_fvgList);i++) if(m_fvgList[i].isBullish && (!validOnly || m_fvgList[i].IsValid)) count++;
      ArrayResize(result, count);
      int k=0;
      for(int i=0;i<ArraySize(m_fvgList);i++) if(m_fvgList[i].isBullish && (!validOnly || m_fvgList[i].IsValid)) result[k++] = m_fvgList[i];
   }
   
   //+------------------------------------------------------------------+
   //| Récupère les FVG bearish                                         |
   //+------------------------------------------------------------------+
   void GetBearishFVGs(FVGInfo &result[], bool validOnly = true)
   {
      if(validOnly && m_validCacheBuilt)
      {
         int ns = ArraySize(m_cachedBearish);
         ArrayResize(result, ns);
         if(ns>0) ArrayCopy(result, m_cachedBearish);
         return;
      }
      int count = 0;
      for(int i=0;i<ArraySize(m_fvgList);i++) if(!m_fvgList[i].isBullish && (!validOnly || m_fvgList[i].IsValid)) count++;
      ArrayResize(result, count);
      int k=0;
      for(int i=0;i<ArraySize(m_fvgList);i++) if(!m_fvgList[i].isBullish && (!validOnly || m_fvgList[i].IsValid)) result[k++] = m_fvgList[i];
   }
   
   //+------------------------------------------------------------------+
   //| Récupère les FVG pour un timeframe spécifique                    |
   //+------------------------------------------------------------------+
   void GetFVGsByTimeframe(ENUM_TIMEFRAMES tf, FVGInfo &result[], bool validOnly = true)
   {
      ArrayResize(result, 0);
      
      for(int i = 0; i < ArraySize(m_fvgList); i++)
      {
         if(m_fvgList[i].timeframe == tf && (!validOnly || m_fvgList[i].IsValid))
         {
            int k = ArraySize(result);
            ArrayResize(result, k + 1);
            result[k] = m_fvgList[i];
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Réinitialise complètement la liste                               |
   //+------------------------------------------------------------------+
   void Clear()
   {
      ArrayResize(m_fvgList, 0);
      
      // 🆕 Réinitialiser le HashSet
      ArrayResize(m_fvgHashKeys, 0);
      ArrayResize(m_fvgHashState, 0);
      m_fvgHashSize = 0;
      m_fvgHashCap = 0;
      
      // 🆕 Réinitialiser les caches
      ArrayResize(m_cachedBullish, 0);
      ArrayResize(m_cachedBearish, 0);
      m_validCacheBuilt = false;
      
      if(m_config.debugMode)
         LOG_DEBUG("FVG list cleared");
   }
   
   //+------------------------------------------------------------------+
   //| Obtient le nombre total de FVG                                   |
   //+------------------------------------------------------------------+
   int GetTotalCount(bool validOnly = true)
   {
      if(!validOnly)
         return ArraySize(m_fvgList);
      
      int count = 0;
      for(int i = 0; i < ArraySize(m_fvgList); i++)
      {
         if(m_fvgList[i].IsValid)
            count++;
      }
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Obtient les statistiques                                          |
   //+------------------------------------------------------------------+
   void GetStats(int &total, int &bullish, int &bearish, int &valid)
   {
      total = ArraySize(m_fvgList);
      bullish = 0;
      bearish = 0;
      valid = 0;
      
      for(int i = 0; i < total; i++)
      {
         if(m_fvgList[i].isBullish)
            bullish++;
         else
            bearish++;
         
         if(m_fvgList[i].IsValid)
            valid++;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Vérifie si initialisé                                            |
   //+------------------------------------------------------------------+
   bool IsInitialized() const { return m_initialized; }
   
   //+------------------------------------------------------------------+
   //| Obtient le symbole                                               |
   //+------------------------------------------------------------------+
   string GetSymbol() const { return m_symbol; }
};
// Undefine local logging macros to avoid leaking into includers
#undef LOG_ERROR
#undef LOG_WARNING
#undef LOG_INFO
#undef LOG_DEBUG

#endif // FVGDETECTOR_MQH
//+------------------------------------------------------------------+

