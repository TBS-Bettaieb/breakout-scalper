//+------------------------------------------------------------------+
//|                                              TradingEnums.mqh     |
//|                              Énumérations pour le trading         |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

// (Removed ENUM_STRATEGY_MODE: strategy now defaults to BREAKOUT behavior everywhere)

//+------------------------------------------------------------------+
//| Custom Order Types for Trading                                  |
//+------------------------------------------------------------------+
enum ENUM_CUSTOM_ORDER_TYPE
{
   CUSTOM_ORDER_BUY_STOP,      // Achat au-dessus du prix actuel
   CUSTOM_ORDER_SELL_STOP,     // Vente en-dessous du prix actuel
   CUSTOM_ORDER_BUY_LIMIT,     // Achat en-dessous du prix actuel
   CUSTOM_ORDER_SELL_LIMIT     // Vente au-dessus du prix actuel
};

//+------------------------------------------------------------------+
//| Swing Point Types                                               |
//+------------------------------------------------------------------+
enum ENUM_SWING_TYPE
{
   SWING_HIGH,          // Point haut (résistance)
   SWING_LOW            // Point bas (support)
};

//+------------------------------------------------------------------+
//| Risk Management Modes                                           |
//+------------------------------------------------------------------+
enum ENUM_RISK_MODE
{
   RISK_FIXED_LOT,      // Lot fixe
   RISK_PERCENTAGE,     // Pourcentage du capital
   RISK_POINTS          // Basé sur les points de risque
};

//+------------------------------------------------------------------+
//| Separator Enumeration                                            |
//+------------------------------------------------------------------+
enum ENUM_SEPARATOR {
   COMMA=0,            // Comma (,)
   SEMICOLON=1         // Semicolon (;)
};

//+------------------------------------------------------------------+
//| Swing Detection Mode                                             |
//+------------------------------------------------------------------+
enum ENUM_SWING_DETECTION_MODE
{
   SWING_DETECTION_WICK,   // Mode mèche (utilise high/low des mèches)
   SWING_DETECTION_BODY    // Mode body (utilise max/min de open/close)
};