//+------------------------------------------------------------------+
//|                                        TrailingTP_System.mqh     |
//|                   Système de Trailing Take Profit avancé        |
//|                   VERSION CORRIGÉE avec Validateur Complet      |
//|                                                                   |
//| VERSION: 2.1 - Bugs corrigés + Validateur robuste               |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "2.1"
#property strict

//+------------------------------------------------------------------+
//| Énumération des modes de Trailing TP                            |
//+------------------------------------------------------------------+
enum ENUM_TRAILING_TP_MODE
{
   TRAILING_TP_LINEAR,        // Mode linéaire (75% → SL+50%, TP+25%)
   TRAILING_TP_STEPPED,       // Mode par paliers (50% → BE, puis +50% TP)
   TRAILING_TP_EXPONENTIAL,   // Mode exponentiel (gains x8+)
   TRAILING_TP_CUSTOM         // Mode personnalisé avec niveaux définis
};

//+------------------------------------------------------------------+
//| Structure pour les niveaux personnalisés                        |
//+------------------------------------------------------------------+
struct TrailingLevel
{
   double profitPercent;      // Pourcentage de profit pour déclencher
   double slMovePercent;      // Pourcentage de déplacement du SL
   double tpExtendPercent;    // Pourcentage d'extension du TP
};

//+------------------------------------------------------------------+
//| VALIDATEUR GLOBAL - Valide la syntaxe AVANT de créer l'EA       |
//+------------------------------------------------------------------+
class CTrailingTPValidator
{
public:
   //+------------------------------------------------------------------+
   //| Valider une string de niveaux custom                            |
   //+------------------------------------------------------------------+
   static bool ValidateCustomLevelsString(string levelsString, string &errorMessage)
   {
      errorMessage = "";
      
      // Vérification 1: String vide
      if(levelsString == "")
      {
         errorMessage = "❌ String vide - Format requis: 'profit:slMove:tpExtend, ...'";
         return false;
      }
      
      // Vérification 2: Longueur max
      if(StringLen(levelsString) > 500)
      {
         errorMessage = "❌ String trop longue (max 500 caractères)";
         return false;
      }
      
      // Séparer par virgule
      string tokens[];
      int levelCount = StringSplit(levelsString, ',', tokens);
      
      // Vérification 3: Nombre de niveaux
      if(levelCount == 0)
      {
         errorMessage = "❌ Aucun niveau trouvé - vérifiez le format";
         return false;
      }
      
      if(levelCount > 20)
      {
         errorMessage = "❌ Trop de niveaux (max 20, trouvé: " + IntegerToString(levelCount) + ")";
         return false;
      }
      
      // Parser et valider chaque niveau
      TrailingLevel levels[];
      ArrayResize(levels, levelCount);
      
      for(int i = 0; i < levelCount; i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         
         // Vérification 4: Format de chaque niveau
         string parts[];
         int partsCount = StringSplit(token, ':', parts);
         
         if(partsCount != 3)
         {
            errorMessage = StringFormat(
               "❌ Niveau %d invalide: '%s'\n" +
               "   Format attendu: 'profit:slMove:tpExtend'\n" +
               "   Exemple: '75:50:25'",
               i+1, token
            );
            return false;
         }
         
         // Parser les valeurs
         double profitPercent = StringToDouble(parts[0]);
         double slMovePercent = StringToDouble(parts[1]);
         double tpExtendPercent = StringToDouble(parts[2]);
         
         // Vérification 5: Valeurs valides
         if(profitPercent <= 0)
         {
            errorMessage = StringFormat(
               "❌ Niveau %d: profit doit être > 0 (trouvé: %.1f)",
               i+1, profitPercent
            );
            return false;
         }
         
         if(profitPercent > 1000)
         {
            errorMessage = StringFormat(
               "❌ Niveau %d: profit trop élevé (max 1000%%, trouvé: %.1f%%)",
               i+1, profitPercent
            );
            return false;
         }
         
         if(slMovePercent < 0)
         {
            errorMessage = StringFormat(
               "❌ Niveau %d: slMove doit être ≥ 0 (trouvé: %.1f)",
               i+1, slMovePercent
            );
            return false;
         }
         
         if(slMovePercent > 1000)
         {
            errorMessage = StringFormat(
               "❌ Niveau %d: slMove trop élevé (max 1000%%, trouvé: %.1f%%)",
               i+1, slMovePercent
            );
            return false;
         }
         
         if(tpExtendPercent < 0)
         {
            errorMessage = StringFormat(
               "❌ Niveau %d: tpExtend doit être ≥ 0 (trouvé: %.1f)",
               i+1, tpExtendPercent
            );
            return false;
         }
         
         if(tpExtendPercent > 2000)
         {
            errorMessage = StringFormat(
               "❌ Niveau %d: tpExtend trop élevé (max 2000%%, trouvé: %.1f%%)",
               i+1, tpExtendPercent
            );
            return false;
         }
         
         levels[i].profitPercent = profitPercent;
         levels[i].slMovePercent = slMovePercent;
         levels[i].tpExtendPercent = tpExtendPercent;
         
         // Vérification 6: Ordre croissant
         if(i > 0 && profitPercent <= levels[i-1].profitPercent)
         {
            errorMessage = StringFormat(
               "❌ Niveaux non ordonnés!\n" +
               "   Niveau %d (%.1f%%) doit être > Niveau %d (%.1f%%)",
               i+1, profitPercent, i, levels[i-1].profitPercent
            );
            return false;
         }
         
         // Vérification 7: Progression logique du SL
         if(i > 0 && slMovePercent < levels[i-1].slMovePercent)
         {
            errorMessage = StringFormat(
               "⚠️ Attention niveau %d: SL recule de %.1f%% à %.1f%%\n" +
               "   Le SL devrait normalement progresser",
               i+1, levels[i-1].slMovePercent, slMovePercent
            );
            // Warning seulement, pas d'erreur
            Print(errorMessage);
         }
      }
      
      // Tout est OK!
      errorMessage = StringFormat(
         "✅ Configuration valide: %d niveau(x) chargé(s)",
         levelCount
      );
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Afficher les niveaux parsés                                     |
   //+------------------------------------------------------------------+
   static void PrintParsedLevels(string levelsString)
   {
      string tokens[];
      int levelCount = StringSplit(levelsString, ',', tokens);
      
      Print("═══════════════════════════════════════");
      Print("📋 NIVEAUX CUSTOM TRAILING TP");
      Print("═══════════════════════════════════════");
      
      for(int i = 0; i < levelCount; i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         
         string parts[];
         StringSplit(token, ':', parts);
         
         if(ArraySize(parts) == 3)
         {
            Print(StringFormat(
               "  [%d] Profit: %s%% → SL à %s%%, TP +%s%%",
               i+1, parts[0], parts[1], parts[2]
            ));
         }
      }
      Print("═══════════════════════════════════════");
   }
};

//+------------------------------------------------------------------+
//| Classe principale du système de Trailing TP                     |
//+------------------------------------------------------------------+
class CTrailingTP
{
private:
   // Configuration
   ENUM_TRAILING_TP_MODE m_mode;
   string m_customLevelsString;
   TrailingLevel m_customLevels[];
   int m_levelCount;
   
