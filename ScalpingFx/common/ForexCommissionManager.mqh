//+------------------------------------------------------------------+
//|                                        ForexCommissionManager.mqh|
//|                    Gestionnaire de commissions pour le Forex    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Classe helper pour gérer les commissions                         |
//+------------------------------------------------------------------+
class ForexCommissionManager
{
private:
    // Cache des commissions par broker/symbole
    double m_defaultCommissionPerLot;
    
public:
    ForexCommissionManager() : m_defaultCommissionPerLot(3.0) {}
    
    // Récupère la commission réelle d'une position
    double GetPositionCommission(ulong ticket)
    {
        // Essayer depuis HistorySelectByPosition
        if(HistorySelectByPosition(ticket))
        {
            for(int i = 0; i < HistoryDealsTotal(); i++)
            {
                ulong dealTicket = HistoryDealGetTicket(i);
                if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket)
                {
                    return HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                }
            }
        }
        return 0;
    }
    
    // Récupère ou estime la commission
    double GetCommission(CPositionInfo &position)
    {
        // 1. Essayer depuis la position
        double comm = position.Commission();
        if(comm != 0) return MathAbs(comm);
        
        // 2. Essayer depuis l'historique
        comm = GetPositionCommission(position.Ticket());
        if(comm != 0) return MathAbs(comm);
        
        // 3. Estimer
        return m_defaultCommissionPerLot * position.Volume();
    }
    
    // Calcule les points équivalents à une commission
    double CalculateCommissionInPoints(string symbol, double commission, double lots)
    {
        // Vérifications
        if(lots <= 0) return 0;
        if(commission == 0) return 0;
        
        // Informations du symbole
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
        
        if(tickValue == 0 || tickSize == 0) 
        {
            Logger::Error("Erreur: impossible de récupérer les infos du symbole " + symbol);
            return 0;
        }
        
        // Valeur monétaire d'un point
        double pointValue = (tickValue / tickSize) * point;
        
        // Commission en points = Commission totale / (Valeur d'un point × Volume)
        double commissionPoints = MathAbs(commission) / (pointValue * lots);
        
        return 2*commissionPoints;
    }
};
