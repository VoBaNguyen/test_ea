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
input ENUM_HOUR startHour = h15; // Start operation hour
input ENUM_HOUR lastHour  = h22; // Last operation hour
input int margin     = 5;        // pips
input double delta   = 5;        // pips
input double initLot = 0.1;      // lot
input int SLPips     = 10;       // pips
input int TPPips     = 30;       // pips

// Calculate default setting
int k = SLPips + TPPips;
double anchorPriceArr[1];

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
   if(anchorPriceArr[0] == 0) {
      anchorPriceArr[0] = Ask;
   }
   
   double anchorPrice = anchorPriceArr[0];

   // Count BUY/SELL position to calculate
   int totalPos = countPosition(EA_ID, ORDER_TYPE_BUY) + countPosition(EA_ID, ORDER_TYPE_SELL);
   int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);

   if(totalPos == 0) {
      // Check active hours
      if(!checkActiveHours(startHour, lastHour)) {
         return;
      }
   
      // Close pending order from previous setup hedging.
      closeOldPendingOrders();
      
      if(pendingOrders == 0) {
         // SETUP FOR THE NEXT HEDGING ROUND!
         anchorPriceArr[0] = Ask;
         double anchorPrice = anchorPriceArr[0];
         double anchorBuy = calTP(true, anchorPrice, delta);
         double anchorSell = calTP(false, anchorPrice, delta);
         double buyTP = calTP(true, anchorBuy, TPPips);
         double sellTP = calTP(false, anchorSell, TPPips);
         double buySL = sellTP;
         double sellSL = buyTP;
         Alert("New anchorPrice: ", anchorPrice);
         sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, initLot, anchorBuy, slippage, buySL, buyTP, "", EA_ID);
         sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, initLot, anchorSell, slippage, sellSL, sellTP, "", EA_ID);
      }
   }

   else {
      Alert("anchorPrice: ", anchorPrice);
      double anchorBuy = calTP(true, anchorPrice, delta);
      double anchorSell = calTP(false, anchorPrice, delta);
      double buyTP = calTP(true, anchorBuy, TPPips);
      double sellTP = calTP(false, anchorSell, TPPips);
      double buySL = sellTP;
      double sellSL = buyTP;
      
      // In case trigger first postion and still hanging the second position
      for(int i=0; i<OrdersTotal(); i++) {
         if(OrderSelect(i, SELECT_BY_POS) == true) {
            if(OrderType() == ORDER_TYPE_BUY_STOP || OrderType() == ORDER_TYPE_SELL_STOP) {
               if(OrderLots() == initLot) {
                  OrderDelete(OrderTicket());
               }
            }
         }
      }
      
      // If there's no pending order, we need to prepare for the next reverse of the price by open an opposite order.
      int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
      if(pendingOrders == 0) {
         int signum = MathPow(-1, totalPos+1);
         int lastTicket = lastOpenedOrder(EA_ID);
         if(selectOrder(lastTicket, SELECT_BY_TICKET, MODE_TRADES)){
            int orderType = OrderType();
            
            // Last order is BUY => Open SELL stop order
            if(orderType == ORDER_TYPE_BUY) {
               double lot = (sumLot(_Symbol, ORDER_TYPE_BUY)*(k + margin))/TPPips 
                             - sumLot(_Symbol, ORDER_TYPE_SELL);
               int orderID = sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, lot, anchorSell, slippage, sellSL, sellTP, "", EA_ID);
            }
            
            // Last order is SELL => Open BUY stop order
            else if(orderType == ORDER_TYPE_SELL) {
               double lot = (sumLot(_Symbol, ORDER_TYPE_SELL)*(k + margin))/TPPips 
                             - sumLot(_Symbol, ORDER_TYPE_BUY);
               int orderID = sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, lot, anchorBuy, slippage, buySL, buyTP, "", EA_ID);
            }
         }
      }
   }
  }
//+------------------------------------------------------------------+



void closeOldPendingOrders() {
   // In case trigger first postion and still hanging the second position
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         if(OrderType() == ORDER_TYPE_BUY_STOP || OrderType() == ORDER_TYPE_SELL_STOP) {
            if(OrderType() == ORDER_TYPE_BUY_STOP && Ask < OrderStopLoss()) {
               OrderDelete(OrderTicket());
            } 
            else if (OrderType() == ORDER_TYPE_SELL_STOP && Ask > OrderStopLoss()) {
               OrderDelete(OrderTicket());
            }
         }
      }
   }
}