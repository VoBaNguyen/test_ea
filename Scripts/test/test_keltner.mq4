//+------------------------------------------------------------------+
//|                                                 test_keltner.mq4 |
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

   double keltnerUp[6], keltnerMid[6], keltnerLow[6];

   // Collect data
   int arrSize = 6;
   int threshold = 4;
   for(int i=0; i<arrSize-1; i++) {
      keltnerUp[i] = iCustom(NULL,0,"Keltner_Channel",50,0,i);
      keltnerMid[i] = iCustom(NULL,0,"Keltner_Channel",50,1,i);
      keltnerLow[i] = iCustom(NULL,0,"Keltner_Channel",50,2,i);
   }
   printf("Cur keltner: %.2f - %.2f - %.2f", keltnerUp[0], keltnerMid[0], keltnerLow[0]);
  }
//+------------------------------------------------------------------+
