//+------------------------------------------------------------------+
//|                                                   hedging_v1.mq4 |
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
//| Setup default parameters for the EA                              |
//+------------------------------------------------------------------+
input int slippage = 10;
input long EA_ID = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_M15;
double delta = 0.5;
int SLPips = 20;
int TPPips = 60;
int k = SLPips + TPPips;
int margin = 5;
double initLot = 1;

double anchorPrice = Ask;
double anchorBuy = anchorPrice + delta;
double anchorSell = anchorPrice - delta;

double buyTP = calTP(true, anchorBuy,TPPips);
double sellTP = calTP(false, anchorSell,TPPips);

double buySL = sellTP;
double sellSL = buyTP;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Alert("Init hedging_v1 strategy");
//---
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Alert("Remove strategy");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   Alert("--------------------------- New tick ---------------------------");


   // If there's a pending order => SKIP
   int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + 
                       countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
   if(pendingOrders > 0) {
      return;
   }
   
   
   // Count BUY/SELL position to calculate
   int totalPos = countPosition(EA_ID, ORDER_TYPE_BUY) + 
                  countPosition(EA_ID, ORDER_TYPE_SELL);
   
   // Let's start with SELL => First order is SELL
   int signum = MathPow(-1, totalPos+1);
   if (totalPos == 0) {
      sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, initLot, anchorBuy, slippage, buySL, buyTP, "", EA_ID);
      sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, initLot, anchorSell, slippage, sellSL, sellTP, "", EA_ID);
      return;
   }

   
   // If there's no pending order, we need to prepare for the next reverse of the price by open an opposite order.
   int ticket = lastOpenedOrder(EA_ID);
   if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES)){
      int orderType = OrderType();
      
      // Last order is BUY => Open SELL stop order
      if(orderType == ORDER_TYPE_BUY) {
         double lot = (sumLot(_Symbol, ORDER_TYPE_BUY)*k 
                       + totalPos*margin)/TPPips 
                       - sumLot(_Symbol, ORDER_TYPE_SELL);
         double entry = anchorPrice + (SLPips/10)*signum;
         double TP = calTP(true, entry,TPPips);
         int orderID = sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, lot, entry, slippage, 0, sellTP, "", EA_ID);
      }
      
      // Last order is SELL => Open BUY stop order
      else if(orderType == ORDER_TYPE_SELL) {
         double lot = (sumLot(_Symbol, ORDER_TYPE_SELL)*k 
                       + totalPos*margin)/TPPips 
                       - sumLot(_Symbol, ORDER_TYPE_BUY);
         double entry = anchorPrice + (SLPips/10)*signum;
         double TP = calTP(true, entry,TPPips);
         int orderID = sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, lot, entry, slippage, 0, buyTP, "", EA_ID);
      }
   }
  }
//+------------------------------------------------------------------+
