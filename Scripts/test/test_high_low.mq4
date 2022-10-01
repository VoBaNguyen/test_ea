//+------------------------------------------------------------------+
//|                                                test_high_low.mq4 |
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
   double priceArr[5];
   int range = ArraySize(priceArr);
   for(int idx=0; idx<range; idx++) {
      priceArr[idx] = High[idx+1];
      Alert(idx, " - ", priceArr[idx]);
   }
   int maxHigh = ArrayMaximum(priceArr, WHOLE_ARRAY, 0);
   Alert("Max: ", maxHigh);
   Alert("Max: ", priceArr[maxHigh]);
}
//+------------------------------------------------------------------+
