//+------------------------------------------------------------------+
//|                                         ForexSwingAnalyzer.mqh   |
//|                    Analyseur de points swing pour le Forex      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Classe pour analyser les points swing                           |
//+------------------------------------------------------------------+
class ForexSwingAnalyzer
{
private:
   // Données du symbole
   string            m_symbol;              // Nom du symbole
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe utilisé
   int               m_magicNumber;         // Magic number pour identification
   int               m_barsN;               // Nombre de barres pour l'analyse
   
   // Historique des points détectés
   double            m_lastHighPoints[3];   // 3 derniers high points
   double            m_lastLowPoints[3];    // 3 derniers low points
   datetime          m_lastHighTimes[3];    // Times des high points
   datetime          m_lastLowTimes[3];     // Times des low points
   
   // Point du symbole
   double            m_point;               // Point du symbole
   
   // Mode de détection
   ENUM_SWING_DETECTION_MODE m_detectionMode; // Mode de détection (WICK ou BODY)
   
public:
   //+------------------------------------------------------------------+
   //| Default Constructor                                              |
   //+------------------------------------------------------------------+
   ForexSwingAnalyzer()
   {
      m_symbol = "";
      m_timeframe = PERIOD_M5;
      m_magicNumber = 0;
      m_barsN = 5;
      m_point = 0.00001;
      m_detectionMode = SWING_DETECTION_WICK;
      
      // Initialiser les arrays de points
      ArrayInitialize(m_lastHighPoints, 0);
      ArrayInitialize(m_lastLowPoints, 0);
      ArrayInitialize(m_lastHighTimes, 0);
      ArrayInitialize(m_lastLowTimes, 0);
   }
   
   //+------------------------------------------------------------------+
   //| Constructor with parameters                                      |
   //+------------------------------------------------------------------+
   ForexSwingAnalyzer(string symbol, ENUM_TIMEFRAMES timeframe, int magicNumber, int barsN, ENUM_SWING_DETECTION_MODE detectionMode = SWING_DETECTION_WICK)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_magicNumber = magicNumber;
      m_barsN = barsN;
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_detectionMode = detectionMode;
      
      // Initialiser les arrays de points
      ArrayInitialize(m_lastHighPoints, 0);
      ArrayInitialize(m_lastLowPoints, 0);
      ArrayInitialize(m_lastHighTimes, 0);
      ArrayInitialize(m_lastLowTimes, 0);
      
