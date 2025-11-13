#ifndef __FVG_TRADE_FILTER_MQH__
#define __FVG_TRADE_FILTER_MQH__

#include "../../../Shared/FVGDetector.mqh"

class FVGTradeFilter
  {
private:
   bool             m_enabled;
   FVGDetector*     m_detector;
   FVGDetector*     m_detectorSecondary;  // 🆕 Deuxième détecteur
   string           m_symbol;
   ENUM_TIMEFRAMES  m_timeframe;
   ENUM_TIMEFRAMES  m_timeframeSecondary;  // 🆕 Deuxième timeframe
   double           m_radiusPts;
   bool             m_useSecondary;        // 🆕 Activer/désactiver le deuxième timeframe
   datetime         m_lastProcessPrimary;    // 🆕 Dernier temps de traitement principal
   datetime         m_lastProcessSecondary;  // 🆕 Dernier temps de traitement secondaire

public:
   FVGTradeFilter()
     {
      m_enabled   = false;
      m_detector  = NULL;
      m_detectorSecondary = NULL;  // 🆕
      m_symbol    = "";
      m_timeframe = PERIOD_CURRENT;
      m_timeframeSecondary = PERIOD_CURRENT;  // 🆕
      m_radiusPts = 500.0;
      m_useSecondary = false;  // 🆕
      m_lastProcessPrimary = 0;      // 🆕
      m_lastProcessSecondary = 0;   // 🆕
     }

   ~FVGTradeFilter()
     {
      if(m_detector != NULL)
        {
         delete m_detector;
         m_detector = NULL;
        }
      // 🆕 Libérer le deuxième détecteur
      if(m_detectorSecondary != NULL)
        {
         delete m_detectorSecondary;
         m_detectorSecondary = NULL;
        }
     }


   // Appelée à chaque nouvelle bougie sur le timeframe surveillé :
   void OnNewBar()
     {
      if(!m_enabled || m_detector == NULL)
         return;
      
      // 🔍 LOGS DIAGNOSTIQUES
      static int callCount = 0;
      static datetime lastLog = 0;
      callCount++;
      
      datetime now = TimeCurrent();
      if(now - lastLog >= 3600) // Log toutes les heures
      {
         FVGInfo bullish[], bearish[];
         m_detector.GetBullishFVGs(bullish, true);
         m_detector.GetBearishFVGs(bearish, true);
         
         Print("╔═════════════════════════════════════════");
         Print("║ 🔍 FVG DETECTOR [", m_symbol, "]");
         Print("╠═════════════════════════════════════════");
         Print("║ OnNewBar calls/h  : ", callCount);
         Print("║ Bullish FVGs      : ", ArraySize(bullish));
         Print("║ Bearish FVGs      : ", ArraySize(bearish));
         Print("║ Total FVGs        : ", ArraySize(bullish) + ArraySize(bearish));
         Print("╚═════════════════════════════════════════");
         
         callCount = 0;
         lastLog = now;
      }
      
      // 🆕 Traiter le détecteur principal toutes les 5 minutes (300 secondes)
      if(now - m_lastProcessPrimary >= 300)
        {
         m_detector.ProcessTimeframe(m_timeframe);
         m_detector.UpdateInvalidation(m_timeframe);
         m_lastProcessPrimary = now;
        }
      
      // 🆕 Traiter le deuxième timeframe toutes les 1 minute (60 secondes)
      if(m_useSecondary && m_detectorSecondary != NULL)
        {
         if(now - m_lastProcessSecondary >= 60)
           {
            m_detectorSecondary.ProcessTimeframe(m_timeframeSecondary);
            m_detectorSecondary.UpdateInvalidation(m_timeframeSecondary);
            m_lastProcessSecondary = now;
           }
        }
     }

     
   // 🆕 Initialisation avec deuxième timeframe optionnel
   void Init(const string symbol, const ENUM_TIMEFRAMES tf, const bool enabled, 
             const ENUM_TIMEFRAMES tfSecondary = PERIOD_M1, const bool useSecondary = true)
     {
      m_symbol    = symbol;
      m_timeframe = tf;
      m_timeframeSecondary = tfSecondary;  // 🆕
      m_useSecondary = useSecondary;        // 🆕
      m_enabled   = enabled;
      if(!m_enabled) return;

      // Initialiser le détecteur principal
      if(m_detector != NULL)
        {
         delete m_detector;
         m_detector = NULL;
        }
      m_detector = new FVGDetector();

      FVGConfig cfg;
      cfg.atrPeriod        = 14;
      cfg.minGapATRPercent = 0.5;
      cfg.epsilonPts        = 0.02;
      cfg.invalidatePct    = 30.0;
      cfg.mode             = WICK_TOUCH;
      cfg.lookbackBars     = 50;  // 🔥 OPTIMISATION: 300→50 pour réduire mémoire
      cfg.debugMode        = false;

      if(!m_detector.Init(m_symbol, m_timeframe, cfg))
        {
         delete m_detector;
         m_detector = NULL;
         m_enabled  = false;
         return;
        }
      // initial pass
      m_detector.ProcessTimeframe(m_timeframe);
      m_detector.UpdateInvalidation(m_timeframe);
      
      // 🆕 Initialiser le deuxième détecteur si activé
      if(m_useSecondary && tfSecondary != PERIOD_CURRENT)
        {
         if(m_detectorSecondary != NULL)
           {
            delete m_detectorSecondary;
            m_detectorSecondary = NULL;
           }
         m_detectorSecondary = new FVGDetector();
         
         if(!m_detectorSecondary.Init(m_symbol, m_timeframeSecondary, cfg))
           {
            delete m_detectorSecondary;
            m_detectorSecondary = NULL;
            Print("⚠️ [FVG] Échec initialisation deuxième timeframe: ", EnumToString(m_timeframeSecondary));
           }
         else
           {
            m_detectorSecondary.ProcessTimeframe(m_timeframeSecondary);
            m_detectorSecondary.UpdateInvalidation(m_timeframeSecondary);
           }
        }
     }

   void SetEnabled(bool enabled)
     {
      m_enabled = enabled;
     }

   bool GetEnabled()
     {
      return m_enabled;
     }

   void SetRadius(double radiusPts)
     {
      m_radiusPts = MathMax(50.0, radiusPts);
     }

   
   
     bool IsTradeAllowedByFVG(const double entryPrice, const double stopLoss, const bool isBuy)
     {
      if(!m_enabled || m_detector == NULL)
         return true;

      FVGInfo fvgs[];
      if(isBuy)
         m_detector.GetBullishFVGs(fvgs, true);
      else
         m_detector.GetBearishFVGs(fvgs, true);

      int fvgsCount = ArraySize(fvgs);
      
      // 🔥 WARNING si trop de FVGs
      if(fvgsCount > 20)
      {
         static datetime lastWarning = 0;
         datetime now = TimeCurrent();
         if(now - lastWarning > 3600)
         {
            Print("⚠️ [FVG] TROP DE FVGs: ", fvgsCount, " (devrait être < 20)");
            Print("⚠️ [FVG] Réduire lookbackBars dans Init()");
            lastWarning = now;
         }
      }
      
      // 🔥 PROTECTION: Limiter à 20 FVGs max pour éviter ralentissement
      int maxCheck = MathMin(fvgsCount, 20);
      
      for(int i = 0; i < maxCheck; i++)
        {
         if(!fvgs[i].IsValid) continue;

         // Normaliser top/bottom
         double fvgHigh = fvgs[i].top;
         double fvgLow  = fvgs[i].bottom;
         if(fvgHigh < fvgLow)
           {
            double t = fvgHigh;
            fvgHigh  = fvgLow;
            fvgLow   = t;
           }

         bool stopInside = (stopLoss <= fvgHigh && stopLoss >= fvgLow);
         if(stopInside)
         {
            Print("🚫 [FVG BLOCK] ", (isBuy ? "BUY" : "SELL"), 
                  " | SL: ", DoubleToString(stopLoss, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)),
                  " | FVG[", i, "] ", EnumToString(m_timeframe), ": ", 
                  DoubleToString(fvgLow, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)), 
                  "-", DoubleToString(fvgHigh, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)));
            return false;
         }
        }
      
      return true;
     }




     bool HasFVGBetweenEntryAndSL(const double entryPrice, const double stopLoss, const bool isBuy)
     {
        if(!m_enabled || m_detector == NULL)
           return false;

        double rangeHigh = MathMax(entryPrice, stopLoss);
        double rangeLow  = MathMin(entryPrice, stopLoss);

        FVGInfo fvgs[];
        if(isBuy)
           m_detector.GetBullishFVGs(fvgs, true);
        else
           m_detector.GetBearishFVGs(fvgs, true);

        int fvgsCount = ArraySize(fvgs);
        int maxCheck = MathMin(fvgsCount, 20);

        for(int i = 0; i < maxCheck; i++)
        {
           if(!fvgs[i].IsValid)
              continue;

           double fvgHigh = fvgs[i].top;
           double fvgLow  = fvgs[i].bottom;
           if(fvgHigh < fvgLow)
           {
              double tmp = fvgHigh;
              fvgHigh = fvgLow;
              fvgLow = tmp;
           }

           if(rangeHigh >= fvgLow && rangeLow <= fvgHigh)
              return true;
        }

        return false;
     }

   // 🆕 Vérifier si le trade est autorisé par FVG sur le timeframe secondaire
   bool IsTradeAllowedByFVGSecondary(const double entryPrice, const double stopLoss, const bool isBuy)
     {
      if(!m_enabled || !m_useSecondary || m_detectorSecondary == NULL)
         return true;

      FVGInfo fvgs[];
      if(isBuy)
         m_detectorSecondary.GetBullishFVGs(fvgs, true);
      else
         m_detectorSecondary.GetBearishFVGs(fvgs, true);

      int fvgsCount = ArraySize(fvgs);
      
      // 🔥 WARNING si trop de FVGs
      if(fvgsCount > 20)
      {
         static datetime lastWarning = 0;
         datetime now = TimeCurrent();
         if(now - lastWarning > 3600)
         {
            Print("⚠️ [FVG Secondary] TROP DE FVGs: ", fvgsCount, " (devrait être < 20)");
            Print("⚠️ [FVG Secondary] Réduire lookbackBars dans Init()");
            lastWarning = now;
         }
      }
      
      // 🔥 PROTECTION: Limiter à 20 FVGs max pour éviter ralentissement
      int maxCheck = MathMin(fvgsCount, 20);
      
      for(int i = 0; i < maxCheck; i++)
        {
         if(!fvgs[i].IsValid) continue;

         // Normaliser top/bottom
         double fvgHigh = fvgs[i].top;
         double fvgLow  = fvgs[i].bottom;
         if(fvgHigh < fvgLow)
           {
            double t = fvgHigh;
            fvgHigh  = fvgLow;
            fvgLow   = t;
           }

         bool stopInside = (stopLoss <= fvgHigh && stopLoss >= fvgLow);
         if(stopInside)
         {
            Print("🚫 [FVG BLOCK Secondary] ", (isBuy ? "BUY" : "SELL"), 
                  " | SL: ", DoubleToString(stopLoss, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)),
                  " | FVG[", i, "] ", EnumToString(m_timeframeSecondary), ": ", 
                  DoubleToString(fvgLow, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)), 
                  "-", DoubleToString(fvgHigh, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)));
            return false;
         }
        }
      
      return true;
     }

   // 🆕 Vérifier si un FVG existe entre entry et SL sur le timeframe secondaire
   bool HasFVGBetweenEntryAndSLSecondary(const double entryPrice, const double stopLoss, const bool isBuy)
     {
        if(!m_enabled || !m_useSecondary || m_detectorSecondary == NULL)
           return false;

        double rangeHigh = MathMax(entryPrice, stopLoss);
        double rangeLow  = MathMin(entryPrice, stopLoss);

        FVGInfo fvgs[];
        if(isBuy)
           m_detectorSecondary.GetBullishFVGs(fvgs, true);
        else
           m_detectorSecondary.GetBearishFVGs(fvgs, true);

        int fvgsCount = ArraySize(fvgs);
        int maxCheck = MathMin(fvgsCount, 20);

        for(int i = 0; i < maxCheck; i++)
        {
           if(!fvgs[i].IsValid)
              continue;

           double fvgHigh = fvgs[i].top;
           double fvgLow  = fvgs[i].bottom;
           if(fvgHigh < fvgLow)
           {
              double tmp = fvgHigh;
              fvgHigh = fvgLow;
              fvgLow = tmp;
           }

           if(rangeHigh >= fvgLow && rangeLow <= fvgHigh)
              return true;
        }

        return false;
     }
  };

#endif // __FVG_TRADE_FILTER_MQH__
