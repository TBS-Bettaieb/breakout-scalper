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
      // Support "HH:MM" and compact "HHMM"
      StringTrimLeft(time);
      StringTrimRight(time);

      int colon = StringFind(time, ":");
      int hour, minute;

      if(colon >= 0)
      {
         hour   = (int)StringToInteger(StringSubstr(time, 0, colon));
         minute = (int)StringToInteger(StringSubstr(time, colon + 1));
      }
      else
      {
         int len = StringLen(time);
         if(len < 1) return -1;
         if(len < 3 || len > 4) return -1;

         hour   = (int)StringToInteger(StringSubstr(time, 0, len - 2));
         minute = (int)StringToInteger(StringSubstr(time, len - 2));
      }

      if(hour < 0 || hour > 23 || minute < 0 || minute > 59) return -1;
      return hour * 60 + minute;
   }
};