   // État de la position
   double m_entryPrice;
   double m_initialSL;
   double m_initialTP;
   double m_distanceSLTP;  // NOUVEAU: Distance SL-TP pour calculs
   bool m_isBuy;
   
   // Suivi des profits
   double m_maxProfit;
   double m_currentProfit;
   int m_currentLevel;
   
   // Validation
   bool m_isInitialized;
   bool m_isValidConfig;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   CTrailingTP(ENUM_TRAILING_TP_MODE mode = TRAILING_TP_STEPPED, string customLevels = "")
   {
      m_mode = mode;
      m_customLevelsString = customLevels;
      m_levelCount = 0;
      
      m_entryPrice = 0;
      m_initialSL = 0;
      m_initialTP = 0;
      m_distanceSLTP = 0;
      m_isBuy = true;
      
      m_maxProfit = 0;
      m_currentProfit = 0;
      m_currentLevel = 0;
      
      m_isInitialized = false;
      m_isValidConfig = true;
      
      // Parser les niveaux custom si fournis
      if(mode == TRAILING_TP_CUSTOM && customLevels != "")
      {
         bool success = ParseCustomLevels(customLevels);
         if(!success)
         {
            Print("❌ Échec du parsing des niveaux custom");
            m_isValidConfig = false;
         }
      }
   }

   ~CTrailingTP()
   {
      ArrayFree(m_customLevels);
   }

