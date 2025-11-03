//+------------------------------------------------------------------+
//|                        TimeRangeParser.mqh                        |
//|            Utilities for parsing and checking time ranges        |
//+------------------------------------------------------------------+
#property strict

struct TimeRange
{
   int  start;            // Minutes since midnight (0-1439)
   int  end;              // Minutes since midnight (0-1439)
   bool crossesMidnight;
};

class TimeRangeParser
{
public:
   // Parse input like "8-10;16-18" or "08:30-10:45;16:00-18:30"
   static bool ParseRanges(const string rangeString, TimeRange &ranges[])
   {
      ArrayFree(ranges);
      if(rangeString == "" || rangeString == " ") return true;

      string tokens[];
      int count = StringSplit(rangeString, ';', tokens);
      if(count <= 0)
      {
         return true;
      }
      ArrayResize(ranges, count);

      for(int i = 0; i < count; i++)
      {
         if(!ParseSingleRange(tokens[i], ranges[i]))
            return false;
      }
      return true;
   }

   // Check if time in minutes is inside any of the ranges
   static bool IsInRanges(int currentMinutes, const TimeRange &ranges[])
   {
      for(int i = 0; i < ArraySize(ranges); i++)
      {
         if(ranges[i].crossesMidnight)
         {
            if(currentMinutes >= ranges[i].start || currentMinutes <= ranges[i].end)
               return true;
         }
         else
         {
            if(currentMinutes >= ranges[i].start && currentMinutes <= ranges[i].end)
               return true;
         }
      }
      return false;
   }

private:
   static bool ParseSingleRange(string token, TimeRange &range)
   {
      StringTrimLeft(token);
      StringTrimRight(token);
      if(token == "")
      {
         range.start = 0; range.end = 0; range.crossesMidnight = false;
         return true;
      }

      int dash = StringFind(token, "-");
      if(dash < 0) return false;

      range.start = ParseTimeToMinutes(StringSubstr(token, 0, dash));
      range.end   = ParseTimeToMinutes(StringSubstr(token, dash + 1));

      if(range.start < 0 || range.end < 0) return false;

      range.crossesMidnight = (range.start > range.end);
      return true;
   }

   static int ParseTimeToMinutes(string time)
   {
      // Support multiple formats: "8", "17", "8:30", "08:30", "830", "0830"
      StringTrimLeft(time);
      StringTrimRight(time);
      
      if(time == "") return -1;
      
      int hour = 0, minute = 0;
      int colon = StringFind(time, ":");
      
      if(colon >= 0)
      {
         // Format "H:MM" ou "HH:MM"
         hour   = (int)StringToInteger(StringSubstr(time, 0, colon));
         minute = (int)StringToInteger(StringSubstr(time, colon + 1));
      }
      else
      {
         int len = StringLen(time);
         
         if(len == 1 || len == 2)
         {
            // Format simple "8" ou "17" → heures pleines
            hour = (int)StringToInteger(time);
            minute = 0;
         }
         else if(len == 3)
         {
            // Format compact "830" → 8h30
            hour   = (int)StringToInteger(StringSubstr(time, 0, 1));
            minute = (int)StringToInteger(StringSubstr(time, 1, 2));
         }
         else if(len == 4)
         {
            // Format compact "0830" ou "1730" → 8h30 ou 17h30
            hour   = (int)StringToInteger(StringSubstr(time, 0, 2));
            minute = (int)StringToInteger(StringSubstr(time, 2, 2));
         }
         else
         {
            return -1; // Format non supporté
         }
      }
      
      // Validation
      if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
         return -1;
      
      return hour * 60 + minute;
   }
};


