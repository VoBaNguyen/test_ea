//+------------------------------------------------------------------+
//|                                                 test_hedging.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             htTPPipss://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "htTPPipss://www.mql5.com"
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
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;
double anchorPrice = Ask - 50;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void addToDoubleArray( double& theArray[][], double size, double price ) {
   ArrayResize( theArray, ArraySize( theArray ) + 1 );
   theArray[ ArraySize( theArray ) ][0] = size;
   theArray[ ArraySize( theArray ) ][1] = price;
}


void OnStart()
  {
//---
   Alert("--------------------------- New test ---------------------------");
   int SLPips = 20;
   int TPPips = 60;
   int k = SLPips + TPPips;
   int margin = 5;
   double initLot = 1;
   int tradeRange = 10;
   double buyOrders[1][2]; 
   double sellOrders[10];
   

   Alert("All opened orders:");
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         Alert("Symbol: ", OrderSymbol(), ", Type: ", OrderType());
      }
   }


   Alert("------------------");

   // If there's a pending order => SKIP
   int pendingBuyOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP);
   int pendingSellOrders = countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
   int pendingOrders = pendingBuyOrders + pendingSellOrders;
   Alert("Pending BUY orders: ", pendingBuyOrders);
   Alert("Pending SELL orders: ", pendingSellOrders);
   if(pendingOrders > 0) {
      return;
   }
   
   // Count BUY/SELL position to calculate
   int buyPos = countPosition(EA_ID, ORDER_TYPE_BUY);
   int sellPos = countPosition(EA_ID, ORDER_TYPE_SELL);
   int totalPos = buyPos + sellPos;
   Alert("Anchor price: ", anchorPrice);
   
   // Let's start with SELL => First order is SELL
   int signum = MathPow(-1, totalPos+1);
   if (totalPos == 0) {
      double entry = anchorPrice;
      double TP = calTP(false, entry, TPPips);
      int orderID = sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, initLot, entry, slippage, 0, TP, "", EA_ID);
   }
   
   else if (MathMod(totalPos, 2) == 1) {
      Alert(totalPos, "BUY");
      double lot = (sumLot(_Symbol, ORDER_TYPE_SELL)*k 
                    + totalPos*margin)/TPPips 
                    - sumLot(_Symbol, ORDER_TYPE_BUY);
      double entry = anchorPrice + (SLPips/10)*signum;
      double TP = calTP(true, entry,TPPips);
      int orderID = sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, lot, entry, slippage, 0, TP, "", EA_ID);
      
   }
   
   else if (MathMod(totalPos, 2) == 0) {
      Alert(totalPos, "SELL");
      // Calculate lot size
      double lot = (sumLot(_Symbol, ORDER_TYPE_BUY)*k 
                    + totalPos*margin)/TPPips 
                    - sumLot(_Symbol, ORDER_TYPE_SELL);
      double entry = anchorPrice + (SLPips/10)*signum;
      double TP = calTP(true, entry,TPPips);
      int orderID = sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, lot, entry, slippage, 0, TP, "", EA_ID);
   }


  }
//+------------------------------------------------------------------+