   //+------------------------------------------------------------------+
   //| Initialiser avec les données de position                       |
   //+------------------------------------------------------------------+
   bool Initialize(double entryPrice, double initialSL, double initialTP, bool isBuy)
   {
      // Validation des paramètres
      if(entryPrice <= 0 || initialTP <= 0)
      {
         Print("❌ TrailingTP: Paramètres invalides - Entry: ", entryPrice, " TP: ", initialTP);
         return false;
      }
      
      m_entryPrice = entryPrice;
      m_initialSL = initialSL;
      m_initialTP = initialTP;
      m_isBuy = isBuy;
      
      // CORRECTION BUG #1: Calculer la distance SL-TP correctement
      if(isBuy)
      {
         m_distanceSLTP = initialTP - entryPrice;
      }
      else
      {
         m_distanceSLTP = entryPrice - initialTP;
      }
      
      // Vérification de la distance
      if(m_distanceSLTP <= 0)
      {
         Print("❌ TrailingTP: Distance SL-TP invalide: ", m_distanceSLTP);
         return false;
      }
      
      m_maxProfit = 0;
      m_currentProfit = 0;
      m_currentLevel = 0;
      
      m_isInitialized = true;
      m_isValidConfig = ValidateConfiguration();
      
      if(!m_isValidConfig)
      {
         Print("❌ TrailingTP: Configuration invalide pour le mode ", EnumToString(m_mode));
         return false;
      }
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour avec le prix actuel                              |
   //+------------------------------------------------------------------+
   bool Update(double currentPrice, double &newSL, double &newTP)
   {
      if(!m_isInitialized || !m_isValidConfig)
         return false;
      
      // CORRECTION BUG #1: Calculer le profit correctement
      double profit = CalculateProfit(currentPrice);
      m_currentProfit = profit;
      
      if(profit > m_maxProfit)
         m_maxProfit = profit;
      
      bool modified = false;
      
      switch(m_mode)
      {
         case TRAILING_TP_LINEAR:
            modified = UpdateLinear(currentPrice, newSL, newTP);
            break;
            
         case TRAILING_TP_STEPPED:
            modified = UpdateStepped(currentPrice, newSL, newTP);
            break;
            
         case TRAILING_TP_EXPONENTIAL:
            modified = UpdateExponential(currentPrice, newSL, newTP);
            break;
            
         case TRAILING_TP_CUSTOM:
            modified = UpdateCustom(currentPrice, newSL, newTP);
            break;
      }
      
      return modified;
   }

   ENUM_TRAILING_TP_MODE GetMode() const { return m_mode; }
   string GetCustomLevelsString() const { return m_customLevelsString; }
   int GetLevelCount() const { return m_levelCount; }

   string GetStatusInfo()
   {
      string info = "Trailing TP: " + EnumToString(m_mode);
      
      if(m_mode == TRAILING_TP_CUSTOM)
      {
         info += " | Niveau: " + IntegerToString(m_currentLevel) + "/" + IntegerToString(m_levelCount);
      }
      else
      {
         info += " | Niveau: " + IntegerToString(m_currentLevel);
      }
      
      info += " | Max Profit: " + DoubleToString(m_maxProfit, 2) + "%";
      return info;
   }

   bool ValidateConfiguration()
   {
      switch(m_mode)
      {
         case TRAILING_TP_LINEAR:
         case TRAILING_TP_STEPPED:
         case TRAILING_TP_EXPONENTIAL:
            return true;
            
         case TRAILING_TP_CUSTOM:
            return (m_levelCount > 0);
            
         default:
            return false;
      }
   }

   void SetCustomLevels(TrailingLevel &levels[])
   {
      if(m_mode != TRAILING_TP_CUSTOM) return;
      
      int size = ArraySize(levels);
      ArrayResize(m_customLevels, size);
      
      for(int i = 0; i < size; i++)
      {
         m_customLevels[i] = levels[i];
      }
      
      m_levelCount = size;
   }

private:
   //+------------------------------------------------------------------+
   //| CORRECTION BUG #1: Calculer le profit en % de la distance SL-TP |
   //+------------------------------------------------------------------+
   double CalculateProfit(double currentPrice)
   {
      if(m_distanceSLTP == 0) return 0;
      
      double profit;
      
      if(m_isBuy)
      {
         profit = currentPrice - m_entryPrice;
      }
      else
      {
         profit = m_entryPrice - currentPrice;
      }
      
      // Retourner en % de la distance SL-TP
      return (profit / m_distanceSLTP) * 100.0;
   }

   bool UpdateLinear(double currentPrice, double &newSL, double &newTP)
   {
      if(m_currentLevel > 0) return false;
      
      if(m_maxProfit >= 75.0)
      {
         double slMove = m_distanceSLTP * 0.5;
         double tpExtend = m_distanceSLTP * 0.25;
         
         if(m_isBuy)
         {
            newSL = m_entryPrice + slMove;
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_entryPrice - slMove;
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 1;
         Print("🎯 Trailing TP LINEAR Niveau 1 déclenché!");
         return true;
      }
      
      return false;
   }

   bool UpdateStepped(double currentPrice, double &newSL, double &newTP)
   {
      if(m_maxProfit >= 50.0 && m_currentLevel == 0)
      {
         newSL = m_entryPrice;
         newTP = m_initialTP;
         m_currentLevel = 1;
         Print("🎯 Trailing TP STEPPED Niveau 1: SL à BE");
         return true;
      }
      else if(m_maxProfit >= 100.0 && m_currentLevel == 1)
      {
         double tpExtend = m_distanceSLTP * 0.5;
         
         if(m_isBuy)
         {
            newSL = m_entryPrice;
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_entryPrice;
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 2;
         Print("🎯 Trailing TP STEPPED Niveau 2: TP +50%");
         return true;
      }
      
      return false;
   }

   bool UpdateExponential(double currentPrice, double &newSL, double &newTP)
   {
      if(m_maxProfit >= 25.0 && m_currentLevel == 0)
      {
         newSL = m_entryPrice;
         newTP = m_initialTP;
         m_currentLevel = 1;
         Print("🎯 Trailing TP EXPONENTIAL Niveau 1: SL à BE");
         return true;
      }
      else if(m_maxProfit >= 50.0 && m_currentLevel == 1)
      {
         double tpExtend = m_distanceSLTP;
         
         if(m_isBuy)
         {
            newSL = m_entryPrice;
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_entryPrice;
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 2;
         Print("🎯 Trailing TP EXPONENTIAL Niveau 2: TP x2");
         return true;
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| CORRECTION BUG #4: Utiliser m_distanceSLTP au lieu de calcul    |
   //+------------------------------------------------------------------+
   bool UpdateCustom(double currentPrice, double &newSL, double &newTP)
   {
      if(m_levelCount == 0 || m_distanceSLTP == 0) return false;
      
      if(m_currentLevel < m_levelCount)
      {
         double levelProfit = m_customLevels[m_currentLevel].profitPercent;
         double levelSlMove = m_customLevels[m_currentLevel].slMovePercent;  
         double levelTpExtend = m_customLevels[m_currentLevel].tpExtendPercent;
         
         if(m_maxProfit >= levelProfit)
         {
            // Calculer les nouveaux niveaux
            double slMove = m_distanceSLTP * (levelSlMove / 100.0);
            double tpExtend = m_distanceSLTP * (levelTpExtend / 100.0);
            if(m_isBuy)
            {
               newSL = m_entryPrice + slMove;
               newTP = m_initialTP + tpExtend;
            }
            else
            {
               newSL = m_entryPrice - slMove;
               newTP = m_initialTP - tpExtend;
            }
            
            m_currentLevel++;
            
            Print(StringFormat(
               "🎯 Trailing TP CUSTOM Niveau %d/%d déclenché!\n" +
               "   Profit: %.2f%% | Nouveau SL: %.5f | Nouveau TP: %.5f",
               m_currentLevel, m_levelCount, m_maxProfit, newSL, newTP
            ));
            
            return true;
         }
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| CORRECTION BUG #3: Retourner bool + logs détaillés              |
   //+------------------------------------------------------------------+
   bool ParseCustomLevels(string levelsString)
   {
      string tokens[];
      int n = StringSplit(levelsString, ',', tokens);
      
      if(n == 0)
      {
         Print("❌ ParseCustomLevels: Aucun token trouvé");
         return false;
      }
      
      ArrayResize(m_customLevels, n);
      m_levelCount = 0;
      
      for(int i = 0; i < n; i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         
         string parts[];
         int partsCount = StringSplit(token, ':', parts);
         
         if(partsCount != 3)
         {
            Print("❌ ParseCustomLevels: Format invalide pour niveau ", i+1, ": '", token, "'");
            return false;
         }
         
         TrailingLevel level;
         level.profitPercent = StringToDouble(parts[0]);
         level.slMovePercent = StringToDouble(parts[1]);
         level.tpExtendPercent = StringToDouble(parts[2]);
         
         m_customLevels[m_levelCount] = level;
         m_levelCount++;
      }
      
      Print("✅ ParseCustomLevels: ", m_levelCount, " niveau(x) parsé(s) avec succès");
      return true;
   }
};