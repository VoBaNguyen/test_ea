//+------------------------------------------------------------------+
//|                                                    test_pips.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include custom models                                            |
//+------------------------------------------------------------------+
#include <models/account.mqh>;
#include <common/utils.mqh>;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  Alert("---------------- NEW TRIAL ----------------");
//---
   string symbols[5];
   symbols[0] = "EURJPYm";
   symbols[1] = "GBPJPYm";
   symbols[2] = "AUDJPYm";
   symbols[3] = "AUDUSDm";
   symbols[4] = "EURUSDm";
   
   for (int i=0; i<ArraySize(symbols); i++) {      
      Alert("Symbol: ", symbols[i], ", Pips: ", getPip(symbols[i]), ", Ask: ", MarketInfo(symbols[i], MODE_ASK));
   }
   
   Alert("AccountLeverage: ", AccountLeverage());
   double anchorPriceArr[1];
   Alert(anchorPriceArr[0]);

  }
//+------------------------------------------------------------------+