      Logger::Success("✓ ForexSwingAnalyzer initialized for " + symbol + " (Mode: " + EnumToString(detectionMode) + ")");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~ForexSwingAnalyzer()
   {
      DeleteSwingLines();
      Logger::Success("✓ ForexSwingAnalyzer destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Trouver le plus haut dans la période de lookback               |
   //+------------------------------------------------------------------+
   double FindHigh()
   {
      // Tentative 1 : Recherche sur le timeframe actuel
      Logger::Debug("🔍 FindHigh: Searching on current timeframe " + EnumToString(m_timeframe));
      double result = SearchHighOnTimeframe(m_timeframe);
      
      if(result > 0)
      {
         Logger::Debug("✓ FindHigh: Found high point at " + DoubleToString(result, _Digits) + " on " + EnumToString(m_timeframe));
         return result;
      }
      
      // Tentative 2 : Recherche sur le timeframe supérieur (+1 niveau)
      ENUM_TIMEFRAMES nextTF1 = GetNextHigherTimeframe(m_timeframe);
      if(nextTF1 != PERIOD_CURRENT)
      {
         Logger::Debug("🔍 FindHigh: No point found. Trying higher timeframe " + EnumToString(nextTF1));
         result = SearchHighOnTimeframe(nextTF1);
         
         if(result > 0)
         {
            Logger::Debug("✓ FindHigh: Found high point at " + DoubleToString(result, _Digits) + " on " + EnumToString(nextTF1));
            return result;
         }
      }
      
      // Tentative 3 : Recherche sur le timeframe encore supérieur (+2 niveaux)
      ENUM_TIMEFRAMES nextTF2 = GetNextHigherTimeframe(nextTF1);
      if(nextTF2 != PERIOD_CURRENT && nextTF1 != PERIOD_CURRENT)
      {
         Logger::Debug("🔍 FindHigh: Still no point. Trying even higher timeframe " + EnumToString(nextTF2));
         result = SearchHighOnTimeframe(nextTF2);
         
         if(result > 0)
         {
            Logger::Debug("✓ FindHigh: Found high point at " + DoubleToString(result, _Digits) + " on " + EnumToString(nextTF2));
            return result;
         }
      }
      
      // Aucun point trouvé même après 3 tentatives
      Logger::Warning("✗ FindHigh: No high point found even on higher timeframes");
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Trouver le plus bas dans la période de lookback                |
   //+------------------------------------------------------------------+
   double FindLow()
   {
      // Tentative 1 : Recherche sur le timeframe actuel
      Logger::Debug("🔍 FindLow: Searching on current timeframe " + EnumToString(m_timeframe));
      double result = SearchLowOnTimeframe(m_timeframe);
      
      if(result > 0)
      {
         Logger::Debug("✓ FindLow: Found low point at " + DoubleToString(result, _Digits) + " on " + EnumToString(m_timeframe));
         return result;
      }
      
      // Tentative 2 : Recherche sur le timeframe supérieur (+1 niveau)
      ENUM_TIMEFRAMES nextTF1 = GetNextHigherTimeframe(m_timeframe);
      if(nextTF1 != PERIOD_CURRENT)
      {
         Logger::Debug("🔍 FindLow: No point found. Trying higher timeframe " + EnumToString(nextTF1));
         result = SearchLowOnTimeframe(nextTF1);
         
         if(result > 0)
         {
            Logger::Debug("✓ FindLow: Found low point at " + DoubleToString(result, _Digits) + " on " + EnumToString(nextTF1));
            return result;
         }
      }
      
      // Tentative 3 : Recherche sur le timeframe encore supérieur (+2 niveaux)
      ENUM_TIMEFRAMES nextTF2 = GetNextHigherTimeframe(nextTF1);
      if(nextTF2 != PERIOD_CURRENT && nextTF1 != PERIOD_CURRENT)
      {
         Logger::Debug("🔍 FindLow: Still no point. Trying even higher timeframe " + EnumToString(nextTF2));
         result = SearchLowOnTimeframe(nextTF2);
         
         if(result > 0)
         {
            Logger::Debug("✓ FindLow: Found low point at " + DoubleToString(result, _Digits) + " on " + EnumToString(nextTF2));
            return result;
         }
      }
      
      // Aucun point trouvé même après 3 tentatives
      Logger::Warning("✗ FindLow: No low point found even on higher timeframes");
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Rafraîchir l'affichage des lignes swing                          |
   //+------------------------------------------------------------------+
   void RefreshSwingDisplay()
   {
      DrawSwingPoints();
   }
   
private:
   //+------------------------------------------------------------------+
   //| Supprimer un point d'un array                                   |
   //+------------------------------------------------------------------+
   void RemovePointFromArray(double price, double &pointsArray[], datetime &timesArray[], string prefix)
   {
      for(int i = 0; i < 3; i++)
      {
         if(MathAbs(pointsArray[i] - price) < m_point * 10)
         {
            // Supprimer la ligne graphique correspondante
            string objName = prefix + "_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
            ObjectDelete(0, objName);
            
            // Réinitialiser les valeurs
            pointsArray[i] = 0;
            timesArray[i] = 0;
            return;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Ajouter un high point à l'historique                             |
   //+------------------------------------------------------------------+
   void AddHighPoint(double price, datetime time)
   {
      // Vérifier d'abord si ce point existe dans les low points et le supprimer
      RemovePointFromArray(price, m_lastLowPoints, m_lastLowTimes, "SwingLow");
      
      // Vérifier si ce point n'est pas déjà dans l'historique des highs
      for(int i = 0; i < 3; i++)
      {
         if(MathAbs(m_lastHighPoints[i] - price) < m_point * 10) // Tolérance de 10 points
            return;
      }
      
      // Décaler les anciens points
      for(int i = 2; i > 0; i--)
      {
         m_lastHighPoints[i] = m_lastHighPoints[i-1];
         m_lastHighTimes[i] = m_lastHighTimes[i-1];
      }
      
      // Ajouter le nouveau point
      m_lastHighPoints[0] = price;
      m_lastHighTimes[0] = time;
      
      // Redessiner les lignes
      DrawSwingPoints();
   }
   
   //+------------------------------------------------------------------+
   //| Ajouter un low point à l'historique                              |
   //+------------------------------------------------------------------+
   void AddLowPoint(double price, datetime time)
   {
      // Vérifier d'abord si ce point existe dans les high points et le supprimer
      RemovePointFromArray(price, m_lastHighPoints, m_lastHighTimes, "SwingHigh");
      
      // Vérifier si ce point n'est pas déjà dans l'historique des lows
      for(int i = 0; i < 3; i++)
      {
         if(MathAbs(m_lastLowPoints[i] - price) < m_point * 10) // Tolérance de 10 points
            return;
      }
      
      // Décaler les anciens points
      for(int i = 2; i > 0; i--)
      {
         m_lastLowPoints[i] = m_lastLowPoints[i-1];
         m_lastLowTimes[i] = m_lastLowTimes[i-1];
      }
      
      // Ajouter le nouveau point
      m_lastLowPoints[0] = price;
      m_lastLowTimes[0] = time;
      
      // Redessiner les lignes
      DrawSwingPoints();
   }
   
   //+------------------------------------------------------------------+
   //| Dessiner les points swing sur le graphique                       |
   //+------------------------------------------------------------------+
   void DrawSwingPoints()
   {
      // Supprimer les anciennes lignes
      DeleteSwingLines();
      
      // Dessiner les high points (lignes vertes)
      for(int i = 0; i < 3; i++)
      {
         if(m_lastHighPoints[i] > 0)
         {
            string name = "SwingHigh_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
            
            // Créer une ligne avec début et fin définis (50 barres de longueur)
            datetime start_time = m_lastHighTimes[i];
            datetime end_time = start_time + PeriodSeconds(m_timeframe) * 50;
            
            ObjectCreate(0, name, OBJ_TREND, 0, start_time, m_lastHighPoints[i], end_time, m_lastHighPoints[i]);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLimeGreen);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); // Ne pas étendre à l'infini
            ObjectSetString(0, name, OBJPROP_TOOLTIP, m_symbol + " High: " + DoubleToString(m_lastHighPoints[i], _Digits));
         }
      }
      
      // Dessiner les low points (lignes rouges)
      for(int i = 0; i < 3; i++)
      {
         if(m_lastLowPoints[i] > 0)
         {
            string name = "SwingLow_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
            
            // Créer une ligne avec début et fin définis (50 barres de longueur)
            datetime start_time = m_lastLowTimes[i];
            datetime end_time = start_time + PeriodSeconds(m_timeframe) * 50;
            
            ObjectCreate(0, name, OBJ_TREND, 0, start_time, m_lastLowPoints[i], end_time, m_lastLowPoints[i]);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); // Ne pas étendre à l'infini
            ObjectSetString(0, name, OBJPROP_TOOLTIP, m_symbol + " Low: " + DoubleToString(m_lastLowPoints[i], _Digits));
         }
      }
      
      // Rafraîchir le graphique
      ChartRedraw(0);
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer toutes les lignes swing                                |
   //+------------------------------------------------------------------+
   void DeleteSwingLines()
   {
      // Supprimer les high lines
      for(int i = 0; i < 3; i++)
      {
         string nameHigh = "SwingHigh_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
         ObjectDelete(0, nameHigh);
         
         string nameLow = "SwingLow_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
         ObjectDelete(0, nameLow);
      }
      
      ChartRedraw(0);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le timeframe supérieur suivant                          |
   //+------------------------------------------------------------------+
   ENUM_TIMEFRAMES GetNextHigherTimeframe(ENUM_TIMEFRAMES current)
   {
      switch(current)
      {
         case PERIOD_M1:  return PERIOD_M5;
         case PERIOD_M5:  return PERIOD_M15;
         case PERIOD_M15: return PERIOD_M30;
         case PERIOD_M30: return PERIOD_H1;
         case PERIOD_H1:  return PERIOD_H4;
         case PERIOD_H4:  return PERIOD_D1;
         case PERIOD_D1:  return PERIOD_W1;
         case PERIOD_W1:  return PERIOD_MN1;
         default:         return PERIOD_CURRENT;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Rechercher un high point sur un timeframe spécifique            |
   //+------------------------------------------------------------------+
   double SearchHighOnTimeframe(ENUM_TIMEFRAMES timeframe)
   {
      double highestHigh = 0;
      
      for(int i = 0; i < 200; i++)
      {
         // TOUJOURS détecter la barre avec le mode WICK (iHighest sur MODE_HIGH)
         double high = iHigh(m_symbol, timeframe, i);
         
         if(i > m_barsN && iHighest(m_symbol, timeframe, MODE_HIGH, m_barsN*2+1, i-m_barsN) == i)
         {
            if(high > highestHigh)
            {
               // Barre détectée : selon le mode, retourner high ou max(open, close)
               double result;
               if(m_detectionMode == SWING_DETECTION_BODY)
               {
                  // Mode body : retourner max(open, close) de la barre détectée
                  double open = iOpen(m_symbol, timeframe, i);
                  double close = iClose(m_symbol, timeframe, i);
                  result = MathMax(open, close);
               }
               else
               {
                  // Mode meche : retourner high de la barre détectée
                  result = high;
               }
               
               // Stocker le point détecté
               datetime barTime = iTime(m_symbol, timeframe, i);
               AddHighPoint(result, barTime);
               
               return result;
            }
         }
         
         highestHigh = MathMax(high, highestHigh);
      }
      
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Rechercher un low point sur un timeframe spécifique             |
   //+------------------------------------------------------------------+
   double SearchLowOnTimeframe(ENUM_TIMEFRAMES timeframe)
   {
      double lowestLow = DBL_MAX;
      
      for(int i = 0; i < 200; i++)
      {
         // TOUJOURS détecter la barre avec le mode WICK (iLowest sur MODE_LOW)
         double low = iLow(m_symbol, timeframe, i);
         
         if(i > m_barsN && iLowest(m_symbol, timeframe, MODE_LOW, m_barsN*2+1, i-m_barsN) == i)
         {
            if(low < lowestLow)
            {
               // Barre détectée : selon le mode, retourner low ou min(open, close)
               double result;
               if(m_detectionMode == SWING_DETECTION_BODY)
               {
                  // Mode body : retourner min(open, close) de la barre détectée
                  double open = iOpen(m_symbol, timeframe, i);
                  double close = iClose(m_symbol, timeframe, i);
                  result = MathMin(open, close);
               }
               else
               {
                  // Mode meche : retourner low de la barre détectée
                  result = low;
               }
               
               // Stocker le point détecté
               datetime barTime = iTime(m_symbol, timeframe, i);
               AddLowPoint(result, barTime);
               
               return result;
            }
         }
         
         lowestLow = MathMin(low, lowestLow);
      }
      
      return -1;
   }
};
