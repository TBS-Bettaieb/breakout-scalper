//+------------------------------------------------------------------+
//|                                        ForexSymbolTrader.mqh     |
//|                    Classe de trading par symbole individuel Forex|
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "/../../Shared/TradingEnums.mqh"
#include "ForexCommissionManager.mqh"
#include "ForexSwingAnalyzer.mqh"
#include "ForexTrendlineManager.mqh"
#include "../../Shared/TrailingTP_System.mqh"
#include "orderManager.mqh"
#include "Filters/FVGTradeFilter.mqh"

#include "CounterManager.mqh"

//+------------------------------------------------------------------+
//| Classe ForexSymbolTrader - Gestion d'un symbole spécifique       |
//+------------------------------------------------------------------+
class ForexSymbolTrader
{
private:
   // Données du symbole
   string            m_symbol;              // Nom du symbole
   double            m_point;               // Point du symbole
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe utilisé
   
   // Magic number unique pour ce symbole
   int               m_magicNumber;
   
   // Gestion des barres
   datetime          m_lastBarTime;         // Dernière barre traitée
   

  CounterManager    m_counterMgr;          // Manager des compteurs BUY/SELL
   
   // Paramètres de trading
   double            m_riskPercent;         // Risque par symbole
   int               m_tpPoints;            // Take Profit en points
   int               m_slPoints;            // Stop Loss en points
   int               m_tslTriggerPoints;    // Points en profit avant TSL
   int               m_tslPoints;           // Trailing Stop Loss
   int               m_barsN;               // Nombre de barres pour l'analyse
   int               m_expirationBars;      // Expiration des ordres
   int               m_orderDistPoints;     // Distance des ordres
   int               m_slippagePoints;      // NEW: Slippage tolerance
   int               m_entryOffsetPoints;   // NEW: Entry offset for Stop orders
   string            m_tradeComment;        // Commentaire des trades
   
   // Objets de trading
   CTrade            m_trade;               // Objet de trading
   CPositionInfo     m_position;            // Gestion des positions
   COrderInfo        m_order;               // Gestion des ordres
   ForexCommissionManager m_commissionManager;  // Gestionnaire de commission
   ForexSwingAnalyzer m_swingAnalyzer;      // Analyseur de swing points
   ForexTrendlineManager* m_trendlineManager; // Gestionnaire des lignes TP/SL
   
   // Trailing TP
   CTrailingTP*      m_trailingTP;
   bool              m_useTrailingTP;
   string            m_customTPLevels;  // Custom TP levels string
   struct PositionTrailing {
      ulong ticket;
      CTrailingTP* trailing;
   };
   PositionTrailing  m_positionTrailings[];
   

   
   // 🆕 Risk Multiplier
   double            m_currentRiskMultiplier; // Multiplicateur de risque actuel
   
   // 🆕 Tracking des coûts par position
   struct PositionCosts {
      ulong ticket;
      double totalCostPoints;
      double breakEvenSL;
      int dynamicTrigger;
   };
   PositionCosts m_positionCosts[];
   
   // 🆕 Nouveaux paramètres dynamiques
   bool              m_useDynamicTSLTrigger;
   double            m_tslCostMultiplier;
   int               m_tslMinTriggerPoints;
   
