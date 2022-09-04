//+------------------------------------------------------------------+
//|                                                  test_candle.mq4 |
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
   ENUM_TIMEFRAMES TIME_FRAME = PERIOD_M5;
   int candle0 = candleType(Symbol(), TIME_FRAME, 0);
   int candle1 = candleType(Symbol(), TIME_FRAME, 1);
   int candle2 = candleType(Symbol(), TIME_FRAME, 2);
   Alert(candle0, candle1, candle2);
   Alert(iClose(Symbol(), TIME_FRAME, 0));
  }
//+------------------------------------------------------------------+


int candleType(string symbol, ENUM_TIMEFRAMES time_frame, int shift) {
   double open = iOpen(symbol, time_frame,shift); 
   double close = iClose(symbol, time_frame,shift);
   if(open < close) {
      return 0; //GREEN
   }
   
   return 1; //RED
}

bool isCandlesType(string symbol, ENUM_TIMEFRAMES time_frame, int range, int type) {
   for(int i=0; i<range; i++) {
      int eleType = candleType(symbol, time_frame, i);
      if (eleType != type) {
         return false;
      }      
   }
   return true;
}
