//+------------------------------------------------------------------+
//|                                        FVGMemoryTracker.mqh      |
//|                        Système de monitoring mémoire FVG         |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Structure pour tracker une allocation                            |
//+------------------------------------------------------------------+
struct MemoryAllocation
{
   string objectName;           // Nom de l'objet/array
   datetime timestamp;          // Quand alloué
   int elementCount;            // Nombre d'éléments
   int elementSize;             // Taille d'un élément (bytes)
   long totalBytes;             // Total en bytes
   string location;             // Où dans le code
};

//+------------------------------------------------------------------+
//| Classe de tracking mémoire FVG                                   |
//+------------------------------------------------------------------+
class FVGMemoryTracker
{
private:
   static bool s_debugMode;
   static MemoryAllocation s_allocations[];
   static long s_totalBytesAllocated;
   static long s_peakBytesAllocated;
   static int s_allocationCount;
   static datetime s_lastReportTime;
   
public:
   //+------------------------------------------------------------------+
   //| Activer/Désactiver le mode debug                                |
   //+------------------------------------------------------------------+
   static void SetDebugMode(bool enabled)
   {
      s_debugMode = enabled;
      if(enabled)
      {
         ArrayResize(s_allocations, 0);
         s_totalBytesAllocated = 0;
         s_peakBytesAllocated = 0;
         s_allocationCount = 0;
         s_lastReportTime = TimeCurrent();
         Print("🔍 FVG Memory Tracker ACTIVÉ");
      }
      else
      {
         Print("🔍 FVG Memory Tracker DÉSACTIVÉ");
         ArrayResize(s_allocations, 0);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Enregistrer une allocation                                       |
   //+------------------------------------------------------------------+
   static void TrackAllocation(string objectName, int elementCount, int elementSize, string location = "")
   {
      if(!s_debugMode) return;
      
      long totalBytes = (long)elementCount * (long)elementSize;
      
      // Chercher si déjà existant
      int index = -1;
      for(int i = 0; i < ArraySize(s_allocations); i++)
      {
         if(s_allocations[i].objectName == objectName)
         {
            index = i;
            // Déduire l'ancienne allocation
            s_totalBytesAllocated -= s_allocations[i].totalBytes;
            break;
         }
      }
      
      // Créer ou mettre à jour
      if(index == -1)
      {
         index = ArraySize(s_allocations);
         ArrayResize(s_allocations, index + 1);
         s_allocationCount++;
      }
      
      s_allocations[index].objectName = objectName;
      s_allocations[index].timestamp = TimeCurrent();
      s_allocations[index].elementCount = elementCount;
      s_allocations[index].elementSize = elementSize;
      s_allocations[index].totalBytes = totalBytes;
      s_allocations[index].location = location;
      
      s_totalBytesAllocated += totalBytes;
      
      if(s_totalBytesAllocated > s_peakBytesAllocated)
         s_peakBytesAllocated = s_totalBytesAllocated;
      
      Print("📊 [FVG MEM] ", objectName, " | ", 
            elementCount, " éléments x ", elementSize, " bytes = ",
            FormatBytes(totalBytes), " | Total: ", FormatBytes(s_totalBytesAllocated),
            (location != "" ? " | " + location : ""));
   }
   
   //+------------------------------------------------------------------+
   //| Enregistrer une désallocation                                    |
   //+------------------------------------------------------------------+
   static void TrackDeallocation(string objectName)
   {
      if(!s_debugMode) return;
      
      for(int i = 0; i < ArraySize(s_allocations); i++)
      {
         if(s_allocations[i].objectName == objectName)
         {
            long freedBytes = s_allocations[i].totalBytes;
            s_totalBytesAllocated -= freedBytes;
            
            Print("🗑️ [FVG MEM] ", objectName, " libéré | ", 
                  FormatBytes(freedBytes), " | Total restant: ", 
                  FormatBytes(s_totalBytesAllocated));
            
            // Retirer de la liste
            for(int j = i; j < ArraySize(s_allocations) - 1; j++)
            {
               s_allocations[j] = s_allocations[j + 1];
            }
            ArrayResize(s_allocations, ArraySize(s_allocations) - 1);
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Rapport périodique (appeler toutes les 5 minutes)               |
   //+------------------------------------------------------------------+
   static void PeriodicReport()
   {
      if(!s_debugMode) return;
      
      datetime now = TimeCurrent();
      if(now - s_lastReportTime < 300) return; // 5 minutes
      
      s_lastReportTime = now;
      
      Print("═══════════════════════════════════════════════════════");
      Print("📈 RAPPORT MÉMOIRE FVG - ", TimeToString(now));
      Print("═══════════════════════════════════════════════════════");
      Print("Total actuel     : ", FormatBytes(s_totalBytesAllocated));
      Print("Peak atteint     : ", FormatBytes(s_peakBytesAllocated));
      Print("Allocations      : ", s_allocationCount);
      Print("Objets actifs    : ", ArraySize(s_allocations));
      Print("───────────────────────────────────────────────────────");
      
      if(ArraySize(s_allocations) > 0)
      {
         // Trier par taille décroissante
         SortAllocationsBySize();
         
         Print("TOP CONSOMMATEURS:");
         int maxDisplay = MathMin(10, ArraySize(s_allocations));
         for(int i = 0; i < maxDisplay; i++)
         {
            double percent = (s_totalBytesAllocated > 0) 
               ? (double)s_allocations[i].totalBytes / (double)s_totalBytesAllocated * 100.0 
               : 0.0;
            
            Print(IntegerToString(i + 1), ". ", s_allocations[i].objectName, 
                  " | ", FormatBytes(s_allocations[i].totalBytes),
                  " (", DoubleToString(percent, 1), "%) | ",
                  s_allocations[i].elementCount, " éléments");
         }
      }
      Print("═══════════════════════════════════════════════════════");
   }
   
   //+------------------------------------------------------------------+
   //| Rapport complet (appeler manuellement)                          |
   //+------------------------------------------------------------------+
   static void FullReport()
   {
      if(!s_debugMode) return;
      
      Print("═══════════════════════════════════════════════════════");
      Print("📊 RAPPORT MÉMOIRE FVG COMPLET");
      Print("═══════════════════════════════════════════════════════");
      Print("Total actuel     : ", FormatBytes(s_totalBytesAllocated));
      Print("Peak atteint     : ", FormatBytes(s_peakBytesAllocated));
      Print("Allocations      : ", s_allocationCount);
      Print("Objets actifs    : ", ArraySize(s_allocations));
      Print("───────────────────────────────────────────────────────");
      
      SortAllocationsBySize();
      
      for(int i = 0; i < ArraySize(s_allocations); i++)
      {
         double percent = (s_totalBytesAllocated > 0)
            ? (double)s_allocations[i].totalBytes / (double)s_totalBytesAllocated * 100.0
            : 0.0;
         
         Print(IntegerToString(i + 1), ". ", s_allocations[i].objectName);
         Print("   Taille    : ", FormatBytes(s_allocations[i].totalBytes), 
               " (", DoubleToString(percent, 1), "%)");
         Print("   Éléments  : ", s_allocations[i].elementCount, 
               " x ", s_allocations[i].elementSize, " bytes");
         Print("   Alloué à  : ", TimeToString(s_allocations[i].timestamp));
         if(s_allocations[i].location != "")
            Print("   Location  : ", s_allocations[i].location);
      }
      Print("═══════════════════════════════════════════════════════");
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir l'usage mémoire actuel                                   |
   //+------------------------------------------------------------------+
   static long GetCurrentUsage() { return s_totalBytesAllocated; }
   static long GetPeakUsage() { return s_peakBytesAllocated; }
   static int GetActiveObjects() { return ArraySize(s_allocations); }
   
private:
   //+------------------------------------------------------------------+
   //| Formater les bytes en unité lisible                             |
   //+------------------------------------------------------------------+
   static string FormatBytes(long bytes)
   {
      if(bytes < 1024)
         return IntegerToString(bytes) + " B";
      else if(bytes < 1024 * 1024)
         return DoubleToString((double)bytes / 1024.0, 2) + " KB";
      else
         return DoubleToString((double)bytes / (1024.0 * 1024.0), 2) + " MB";
   }
   
   //+------------------------------------------------------------------+
   //| Trier les allocations par taille décroissante                   |
   //+------------------------------------------------------------------+
   static void SortAllocationsBySize()
   {
      int n = ArraySize(s_allocations);
      for(int i = 0; i < n - 1; i++)
      {
         for(int j = 0; j < n - i - 1; j++)
         {
            if(s_allocations[j].totalBytes < s_allocations[j + 1].totalBytes)
            {
               MemoryAllocation temp = s_allocations[j];
               s_allocations[j] = s_allocations[j + 1];
               s_allocations[j + 1] = temp;
            }
         }
      }
   }
};

// Initialisation des variables statiques
bool FVGMemoryTracker::s_debugMode = false;
MemoryAllocation FVGMemoryTracker::s_allocations[];
long FVGMemoryTracker::s_totalBytesAllocated = 0;
long FVGMemoryTracker::s_peakBytesAllocated = 0;
int FVGMemoryTracker::s_allocationCount = 0;
datetime FVGMemoryTracker::s_lastReportTime = 0;

