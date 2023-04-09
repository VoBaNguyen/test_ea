//+------------------------------------------------------------------+
//|                                                  test_random.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   datetime now = TimeCurrent();
   // Set the time to midnight
   datetime midnight = StrToTime(TimeToStr(now, TIME_DATE)) + 0*60*60;
   // Set the time to yesterday midnight
   datetime yesterdayMidnight = midnight - 24*60*60;
   printf(now);
   printf(midnight);
   printf(yesterdayMidnight);
  }
//+------------------------------------------------------------------+
