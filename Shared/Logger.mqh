//+------------------------------------------------------------------+
//| Logger.mqh                                                        |
//| Centralized logging system with configurable levels              |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Log level enumeration                                            |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_NONE = 0,      // No logging
   LOG_ERROR = 1,     // Only errors
   LOG_WARNING = 2,   // Errors + warnings
   LOG_INFO = 3,      // Errors + warnings + info
   LOG_DEBUG = 4      // Everything including debug
};

//+------------------------------------------------------------------+
//| Static logger class                                              |
//+------------------------------------------------------------------+
class Logger
{
private:
   static ENUM_LOG_LEVEL s_logLevel;
   static string s_prefix;

   //+------------------------------------------------------------------+
   //| Extract filename from full path                                  |
   //+------------------------------------------------------------------+
   static string GetFileName(string fullPath)
   {
      if(fullPath == "") return "";
      
      string parts[];
      int count = StringSplit(fullPath, '\\', parts);
      if(count > 0)
         return parts[count-1];
      count = StringSplit(fullPath, '/', parts);
      if(count > 0)
         return parts[count-1];
      return fullPath; // Return original if no separator found
   }
   
   //+------------------------------------------------------------------+
   //| Format log message with filename and method name                |
   //+------------------------------------------------------------------+
   static string FormatLogMessage(string level, string message, string fileName = "", string methodName = "")
   {
      string result = s_prefix;
      result += level;
      
      if(fileName != "" || methodName != "")
      {
         result += " [";
         if(fileName != "")
         {
            result += GetFileName(fileName);
            if(methodName != "") result += "::";
         }
         if(methodName != "")
         {
            result += methodName;
         }
         result += "] ";
      }
      else
      {
         result += " ";
      }
      
      result += message;
      return result;
   }

public:
   //+------------------------------------------------------------------+
   //| Initialize logger                                                |
   //+------------------------------------------------------------------+
   static void Initialize(ENUM_LOG_LEVEL level, string prefix = "")
   {
      s_logLevel = level;
      s_prefix = prefix;
   }
   
   //+------------------------------------------------------------------+
   //| Log error message (always shown unless LOG_NONE)               |
   //+------------------------------------------------------------------+
   static void Error(string message)
   {
      if(s_logLevel >= LOG_ERROR)
      {
         Print(FormatLogMessage("❌ ERROR", message, __FILE__, __FUNCTION__));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log warning message                                             |
   //+------------------------------------------------------------------+
   static void Warning(string message)
   {
      if(s_logLevel >= LOG_WARNING)
      {
         Print(FormatLogMessage("⚠️ WARNING", message, __FILE__, __FUNCTION__));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log info message                                                |
   //+------------------------------------------------------------------+
   static void Info(string message)
   {
      if(s_logLevel >= LOG_INFO)
      {
         Print(FormatLogMessage("ℹ️ INFO", message, __FILE__, __FUNCTION__));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log debug message                                               |
   //+------------------------------------------------------------------+
   static void Debug(string message)
   {
      if(s_logLevel >= LOG_DEBUG)
      {
         Print(FormatLogMessage("🔍 DEBUG", message, __FILE__, __FUNCTION__));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log success message                                             |
   //+------------------------------------------------------------------+
   static void Success(string message)
   {
      if(s_logLevel >= LOG_INFO)
      {
         Print(FormatLogMessage("✅ SUCCESS", message, __FILE__, __FUNCTION__));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log trade signal                                                |
   //+------------------------------------------------------------------+
   static void Signal(bool isBuy, string message)
   {
      if(s_logLevel >= LOG_INFO)
      {
         string signalLevel = isBuy ? "🟢 BUY" : "🔴 SELL";
         Print(FormatLogMessage(signalLevel, message, __FILE__, __FUNCTION__));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get current log level                                           |
   //+------------------------------------------------------------------+
   static ENUM_LOG_LEVEL GetLevel() { return s_logLevel; }
   
   //+------------------------------------------------------------------+
   //| Set log level                                                   |
   //+------------------------------------------------------------------+
   static void SetLevel(ENUM_LOG_LEVEL level) { s_logLevel = level; }
};

// Initialize static members
static ENUM_LOG_LEVEL Logger::s_logLevel = LOG_INFO;
static string Logger::s_prefix = "";
