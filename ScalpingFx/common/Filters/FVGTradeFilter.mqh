#ifndef __FVG_TRADE_FILTER_MQH__
#define __FVG_TRADE_FILTER_MQH__

#include "../../../Shared/FVGDetector.mqh"

class FVGTradeFilter
  {
private:
   bool             m_enabled;
   FVGDetector*     m_detector;
   string           m_symbol;
   ENUM_TIMEFRAMES  m_timeframe;
   double           m_radiusPts;
   datetime         m_lastBarTime; // cache de nouvelle bougie

public:
   FVGTradeFilter()
     {
      m_enabled   = false;
      m_detector  = NULL;
      m_symbol    = "";
      m_timeframe = PERIOD_CURRENT;
      m_radiusPts = 500.0;
      m_lastBarTime = 0;
     }

   ~FVGTradeFilter()
     {
      if(m_detector != NULL)
        {
         delete m_detector;
         m_detector = NULL;
        }
     }

   void Init(const string symbol, const ENUM_TIMEFRAMES tf, const bool enabled)
     {
      m_symbol    = symbol;
      m_timeframe = tf;
      m_enabled   = enabled;
      if(!m_enabled) return;

      if(m_detector != NULL)
        {
         delete m_detector;
         m_detector = NULL;
        }
      m_detector = new FVGDetector();

      FVGConfig cfg;
      cfg.atrPeriod        = 14;
      cfg.minGapATRPercent = 5.0;
      cfg.epsilonPts        = 0.1;
      cfg.invalidatePct    = 30.0;
      cfg.mode             = WICK_TOUCH;
      cfg.lookbackBars     = 300;
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
      m_lastBarTime = iTime(m_symbol, m_timeframe, 0);
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

      // Ne recalculer que si nouvelle bougie
      datetime cur = iTime(m_symbol, m_timeframe, 0);
      if(cur != m_lastBarTime || m_lastBarTime == 0)
        {
         m_detector.ProcessTimeframe(m_timeframe);
         m_detector.UpdateInvalidation(m_timeframe);
         m_lastBarTime = cur;
        }

      FVGInfo fvgs[];
      if(isBuy)
         m_detector.GetBullishFVGs(fvgs, true);
      else
         m_detector.GetBearishFVGs(fvgs, true);

      for(int i = 0; i < ArraySize(fvgs); i++)
        {
         if(!fvgs[i].IsValid) continue;

         double fvgHigh = fvgs[i].top;
         double fvgLow  = fvgs[i].bottom;
         if(fvgHigh < fvgLow)
           {
            double t = fvgHigh;
            fvgHigh  = fvgLow;
            fvgLow   = t;
           }

         bool stopInside = (stopLoss <= fvgHigh && stopLoss >= fvgLow);
         if(stopInside) return false;
        }
      return true;
     }
  };

#endif // __FVG_TRADE_FILTER_MQH__
