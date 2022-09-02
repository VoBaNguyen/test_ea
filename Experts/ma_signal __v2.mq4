/***
 Description: MA signal V2
   - Su dung MA10,20,50,200
   - Ket hop ADX khung H1
   - Dung khung H4 de xac dinh suc manh cua xu huong - Tranh case sideway
*/


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
//| Include custom modules                                           |
//+------------------------------------------------------------------+
#include <common/utils.mqh>;
#include <models/account.mqh>;

//+------------------------------------------------------------------+
//| Input EA                                                         |
//+------------------------------------------------------------------+
input double riskLevel = 0.05;
input int TPPips = 200;
input int SLPips = 100;
input int maxPos = 1; //Max Position
input int delay = 1;
input long magicNumber = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_H1;
input ENUM_TIMEFRAMES TIME_FRAME_SLOW = PERIOD_H4;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double bufMA10[6], 
       bufMA20[6], 
       bufMA50[6], 
       bufMA200[6],
       priceClose[6], 
       priceOpen[6],
       bufADXFast[6],
       bufADXSlow[6];

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
      bufMA10[i] = iMA(NULL,TIME_FRAME,10,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA20[i] = iMA(NULL,TIME_FRAME,20,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA50[i] = iMA(NULL,TIME_FRAME,50,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA200[i] = iMA(NULL,TIME_FRAME,200,0,MODE_SMA,PRICE_CLOSE,i);
      bufADXFast[i] = iADX(NULL, TIME_FRAME, 20, PRICE_CLOSE, MODE_MAIN,i);
      bufADXSlow[i] = iADX(NULL, TIME_FRAME_SLOW, 20, PRICE_CLOSE, MODE_MAIN,i);
   }
   
   
   CopyClose(Symbol(), TIME_FRAME, 0, arrSize, priceClose);
   CopyOpen(Symbol(), TIME_FRAME, 0, arrSize, priceOpen);
   
   // Last price
   double ma10  = NormalizeDouble(bufMA10[1], _Digits);
   double ma20  = NormalizeDouble(bufMA20[1], _Digits);
   double ma50  = NormalizeDouble(bufMA50[1], _Digits);
   double ma200 = NormalizeDouble(bufMA200[1], _Digits);
   double close = NormalizeDouble(priceClose[1], _Digits);
   double open  = NormalizeDouble(priceOpen[1], _Digits);
   double ADXFast   = NormalizeDouble(bufADXFast[1], _Digits);
   double ADXSlow   = NormalizeDouble(bufADXSlow[1], _Digits);

   // Signal
   bool ADXUpward = false;
   bool MA10Upward = false;
   bool MA10Downward = false;
   bool isBuy = false;
   bool isSell = false;
   bool upward = false;
   bool downward = false;
   
   int totalPos = countPosition(magicNumber);
   if(totalPos < maxPos) {
      // Check for BUY signal
      ADXUpward = idcUpward(bufADXFast, arrSize, threshold);
      MA10Upward = idcUpward(bufMA10, arrSize, threshold);   
      MA10Downward = idcDownward(bufMA10, arrSize, threshold);
      if(ADXUpward && ADXSlow >= 20) {      
         upward = crossUpward(bufMA10[0],bufMA10[1],bufMA20[0],bufMA20[1]);
         upward = upward || crossUpward(bufMA10[0],bufMA10[1],bufMA50[0],bufMA50[1]);
         upward = upward || crossUpward(bufMA10[0],bufMA10[1],bufMA200[0],bufMA200[1]);
         bool ma20Upward = idcUpward(bufMA20,arrSize);
         bool ma50Upward = idcUpward(bufMA50,arrSize);
         bool ma200Upward = idcUpward(bufMA200,arrSize);
         bool upward = upward && ma20Upward && ma50Upward && ma200Upward;
      
         if(ma10 > ma20 && ma20 > ma50 && ma50 > ma200 && upward) {
            isBuy = true;
         } else if (ma10 > ma20 && ma10 > ma50 && ma10 > ma200 && ADXFast > 20 && ADXFast < 40 && MA10Upward) {
            isBuy = true;
         }

         downward = crossDownward(bufMA10[0],bufMA10[1],bufMA20[0],bufMA20[1]);
         downward = downward || crossDownward(bufMA10[0],bufMA10[1],bufMA50[0],bufMA50[1]);
         downward = downward || crossDownward(bufMA10[0],bufMA10[1],bufMA200[0],bufMA200[1]);
         bool ma20Downward = idcDownward(bufMA20,arrSize);
         bool ma50Downward = idcDownward(bufMA50,arrSize);
         bool ma200Downward = idcDownward(bufMA200,arrSize);
         bool downward = downward && ma20Downward && ma50Downward && ma200Downward;
         
         // Check for SELL signal
         if(ma10 < ma20 && ma20 < ma50 && ma50 < ma200 && downward) {
            isSell = true;
         } else if (ma10 < ma20 && ma10 < ma50 && ma10 < ma200 && ADXFast > 20 && ADXFast < 40 && MA10Downward) {
            isSell = true;
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
         if(orderID < 0) Alert("Order rejected. Order error: " + getErr());
      } else if(isSell) {
         double TP = calTP(false, Ask,TPPips);
         double SL = calSL(false, Bid,SLPips);
         int orderID = OrderSend(NULL,OP_SELL,lotSize,Bid,10,SL,TP, "Sell MA", magicNumber);
         if(orderID < 0) Alert("order rejected. Order error: " + getErr());
      }
   }
   
   // Close positions
   //for(int i=0; i<PositionsTotal(); i++) {
   //   ulong ticket = PositionGetTicket(i);
   //   PositionSelectByTicket(ticket);
   //   double prevMa10 = NormalizeDouble(bufMA10[count-1], Digits());
   //   double prevMa20 = NormalizeDouble(bufMA10[count-1], Digits());
   //   if(magicNumber == PositionGetInteger(POSITION_MAGIC)) {
   //      // Close BUY position
   //      if(PositionGetInteger(POSITION_TYPE) == 0) {
   //         if(prevMa10 < prevMa20) {
   //            closePosition(ticket);
   //         }
   //      }
   //      // Close SELL position
   //      else if(PositionGetInteger(POSITION_TYPE) == 1) {
   //         if(prevMa10 > prevMa20) {
   //            closePosition(ticket);
   //         }
   //      }
   //   }
   //}
   
   
  }
//+------------------------------------------------------------------+
