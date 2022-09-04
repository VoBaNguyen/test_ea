//+------------------------------------------------------------------+
//|                                                   test_array.mq4 |
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
   double arr[3];
   arr[0] = 1839.3934;
   arr[1] = 1839.3775;
   arr[2] = 1839.3738;
   Alert("decrease: ", isArrDecrease(arr));
   Alert("increase: ", isArrIncrease(arr));
   Alert("upward: ", idcUpward(arr, 3, 0.3));
   Alert("downward: ", idcDownward(arr, 3, 0.3));
  }
//+------------------------------------------------------------------+
