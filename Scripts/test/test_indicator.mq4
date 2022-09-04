//+------------------------------------------------------------------+
//|                                               test_indicator.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <common/utils.mqh>;
#include <models/account.mqh>;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   double keltnerMid[6];

   int arrSize = 6;


   // Collect data
   for(int i=0; i<arrSize; i++) {
      keltnerMid[i] = iCustom(Symbol(),PERIOD_M5,"Keltner_Channel",50,1,i);
      Alert(i, " - ", keltnerMid[i]);      
   }
   
   bool isKNDownward  = idcDownward(keltnerMid, arrSize, 0.3);
   Alert(isKNDownward);   
   
  }
//+------------------------------------------------------------------+


