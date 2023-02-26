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
   // Check ATR > Distance between BUY & SELL orders
   string symbol = "XAUUSDm";
   double ATRCurr = iATR(symbol,PERIOD_H1,20,1);
   double ATRPips = NormalizeDouble(ATRCurr/getPip(), 2);
   
   Alert("MODE_POINT: ", MarketInfo(symbol, MODE_POINT));
   Alert("MODE_DIGITS: ", MarketInfo(symbol, MODE_DIGITS));
   Alert("ATRCurr: ", ATRCurr, "Get pips: ", getPip());
   Alert("ATRPips: ", ATRPips);
  }
//+------------------------------------------------------------------+
