//+------------------------------------------------------------------+
//|                                                    test_time.mq4 |
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
   // If meet target profit - Close all order - Stop trading
   // Get the current date and time
   datetime now = TimeCurrent();
   // Set the time to midnight
   datetime deltaTime = StrToTime(TimeToStr(now)) % (24*60*60);
   datetime midnight = StrToTime(TimeToStr(now)) - deltaTime;

   Print("Timestamp midnight: ", TimeToString(midnight));
   Print("Timestamp current: ", TimeToStr(now));
  }
//+------------------------------------------------------------------+
