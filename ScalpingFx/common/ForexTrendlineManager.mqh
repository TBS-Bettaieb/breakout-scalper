//+------------------------------------------------------------------+
//|                                        ForexTrendlineManager.mqh |
//|                      Gestionnaire des lignes de TP/SL visuelles  |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Structure pour stocker les références des lignes               |
//+------------------------------------------------------------------+
struct TrendlineRefs
{
   ulong  ticket;
   string tpLineName;
   string slLineName;
};

//+------------------------------------------------------------------+
//| Classe ForexTrendlineManager - Gestion des lignes TP/SL        |
//+------------------------------------------------------------------+
class ForexTrendlineManager
{
private:
   string            m_symbol;              // Symbole principal
   int               m_magicNumber;         // Magic number pour identification
   TrendlineRefs     m_trendlines[];        // Tableau des références des lignes
   long              m_chartId;             // ID du graphique principal
   
   // Générer le nom unique d'une ligne
   string GenerateLineName(ulong ticket, string type)
   {
      return StringFormat("ForexScalp_%s_%d_TPSL_%d_%s", 
                         m_symbol, m_magicNumber, ticket, type);
   }
   
   // Trouver l'index d'une position dans le tableau
   int FindPositionIndex(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_trendlines); i++)
      {
         if(m_trendlines[i].ticket == ticket)
            return i;
      }
      return -1;
   }
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ForexTrendlineManager(string symbol, int magicNumber)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_chartId = ChartID(); // Utiliser le graphique courant (où est attaché l'EA)
      ArrayResize(m_trendlines, 0);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~ForexTrendlineManager()
   {
      DeleteAllLines();
   }
   
   //+------------------------------------------------------------------+
   //| Créer les lignes TP et SL pour une position                    |
   //+------------------------------------------------------------------+
   void CreatePositionLines(ulong ticket, double tpPrice, double slPrice)
   {
      // Vérifier que les prix sont valides
      if(tpPrice <= 0 && slPrice <= 0) return;
      
      // Vérifier si cette position a déjà des lignes
      if(FindPositionIndex(ticket) >= 0)
      {
         // Mettre à jour les lignes existantes
         UpdatePositionLines(ticket, tpPrice, slPrice);
         return;
      }
      
      // Ajouter une nouvelle entrée au tableau
      int index = ArraySize(m_trendlines);
      ArrayResize(m_trendlines, index + 1);
      m_trendlines[index].ticket = ticket;
      
      // Créer la ligne TP si le prix est valide
      if(tpPrice > 0)
      {
         string tpLineName = GenerateLineName(ticket, "TP");
         m_trendlines[index].tpLineName = tpLineName;
         
         if(ObjectCreate(m_chartId, tpLineName, OBJ_HLINE, 0, 0, tpPrice))
         {
            ObjectSetInteger(m_chartId, tpLineName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(m_chartId, tpLineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(m_chartId, tpLineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(m_chartId, tpLineName, OBJPROP_BACK, false);
            ObjectSetInteger(m_chartId, tpLineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(m_chartId, tpLineName, OBJPROP_HIDDEN, true);
            
            // Ajouter un label pour identifier la ligne
            string labelName = tpLineName + "_Label";
            ObjectCreate(m_chartId, labelName, OBJ_TEXT, 0, TimeCurrent(), tpPrice);
            ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, "TP #" + IntegerToString(ticket));
            ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(m_chartId, labelName, OBJPROP_FONT, "Arial");
         }
      }
      
      // Créer la ligne SL si le prix est valide
      if(slPrice > 0)
      {
         string slLineName = GenerateLineName(ticket, "SL");
         m_trendlines[index].slLineName = slLineName;
         
         if(ObjectCreate(m_chartId, slLineName, OBJ_HLINE, 0, 0, slPrice))
         {
            ObjectSetInteger(m_chartId, slLineName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(m_chartId, slLineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(m_chartId, slLineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(m_chartId, slLineName, OBJPROP_BACK, false);
            ObjectSetInteger(m_chartId, slLineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(m_chartId, slLineName, OBJPROP_HIDDEN, true);
            
            // Ajouter un label pour identifier la ligne
            string labelName = slLineName + "_Label";
            ObjectCreate(m_chartId, labelName, OBJ_TEXT, 0, TimeCurrent(), slPrice);
            ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, "SL #" + IntegerToString(ticket));
            ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(m_chartId, labelName, OBJPROP_FONT, "Arial");
         }
      }
      
      ChartRedraw(m_chartId);
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les lignes TP et SL pour une position           |
   //+------------------------------------------------------------------+
   void UpdatePositionLines(ulong ticket, double newTP, double newSL)
   {
      int index = FindPositionIndex(ticket);
      if(index < 0) return;
      
      // Mettre à jour la ligne TP si nécessaire
      if(newTP > 0 && m_trendlines[index].tpLineName != "")
      {
         if(ObjectFind(m_chartId, m_trendlines[index].tpLineName) >= 0)
         {
            ObjectSetDouble(m_chartId, m_trendlines[index].tpLineName, OBJPROP_PRICE, newTP);
            
            // Mettre à jour aussi le label
            string labelName = m_trendlines[index].tpLineName + "_Label";
            if(ObjectFind(m_chartId, labelName) >= 0)
            {
               ObjectSetDouble(m_chartId, labelName, OBJPROP_PRICE, newTP);
            }
         }
      }
      
      // Mettre à jour la ligne SL si nécessaire
      if(newSL > 0 && m_trendlines[index].slLineName != "")
      {
         if(ObjectFind(m_chartId, m_trendlines[index].slLineName) >= 0)
         {
            ObjectSetDouble(m_chartId, m_trendlines[index].slLineName, OBJPROP_PRICE, newSL);
            
            // Mettre à jour aussi le label
            string labelName = m_trendlines[index].slLineName + "_Label";
            if(ObjectFind(m_chartId, labelName) >= 0)
            {
               ObjectSetDouble(m_chartId, labelName, OBJPROP_PRICE, newSL);
            }
         }
      }
      
      ChartRedraw(m_chartId);
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer les lignes TP et SL pour une position                |
   //+------------------------------------------------------------------+
   void DeletePositionLines(ulong ticket)
   {
      int index = FindPositionIndex(ticket);
      if(index < 0) return;
      
      // Supprimer la ligne TP et son label
      if(m_trendlines[index].tpLineName != "")
      {
         ObjectDelete(m_chartId, m_trendlines[index].tpLineName);
         ObjectDelete(m_chartId, m_trendlines[index].tpLineName + "_Label");
      }
      
      // Supprimer la ligne SL et son label
      if(m_trendlines[index].slLineName != "")
      {
         ObjectDelete(m_chartId, m_trendlines[index].slLineName);
         ObjectDelete(m_chartId, m_trendlines[index].slLineName + "_Label");
      }
      
      // Supprimer l'entrée du tableau
      for(int i = index; i < ArraySize(m_trendlines) - 1; i++)
      {
         m_trendlines[i] = m_trendlines[i + 1];
      }
      ArrayResize(m_trendlines, ArraySize(m_trendlines) - 1);
      
      ChartRedraw(m_chartId);
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer toutes les lignes TP/SL                            |
   //+------------------------------------------------------------------+
   void DeleteAllLines()
   {
      // Supprimer toutes les lignes et labels
      for(int i = ArraySize(m_trendlines) - 1; i >= 0; i--)
      {
         if(m_trendlines[i].tpLineName != "")
         {
            ObjectDelete(m_chartId, m_trendlines[i].tpLineName);
            ObjectDelete(m_chartId, m_trendlines[i].tpLineName + "_Label");
         }
         
         if(m_trendlines[i].slLineName != "")
         {
            ObjectDelete(m_chartId, m_trendlines[i].slLineName);
            ObjectDelete(m_chartId, m_trendlines[i].slLineName + "_Label");
         }
      }
      
      // Vider le tableau
      ArrayResize(m_trendlines, 0);
      
      ChartRedraw(m_chartId);
   }
   
};
//+------------------------------------------------------------------+