   // 🆕 FVG Filter
   bool              m_useFvgFilter;
   FVGTradeFilter    m_fvgFilter;           // Filtre FVG pour validation des trades
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ForexSymbolTrader(string symbol, 
                     int magicNumber,
                     ENUM_TIMEFRAMES timeframe,
                     double riskPercent,
                     int tpPoints,
                     int slPoints,
                     int tslTriggerPoints,
                     int tslPoints,
                     int barsN,
                     int expirationBars,
                     int orderDistPoints,
                     int slippagePoints,
                     int entryOffsetPoints,
                     string tradeComment,
                     bool useTrailingTP = false,
                     ENUM_TRAILING_TP_MODE trailingTPMode = TRAILING_TP_STEPPED,
                     string customTPLevels = "",
                     bool useDynamicTSLTrigger = true,      // 🆕 AJOUTER
                     double tslCostMultiplier = 1.5,        // 🆕 AJOUTER
                     int tslMinTriggerPoints = 50,          // 🆕 AJOUTER
                     bool useFvgFilter = false)             // 🆕 FVG FILTER
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      m_counterMgr.Init(m_symbol, m_magicNumber, m_position);
      m_riskPercent = riskPercent;
      m_tpPoints = tpPoints;
      m_slPoints = slPoints;
      m_tslTriggerPoints = tslTriggerPoints;
      m_tslPoints = tslPoints;
      m_barsN = barsN;
      m_expirationBars = expirationBars;
      m_orderDistPoints = orderDistPoints;
      m_slippagePoints = slippagePoints;
      m_entryOffsetPoints = entryOffsetPoints;
      m_tradeComment = "BreakoutScalper_" + TimeframeToString(m_timeframe);
      
      // Initialiser les variables
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_lastBarTime = iTime(symbol, timeframe, 0);  
      
      m_currentRiskMultiplier = 1.0;
      
      // 🆕 AJOUTER APRÈS les autres initialisations:
      m_useDynamicTSLTrigger = useDynamicTSLTrigger;
      m_tslCostMultiplier = tslCostMultiplier;
      m_tslMinTriggerPoints = tslMinTriggerPoints;
      ArrayResize(m_positionCosts, 0);
      
      // 🆕 FVG Filter
      m_useFvgFilter = useFvgFilter;
      m_fvgFilter.Init(m_symbol, m_timeframe, m_useFvgFilter);
      
      // Configurer l'objet de trading
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(m_slippagePoints);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
      
      // Initialiser l'analyseur de swing
      m_swingAnalyzer = ForexSwingAnalyzer(symbol, timeframe, magicNumber, barsN);
      
      m_customTPLevels = customTPLevels;
      
      // Initialiser le Trailing TP
      m_useTrailingTP = useTrailingTP;
      if(m_useTrailingTP) {
         m_trailingTP = new CTrailingTP(trailingTPMode, customTPLevels);
         
         if(!m_trailingTP.ValidateConfiguration()) {
            Print("⚠️ Config Trailing TP invalide pour ", symbol);
            delete m_trailingTP;
            m_trailingTP = NULL;
            m_useTrailingTP = false;
         }
      } else {
         m_trailingTP = NULL;
      }
      ArrayResize(m_positionTrailings, 0);
      
      // Initialiser le gestionnaire des lignes TP/SL
      m_trendlineManager = new ForexTrendlineManager(symbol, magicNumber);
      
