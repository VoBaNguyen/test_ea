//+------------------------------------------------------------------+
//|                                                    ma_signal.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


//+------------------------------------------------------------------+
//| Include system modules                                           |
//+------------------------------------------------------------------+
#include <stderror.mqh>
#include <stdlib.mqh>

//+------------------------------------------------------------------+
//| Include custom modules                                           |
//+------------------------------------------------------------------+
#include <common/utils.mqh>;
#include <models/account.mqh>;

//+------------------------------------------------------------------+
//| Input EA                                                         |
//+------------------------------------------------------------------+
input double lotSize = 0.1; // Lot Size
input int maxPos = 1; //Max Position
input int delay = 2;
input int threshold = 2; // Trend delta
input long magicNumber = 8888; // Expert ID
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;

int slippage = 10;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double   bufMA1[3], 
         bufMA2[3], 
         keltnerUp[3], 
         keltnerMid[3], 
         keltnerLow[3],
         priceClose[3], 
         priceOpen[3];

int OnInit()
  {
//---
   Alert("Init Kelter MA scalping strategy");
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
   
   // Collect data
   int arrSize = 3;
   for(int i=0; i<arrSize-1; i++) {
      bufMA1[i] = iMA(NULL,TIME_FRAME,5,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA2[i] = iMA(NULL,TIME_FRAME,100,0,MODE_SMA,PRICE_CLOSE,i);
      keltnerUp[i] = iCustom(NULL,TIME_FRAME,"Keltner_Channel",50,0,i);
      keltnerMid[i] = iCustom(NULL,TIME_FRAME,"Keltner_Channel",50,1,i);
      keltnerLow[i] = iCustom(NULL,TIME_FRAME,"Keltner_Channel",50,2,i);
   }
   
   CopyClose(Symbol(), TIME_FRAME, 0, arrSize, priceClose);
   CopyOpen(Symbol(), TIME_FRAME, 0, arrSize, priceOpen);
   
   // Last price
   int shift = 0;
   double ma1   = NormalizeDouble(bufMA1[shift], _Digits);
   double ma2   = NormalizeDouble(bufMA2[shift], _Digits);
   double upKN  = NormalizeDouble(keltnerUp[shift], _Digits);
   double midKN = NormalizeDouble(keltnerMid[shift], _Digits);
   double lowKN = NormalizeDouble(keltnerLow[shift], _Digits);
   double close = NormalizeDouble(priceClose[shift], _Digits);
   double open  = NormalizeDouble(priceOpen[shift], _Digits);

   // Signal
   bool isMA1Upward = false;
   bool isMA1Downward = false;
   bool isBuy = false;
   bool isSell = false;
   
   int totalPos = countPosition(magicNumber);
   isMA1Upward = idcUpward(bufMA1, arrSize, threshold);   
   isMA1Downward = idcDownward(bufMA1, arrSize, threshold);
   
   if(totalPos < maxPos) {
      // Check for BUY signal
      if(isMA1Upward) {
         if(ma1 > ma2 && close > upKN) {
            isBuy = true;
         }
      } 
      
      // Check for SELL signal
      if(isMA1Downward) {
         if(ma1 < ma2 && close < lowKN) {
            isSell = true;
         }
      }
      
      //+------------------------------------------------------------------+
      //| CHECK DUPLICATE POSITIONS                                        |
      //+------------------------------------------------------------------+   
      if(isBuy || isSell) {
         long delaySec = delay * PeriodSeconds(TIME_FRAME);
         bool recentClose = isRecentClose(delaySec);   
         if(recentClose) {
            isBuy = false;
            isSell = false;
         }
      }
      
      int delta = 10;
      if(isBuy || isSell) {
         // Manage orders
         if(isBuy) {
            int orderID = OrderSend(NULL,OP_BUY,lotSize,Ask,slippage,lowKN,0, "Buy MA", magicNumber);
            if(orderID < 0) Alert("Order rejected. Order error: " + ErrorDescription(GetLastError()));
         } else if(isSell) {
            int orderID = OrderSend(NULL,OP_SELL,lotSize,Bid,slippage,upKN,0, "Sell MA", magicNumber);
            if(orderID < 0) Alert("order rejected. Order error: " + ErrorDescription(GetLastError()));
         }
      }
   }


   if(totalPos >= maxPos) {
      //+------------------------------------------------------------------+
      //| MOVE STOPLOSS                                                    |
      //+------------------------------------------------------------------+
      bool moveSL = true;
      int SLPips = 10;
      if (moveSL) {
        for(int i=0; i<OrdersTotal(); i++) {
           if(OrderSelect(i, SELECT_BY_POS) == true) {
              double oldSL = OrderStopLoss();
              //double newSL = calSL(true,upKN,SLPips);
              //if(OrderType() == 0) {
              //   double newSL = calSL(true,lowKN,SLPips);
              //}
              double newSL = calSL(true,midKN,SLPips);
               
              if(newSL != oldSL && MathAbs(newSL - oldSL) > 0.1) {
                 modifyOrder(newSL,0);//Modify it!
              }
           }
         }
      }

      //+------------------------------------------------------------------+
      //| TAKE PROFIT 50%                                                  |
      //+------------------------------------------------------------------+
      //for(int i=0; i<OrdersTotal(); i++) {
      //   if(OrderSelect(i, SELECT_BY_POS) == true) {
      //      int ticket = OrderTicket();
      //      double size = OrderLots();
      //      if(OrderType() == 0 && !isMA1Upward && OrderLots() == lotSize) {
      //         OrderClose(ticket, lotSize/2, Bid, slippage, 0);
      //      }
      //      if(OrderType() == 1 && !isMA1Downward && OrderLots() == lotSize) {
      //         OrderClose(ticket, lotSize/2, Ask, slippage, 0);
      //      }
      //   }
      //}
   }



  }
//+------------------------------------------------------------------+

void modifyOrder(double SL, double TP) {
   int ticket = OrderTicket();
   double price = OrderOpenPrice();
   Alert ("Modification order: ",ticket,". Awaiting response..");
   bool stt = OrderModify(ticket,price,SL,TP,0);
   if (stt == false) {
      Alert ("Failed to modify order: ", getErr());
   }
}