//+------------------------------------------------------------------+
//|                                         test_price_action_v1.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
	double value = iCustom(Symbol(),PERIOD_H1,"test\\test_candel", 1, 2);


   // Check insidebar
   string grpInfo[2];
   grpInfo[0] = "undefined";
   grpInfo[1] = "undefined";
   classifyGrpCandle(1, grpInfo, PERIOD_CURRENT);
   if(grpInfo[1] == "insidebar") {
      if(grpInfo[0] == "sell") {
         InsideBarsDown[i] = High[i] + dist;
      }
      else if(grpInfo[0] == "buy") {
         InsideBarsUp[i] = Low[i] - dist;
      }

   }


  }
//+------------------------------------------------------------------+