      Print("✓ ForexSymbolTrader initialized for ", symbol, " | Magic: ", magicNumber,
            " | Dynamic TSL: ", (m_useDynamicTSLTrigger ? "ON" : "OFF"),
            " | Cost Multiplier: ", DoubleToString(m_tslCostMultiplier, 1),
            " | FVG Filter: ", (m_useFvgFilter ? "ON" : "OFF"));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~ForexSymbolTrader()
   {
      // Cleanup Trailing TP
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].trailing != NULL) {
            delete m_positionTrailings[i].trailing;
         }
      }
      if(m_trailingTP != NULL) delete m_trailingTP;
      
      // Cleanup Trendline Manager
      if(m_trendlineManager != NULL) 
      {
         delete m_trendlineManager;
         m_trendlineManager = NULL;
      }
      
      Print("✓ ForexSymbolTrader destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Traitement principal du tick pour ce symbole                    |
   //+------------------------------------------------------------------+
   void OnTick()
   {

      CheckFvgDisqualifier();

      // Vérifier si c'est une nouvelle barre
      if(!IsNewBar()) return;
      

      m_fvgFilter.OnNewBar();
      // Note: Trading time control is now handled at the global level in the bot's OnTick()
      
      // Mettre à jour les compteurs
      UpdateCounters();
      
      // Vérifier les nouvelles positions pour créer les lignes TP/SL
      CheckForNewPositions();
      
      // Chercher des signaux de trading seulement si pas de positions/ordres existants
      if(m_counterMgr.CanSendBuyStopOrder())
      {
         // Acheter sur cassure du dernier swing high (BREAKOUT par défaut)
         double high = m_swingAnalyzer.FindHigh();
         if(high > 0)
         {
            SendBuyOrder(high);
         }
      }
      
      if(m_counterMgr.CanSendSellStopOrder())
      {
         // Vendre sur cassure du dernier swing low (BREAKOUT par défaut)
         double low = m_swingAnalyzer.FindLow();
         if(low > 0)
         {
            SendSellOrder(low);
         }
      }
   }

      //+------------------------------------------------------------------+
   //| Vérifier et annuler les ordres disqualifiés par le filtre FVG    |
   //+------------------------------------------------------------------+
   bool CheckFvgDisqualifier()
   {
      if(!m_fvgFilter.GetEnabled())
         return false;


      // Utiliser OrderManager::FindTicketViolatingPriceTolerance pour trouver un ordre dépassant le priceTolerance
      ulong violatingTicket = 0;
      bool isBuy = false;
      double priceTolerance = SymbolInfoDouble(m_symbol, SYMBOL_BID) * 0.0001; // 0.01% tolerance
      double orderPrice = 0.0;
      double orderSL = 0.0;
      if(FindTicketViolatingPriceTolerance(priceTolerance, violatingTicket, isBuy, orderPrice, orderSL))
      {
         
            bool isAllowed = m_fvgFilter.IsTradeAllowedByFVG(orderPrice, orderSL, isBuy);

            if(!isAllowed)
            {
               if(CancelOrderById(violatingTicket))
               {
               }
               else
               {
                  Logger::Error(StringFormat("❌ Erreur suppression ordre #%I64u | Erreur: %d", violatingTicket, GetLastError()));
               }

               
            }


            if(!isAllowed)
            {
               OrderManager::SendLimitOrder(BuildOrderParams(),!isBuy, orderPrice,"FVG");
            }
            
         
      }
			return false;
   }

   
     //+------------------------------------------------------------------+
  //| Retourner un ticket violant priceTolerance (+ sens isBuy)        |
  //+------------------------------------------------------------------+
  // Modifié pour retourner également le StopLoss de l'ordre (slOrder)
  bool FindTicketViolatingPriceTolerance(const double priceTolerance, ulong &ticket, bool &isBuy, double &orderPrice, double &slOrder)
  {
   ticket = 0;
   isBuy = false;
   slOrder = 0.0;
   orderPrice=0.0;
   bool shouldCheckFVG = false;
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
      orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      slOrder = OrderGetDouble(ORDER_SL);
      long orderType = OrderGetInteger(ORDER_TYPE);
      double distanceToPrice = MathAbs(currentPrice - orderPrice);

      if(distanceToPrice >= priceTolerance)
        {
         ticket = t;
               if(orderType == ORDER_TYPE_BUY_STOP)
              {
               isBuy = true;
               shouldCheckFVG = true;
              }
             else if(orderType == ORDER_TYPE_SELL_STOP)
              {
               isBuy = false;
               shouldCheckFVG = true;
              }
              if(shouldCheckFVG)
               return true;
        }
     }
   return shouldCheckFVG;
  }

   //+------------------------------------------------------------------+
   //| 🆕 Trailing Stop Loss DYNAMIQUE basé sur les coûts réels        |
   //+------------------------------------------------------------------+
   void TrailStop()
   {
      int stopLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double minDistance = stopLevel * point;

      if(stopLevel == 0)
      {
         int spread = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
         minDistance = spread * point * 2.0;
      }

      double safetyMargin = MathMax(minDistance * 0.1, 5.0 * point);
      minDistance += safetyMargin;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
         
         if(!m_position.SelectByTicket(ticket)) continue;
         
         // 🆕 Calculer ou récupérer les coûts
         double totalCostPoints, breakEvenSL;
         int effectiveTrigger;
         
         if(!GetPositionCosts(ticket, totalCostPoints, breakEvenSL, effectiveTrigger))
         {
            CalculatePositionCosts(ticket);
            if(!GetPositionCosts(ticket, totalCostPoints, breakEvenSL, effectiveTrigger))
            {
               effectiveTrigger = m_tslTriggerPoints;
            }
         }
         else
         {
            CalculatePositionCosts(ticket);
            GetPositionCosts(ticket, totalCostPoints, breakEvenSL, effectiveTrigger);
         }
         
         // 🆕 Utiliser le trigger dynamique ou fixe
         int finalTrigger = m_useDynamicTSLTrigger ? effectiveTrigger : m_tslTriggerPoints;
         
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         double profitPoints = 0;
         double newSL = 0;
         
         if(posType == POSITION_TYPE_BUY)
         {
            profitPoints = (currentPrice - openPrice) / point;
            
            if(profitPoints >= finalTrigger)
            {
               double trailingSL = currentPrice - (m_tslPoints * point);
               newSL = MathMax(breakEvenSL, trailingSL);
               
               double actualDistance = currentPrice - newSL;
               if(actualDistance < minDistance)
               {
                  newSL = currentPrice - minDistance;
               }
               
               newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
               
               if(newSL > currentSL + point)
               {
                  if(m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                  {
                     Print("📈 TSL #", ticket, " [", m_symbol, "] BUY: ", 
                           DoubleToString(currentSL, 5), " → ", DoubleToString(newSL, 5),
                           " | Profit: ", DoubleToString(profitPoints, 1), " pts",
                           " | Trigger: ", finalTrigger, " pts ",
                           (m_useDynamicTSLTrigger ? "(DYNAMIC)" : "(FIXED)"),
                           " | BE: ", DoubleToString(breakEvenSL, 5),
                           " | Costs: ", DoubleToString(totalCostPoints, 1), " pts");
                     
                     if(m_trendlineManager != NULL)
                     {
                        m_trendlineManager.UpdatePositionLines(ticket, 
                                                            PositionGetDouble(POSITION_TP), 
                                                            newSL);
                     }
                  }
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            profitPoints = (openPrice - currentPrice) / point;
            
            if(profitPoints >= finalTrigger)
            {
               double trailingSL = currentPrice + (m_tslPoints * point);
               newSL = MathMin(breakEvenSL, trailingSL);
               
               double actualDistance = newSL - currentPrice;
               if(actualDistance < minDistance)
               {
                  newSL = currentPrice + minDistance;
               }
               
               newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
               
               if((newSL < currentSL - point) || currentSL == 0)
               {
                  if(m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                  {
                     Print("📉 TSL #", ticket, " [", m_symbol, "] SELL: ", 
                           DoubleToString(currentSL, 5), " → ", DoubleToString(newSL, 5),
                           " | Profit: ", DoubleToString(profitPoints, 1), " pts",
                           " | Trigger: ", finalTrigger, " pts ",
                           (m_useDynamicTSLTrigger ? "(DYNAMIC)" : "(FIXED)"),
                           " | BE: ", DoubleToString(breakEvenSL, 5),
                           " | Costs: ", DoubleToString(totalCostPoints, 1), " pts");
                     
                     if(m_trendlineManager != NULL)
                     {
                        m_trendlineManager.UpdatePositionLines(ticket, 
                                                            PositionGetDouble(POSITION_TP), 
                                                            newSL);
                     }
                  }
               }
            }
         }
      }
   }
   
   bool CancelOrderById(const ulong ticket)
   {
      return OrderManager::CancelOrderById(BuildOrderParams(), ticket);
   }


   //+------------------------------------------------------------------+
   //| Fermer toutes les positions et ordres pour ce symbole          |
   //+------------------------------------------------------------------+
   void CloseAllOrders()
   {
      // Supprimer toutes les lignes TP/SL avant de fermer les positions
      if(m_trendlineManager != NULL)
      {
         m_trendlineManager.DeleteAllLines();
      }
      
      // Fermer toutes les positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() == m_magicNumber && m_position.Symbol() == m_symbol)
            {
               m_trade.PositionClose(m_position.Ticket());
            }
         }
      }
      
      // Supprimer tous les ordres en attente
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber && OrderGetString(ORDER_SYMBOL) == m_symbol)
            {
               m_trade.OrderDelete(ticket);
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Annuler tous les ordres pending sans fermer les positions       |
   //+------------------------------------------------------------------+
   void CancelAllPendingOrders()
   {
      int cancelledCount = 0;
      
      // Supprimer uniquement les ordres en attente (ne pas toucher aux positions ouvertes)
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber && OrderGetString(ORDER_SYMBOL) == m_symbol)
            {
               if(m_trade.OrderDelete(ticket))
               {
                  cancelledCount++;
               }
            }
         }
      }
      
      // Log seulement si des ordres ont été annulés
      if(cancelledCount > 0)
      {
         Print("🚫 ", m_symbol, ": ", cancelledCount, " pending order(s) cancelled (trading paused)");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut pour l'affichage             |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
     return m_counterMgr.GetStatusInfo();
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le profit total pour ce symbole                         |
   //+------------------------------------------------------------------+
   double GetTotalProfit()
   {
          
      return m_counterMgr.GetTotalProfit();
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total de positions                            |
   //+------------------------------------------------------------------+
   int GetTotalPositions()
   {
      return m_counterMgr.GetTotalPositions();
   }
   
   //+------------------------------------------------------------------+
   //| Rafraîchir l'affichage des lignes swing                          |
   //+------------------------------------------------------------------+
   void RefreshSwingDisplay()
   {
      m_swingAnalyzer.RefreshSwingDisplay();
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Définir le multiplicateur actuel                              |
   //+------------------------------------------------------------------+
   void SetRiskMultiplier(double multiplier)
   {
      m_currentRiskMultiplier = MathMax(0.1, MathMin(10.0, multiplier));
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Obtenir le multiplicateur actuel                              |
   //+------------------------------------------------------------------+
   double GetRiskMultiplier()
   {
      return m_currentRiskMultiplier;
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Calculer et stocker les coûts d'une position                 |
   //+------------------------------------------------------------------+
   void CalculatePositionCosts(ulong ticket)
   {
      if(!m_position.SelectByTicket(ticket)) return;
      
      // Calculer les coûts
      double commission = m_commissionManager.GetCommission(m_position);
      double commissionPoints = m_commissionManager.CalculateCommissionInPoints(
          m_position.Symbol(), 
          commission, 
          m_position.Volume()
      );
      
      double spreadPoints = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      
      double swap = PositionGetDouble(POSITION_SWAP);
      double swapPoints = 0;
      if(swap < 0)
      {
         double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
         
         if(tickValue > 0 && volume > 0)
         {
            swapPoints = MathAbs((swap / tickValue / volume) * (tickSize / m_point));
         }
      }
      
      double totalCostPoints = commissionPoints + spreadPoints + swapPoints;
      
      // Calculer le breakeven SL
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double breakEvenSL = (posType == POSITION_TYPE_BUY) 
         ? openPrice + (totalCostPoints * m_point)
         : openPrice - (totalCostPoints * m_point);
      
      // Calculer le trigger dynamique
      int dynamicTrigger = (int)(totalCostPoints * m_tslCostMultiplier);
      dynamicTrigger = MathMax(dynamicTrigger, m_tslMinTriggerPoints);
      
      // Chercher si déjà existant
      int index = -1;
      for(int i = 0; i < ArraySize(m_positionCosts); i++)
      {
         if(m_positionCosts[i].ticket == ticket)
         {
            index = i;
            break;
         }
      }
      
      // Ajouter ou mettre à jour
      if(index == -1)
      {
         int size = ArraySize(m_positionCosts);
         ArrayResize(m_positionCosts, size + 1);
         index = size;
         m_positionCosts[index].ticket = ticket;
      }
      
      m_positionCosts[index].totalCostPoints = totalCostPoints;
      m_positionCosts[index].breakEvenSL = breakEvenSL;
      m_positionCosts[index].dynamicTrigger = dynamicTrigger;
      
      Print("💰 #", ticket, " [", m_symbol, "] Costs: ", DoubleToString(totalCostPoints, 1), " pts",
            " | BE: ", DoubleToString(breakEvenSL, 5),
            " | Dynamic Trigger: ", dynamicTrigger, " pts");
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Obtenir les informations de coûts d'une position             |
   //+------------------------------------------------------------------+
   bool GetPositionCosts(ulong ticket, double &totalCostPoints, double &breakEvenSL, int &dynamicTrigger)
   {
      for(int i = 0; i < ArraySize(m_positionCosts); i++)
      {
         if(m_positionCosts[i].ticket == ticket)
         {
            totalCostPoints = m_positionCosts[i].totalCostPoints;
            breakEvenSL = m_positionCosts[i].breakEvenSL;
            dynamicTrigger = m_positionCosts[i].dynamicTrigger;
            return true;
         }
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Nettoyer les coûts d'une position fermée                     |
   //+------------------------------------------------------------------+
   void RemovePositionCosts(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_positionCosts); i++)
      {
         if(m_positionCosts[i].ticket == ticket)
         {
            for(int j = i; j < ArraySize(m_positionCosts) - 1; j++)
            {
               m_positionCosts[j] = m_positionCosts[j + 1];
            }
            ArrayResize(m_positionCosts, ArraySize(m_positionCosts) - 1);
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Ajuster le multiplicateur + ordres pending                    |
   //+------------------------------------------------------------------+
   int AdjustPositionSizes(double newMultiplier)
   {
      // Valider le multiplicateur (0.1 à 10.0)
      double validMultiplier = MathMax(0.1, MathMin(10.0, newMultiplier));
      
      // Sauvegarder l'ancien multiplicateur pour le calcul
      double oldMultiplier = m_currentRiskMultiplier;
      
      // ✅ Mettre à jour le multiplicateur actuel
      m_currentRiskMultiplier = validMultiplier;
      
      int adjustedOrders = 0;
      
      // ✅ Ajuster les ordres pending existants
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(!OrderSelect(ticket)) continue;
         
         // Vérifier que c'est notre ordre
         if(OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
         if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
         
         // Récupérer les infos de l'ordre
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         double orderSL = OrderGetDouble(ORDER_SL);
         double orderTP = OrderGetDouble(ORDER_TP);
         double currentVolume = OrderGetDouble(ORDER_VOLUME_CURRENT);
         datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         
         // Calculer le nouveau volume
         // Hypothèse: l'ordre a été créé avec l'ancien multiplicateur
         double baseVolume = (oldMultiplier > 0) ? (currentVolume / oldMultiplier) : currentVolume;
         double newVolume = baseVolume * validMultiplier;
         
         // Normaliser selon les contraintes du broker
         double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
         double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         newVolume = MathFloor(newVolume / lotStep) * lotStep;
         newVolume = MathMax(minLot, MathMin(maxLot, newVolume));
         newVolume = NormalizeDouble(newVolume, 2);
         
         // Si le volume n'a pas changé significativement, passer
         if(MathAbs(newVolume - currentVolume) < lotStep) continue;
         
         // ✅ Supprimer l'ancien ordre
         if(!m_trade.OrderDelete(ticket))
         {
            Print("❌ [", m_symbol, "] Impossible de supprimer ordre #", ticket, " | Erreur: ", GetLastError());
            continue;
         }
         
         // ✅ Recréer l'ordre avec le nouveau volume
         bool success = false;
         ulong newTicket = 0;
         
         switch(orderType)
         {
            case ORDER_TYPE_BUY_STOP:
               success = m_trade.BuyStop(newVolume, orderPrice, m_symbol, orderSL, orderTP, 
                                        ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            case ORDER_TYPE_SELL_STOP:
               success = m_trade.SellStop(newVolume, orderPrice, m_symbol, orderSL, orderTP,
                                         ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            case ORDER_TYPE_BUY_LIMIT:
               success = m_trade.BuyLimit(newVolume, orderPrice, m_symbol, orderSL, orderTP,
                                         ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            case ORDER_TYPE_SELL_LIMIT:
               success = m_trade.SellLimit(newVolume, orderPrice, m_symbol, orderSL, orderTP,
                                          ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            default:
               // Ignorer les autres types (Market orders ne devraient pas être ici)
               continue;
         }
         
         if(success)
         {
            Print("📝 [", m_symbol, "] Ordre #", ticket, " → #", newTicket, " | Volume: ", 
                  DoubleToString(currentVolume, 2), " → ", DoubleToString(newVolume, 2), " lots");
            adjustedOrders++;
         }
         else
         {
            Print("❌ [", m_symbol, "] Échec recréation ordre (", EnumToString(orderType), ") | ",
                  "Prix: ", DoubleToString(orderPrice, _Digits), " | Volume: ", DoubleToString(newVolume, 2), " | ",
                  "Erreur: ", GetLastError());
         }
      }
      
      // Log du résultat final
      if(adjustedOrders > 0)
      {
         Print("📊 [", m_symbol, "] Multiplicateur: ", DoubleToString(oldMultiplier, 2), 
               " → ", DoubleToString(validMultiplier, 2), " | ", adjustedOrders, " ordre(s) ajusté(s)");
      }
      else
      {
         Print("📊 [", m_symbol, "] Multiplicateur: ", DoubleToString(oldMultiplier, 2),
               " → ", DoubleToString(validMultiplier, 2), " | Aucun ordre pending à ajuster");
      }
      
      return adjustedOrders;
   }
   
   //+------------------------------------------------------------------+
   //| Appelé quand une position est ouverte                           |
   //+------------------------------------------------------------------+
   void OnPositionOpened(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return;
      
      // 🆕 AJOUTER CETTE LIGNE AU DÉBUT:
      CalculatePositionCosts(ticket);
      
      // Créer les lignes TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         double tpPrice = PositionGetDouble(POSITION_TP);
         double slPrice = PositionGetDouble(POSITION_SL);
         m_trendlineManager.CreatePositionLines(ticket, tpPrice, slPrice);
      }
      
      // Gestion du trailing TP (logique existante)
      if(!m_useTrailingTP || m_trailingTP == NULL) return;
      
      // Vérifier que ce n'est pas déjà tracké
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].ticket == ticket) return;
      }
      
      // MODIFIER: Passer customLevels
      CTrailingTP* newTrailing = new CTrailingTP(
         m_trailingTP.GetMode(),
         m_trailingTP.GetCustomLevelsString()  // <-- AJOUTER
      );
      
      newTrailing.Initialize(
         PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_SL),
         PositionGetDouble(POSITION_TP),
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY
      );
      
      int size = ArraySize(m_positionTrailings);
      ArrayResize(m_positionTrailings, size + 1);
      m_positionTrailings[size].ticket = ticket;
      m_positionTrailings[size].trailing = newTrailing;
      
      Print("🎯 Trailing TP #", ticket, " | Mode: ", EnumToString(m_trailingTP.GetMode()),
            " | Niveaux: ", newTrailing.GetLevelCount());
   }
   
   //+------------------------------------------------------------------+
   //| Appelé quand une position est fermée                            |
   //+------------------------------------------------------------------+
   void OnPositionClosed(ulong ticket)
   {
      // 🆕 AJOUTER CETTE LIGNE AU DÉBUT:
      RemovePositionCosts(ticket);
      
      // Supprimer les lignes TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         m_trendlineManager.DeletePositionLines(ticket);
      }
      
      // Gestion du trailing TP (logique existante)
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].ticket == ticket) {
            if(m_positionTrailings[i].trailing != NULL) {
               delete m_positionTrailings[i].trailing;
            }
            for(int j = i; j < ArraySize(m_positionTrailings) - 1; j++) {
               m_positionTrailings[j] = m_positionTrailings[j + 1];
            }
            ArrayResize(m_positionTrailings, ArraySize(m_positionTrailings) - 1);
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Détecter les nouvelles positions                                 |
   //+------------------------------------------------------------------+
   void CheckForNewPositions()
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != m_magicNumber) continue;
         if(m_position.Symbol() != m_symbol) continue;
         
         ulong ticket = m_position.Ticket();
         
         bool alreadyTracked = false;
         for(int j = 0; j < ArraySize(m_positionTrailings); j++)
         {
            if(m_positionTrailings[j].ticket == ticket)
            {
               alreadyTracked = true;
               break;
            }
         }
         
         if(!alreadyTracked) OnPositionOpened(ticket);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Appliquer le Trailing TP à toutes les positions                 |
   //+------------------------------------------------------------------+
   void ApplyTrailingTP()
   {
      if(!m_useTrailingTP) return;
      
      CheckForNewPositions();
      
      for(int i = ArraySize(m_positionTrailings) - 1; i >= 0; i--) {
         ulong ticket = m_positionTrailings[i].ticket;
         
         if(!PositionSelectByTicket(ticket)) {
            OnPositionClosed(ticket);
            continue;
         }
         
         double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
            ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
            : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         
         double newSL, newTP;
         if(m_positionTrailings[i].trailing.Update(currentPrice, newSL, newTP)) {
            if(newSL > 0 && newTP > 0) {
               if(m_trade.PositionModify(ticket, newSL, newTP))
               {
                  // Mettre à jour les lignes TP/SL après modification du Trailing TP
                  if(m_trendlineManager != NULL)
                  {
                     m_trendlineManager.UpdatePositionLines(ticket, newTP, newSL);
                  }
               }
            }
         }
      }
   }
   
private:
   //+------------------------------------------------------------------+
   //| Vérifier si c'est une nouvelle barre                            |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      
      if(m_lastBarTime != currentTime)
      {
         m_lastBarTime = currentTime;
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Calculer la taille du lot basée sur le risque                   |
   //+------------------------------------------------------------------+
   OrderParams BuildOrderParams()
   {
      return OrderManager::CreateParams(
         m_symbol,
         m_timeframe,
			m_magicNumber,
         m_point,
         m_tpPoints,
         m_slPoints,
         m_entryOffsetPoints,
         m_orderDistPoints,
         m_expirationBars,
         m_riskPercent,
         m_currentRiskMultiplier,
         m_tradeComment,
         m_trade
      );
   }
   
   
   //+------------------------------------------------------------------+
   //| Envoyer un ordre Buy (Stop ou Limit selon la stratégie)         |
   //+------------------------------------------------------------------+
   void SendBuyOrder(double entry)
   {
      OrderManager::SendBuyOrder(BuildOrderParams(), entry);
   }
   
   //+------------------------------------------------------------------+
   //| Envoyer un ordre Sell (Stop ou Limit selon la stratégie)         |
   //+------------------------------------------------------------------+
   void SendSellOrder(double entry)
   {
      OrderManager::SendSellOrder(BuildOrderParams(), entry);
   }
   
   //+------------------------------------------------------------------+
   //| Convertir un timeframe en string                                |
   //+------------------------------------------------------------------+
   string TimeframeToString(ENUM_TIMEFRAMES tf)
   {
      switch(tf)
      {
         case PERIOD_M1:  return "M1";
         case PERIOD_M5:  return "M5";
         case PERIOD_M15: return "M15";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H4:  return "H4";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         case PERIOD_MN1: return "MN1";
         default:         return "UNKNOWN";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les compteurs de positions/ordres                |
   //+------------------------------------------------------------------+
   void UpdateCounters()
   {
      m_counterMgr.Recalculate();
   }
   
};
