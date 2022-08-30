//+------------------------------------------------------------------+
//|                                                 test_account.mq4 |
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
// Include system modules
#include <models/account.mqh>;
#include <common/utils.mqh>;
void OnStart()
  {
//---
   MyAccount account("Nguyen", "Vo", 7777);
   account.showBalance();
   
   Alert("Symbol: ", _Symbol);
   Alert("Pip: ", getPip());
  }
//+------------------------------------------------------------------+
