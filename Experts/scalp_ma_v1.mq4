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
input double riskLevel = 0.01;
input int TPPips = 30;
input int SLPips = 30;
input int maxPos = 1; //Max Position
input int delay = 1;
input long magicNumber = 8888;
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double buf1[6], buf2[6], buf3[6],
       priceClose[6], priceOpen[6],
       bufADX[6];

int OnInit()
  {
//---
   Alert("Init MA Scaplt strategy");
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
   int arrSize = 6;
   int threshold = 4;
   for(int i=0; i<arrSize-1; i++) {
      buf1[i] = iMA(NULL,TIME_FRAME,20,0,MODE_SMA,PRICE_CLOSE,i);
      buf2[i] = iMA(NULL,TIME_FRAME,40,0,MODE_SMA,PRICE_CLOSE,i);
      buf3[i] = iMA(NULL,TIME_FRAME,100,0,MODE_SMA,PRICE_CLOSE,i);
      bufADX[i] = iADX(NULL, TIME_FRAME, 20, PRICE_CLOSE, MODE_MAIN,i);
   }
   
   
   CopyClose(Symbol(), TIME_FRAME, 0, arrSize, priceClose);
   CopyOpen(Symbol(), TIME_FRAME, 0, arrSize, priceOpen);
   
   // Last price
   double ma1  = NormalizeDouble(buf1[1], _Digits);
   double ma2  = NormalizeDouble(buf2[1], _Digits);
   double ma3  = NormalizeDouble(buf3[1], _Digits);
   double close = NormalizeDouble(priceClose[1], _Digits);
   double open  = NormalizeDouble(priceOpen[1], _Digits);
   double ADX   = NormalizeDouble(bufADX[1], _Digits);

   // Signal
   bool isADXUpward = false;
   bool isMA1Upward = false;
   bool isMA1Downward = false;
   bool isBuy = false;
   bool isSell = false;
   
   int totalPos = countPosition(magicNumber);
   if(totalPos < maxPos) {
      // Check for BUY signal
      isADXUpward = idcUpward(bufADX, arrSize, threshold);
      isMA1Upward = idcUpward(buf1, arrSize);   
      isMA1Downward = idcDownward(buf1, arrSize);
      if(isADXUpward) {
         
         if(isMA1Upward) {
            if(ma1 > ma2 && ma2 > ma3) {
               isBuy = true;
            } else if (ma1 > ma2 && ma1 > ma3 && ADX > 20 && ADX < 40) {
               isBuy = true;
            }
         } else if (isMA1Downward) {
            // Check for SELL signal
            if(ma1 < ma2 && ma2 < ma3) {
               isSell = true;
            } else if (ma1 < ma2 && ma1 < ma3 && ADX > 20 && ADX < 40) {
               isSell = true;
            }
         }
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


   if(isBuy || isSell) {
      MyAccount account("Nguyen", "Vo", magicNumber);
      double lotSize = calcLot(account.info.BALANCE, riskLevel, SLPips);
      // Manage orders
      if(isBuy) {
         double TP = calTP(true, Ask,TPPips);
         double SL = calSL(true, Bid,SLPips);
         int orderID = OrderSend(NULL,OP_BUY,lotSize,Ask,10,SL,TP, "Buy MA", magicNumber);
         if(orderID < 0) Alert("Order rejected. Order error: " + ErrorDescription(GetLastError()));
      } else if(isSell) {
         double TP = calTP(false, Ask,TPPips);
         double SL = calSL(false, Bid,SLPips);
         int orderID = OrderSend(NULL,OP_SELL,lotSize,Bid,10,SL,TP, "Sell MA", magicNumber);
         if(orderID < 0) Alert("order rejected. Order error: " + ErrorDescription(GetLastError()));
      }
   }
  }
//+------------------------------------------------------------------+
