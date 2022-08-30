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
input int TPPips = 100;
input int SLPips = 50;
input int stdDev = 5;
input int maxPos = 1; //Max Position
input int delayHours = 1;
input long magicNumber = 7777;
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_H1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int MA10Handler, MA20Handler, MA50Handler, MA200Handler, ADXHandler;
double bufferMA10[], bufferMA20[], bufferMA50[], bufferMA200[],
       priceClose[], priceOpen[],
       bufferADX[];

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
   int count = 5;
   for(int i=0; i<count; i++) {
      bufferMA10[i] = iMA(NULL,TIME_FRAME,10,0,MODE_SMA,PRICE_CLOSE,i);
      bufferMA20[i] = iMA(NULL,TIME_FRAME,20,0,MODE_SMA,PRICE_CLOSE,i);
      bufferMA50[i] = iMA(NULL,TIME_FRAME,50,0,MODE_SMA,PRICE_CLOSE,i);
      bufferMA200[i] = iMA(NULL,TIME_FRAME,200,0,MODE_SMA,PRICE_CLOSE,i);
      bufferADX[i] = iADX(NULL, TIME_FRAME, 20, PRICE_CLOSE, MODE_MAIN,i);
   }
   
   
   CopyClose(Symbol(), TIME_FRAME, 0, count, priceClose);
   CopyOpen(Symbol(), TIME_FRAME, 0, count, priceOpen);
   
   // Last price
   int shift = 1;
   double ma10  = NormalizeDouble(bufferMA10[count-shift], Digits());
   double ma20  = NormalizeDouble(bufferMA20[count-shift], Digits());
   double ma50  = NormalizeDouble(bufferMA50[count-shift], Digits());
   double ma200 = NormalizeDouble(bufferMA200[count-shift], Digits());
   double close = NormalizeDouble(priceClose[count-shift], Digits());
   double open  = NormalizeDouble(priceOpen[count-shift], Digits());
   double ADX   = NormalizeDouble(bufferADX[count-shift], Digits());

   // Signal
   bool isADXUpward = false;
   bool isBuy = false;
   bool isSell = false;
   bool isUpward = false;
   bool isDownward = false;
   
   int totalPos = countPosition(magicNumber);
   if(totalPos < maxPos) {
      // Check for BUY signal
      isADXUpward = idcUpward(ADXHandler, 0, count, 4);
      
      if(isADXUpward) {
         isUpward = crossUpward(MA10Handler, 0, MA20Handler, 0, count);
         isUpward = isUpward || crossUpward(MA10Handler, 0, MA50Handler, 0, count);
         isUpward = isUpward || crossUpward(MA10Handler, 0, MA200Handler, 0, count);
         bool ma20Upward = idcUpward(MA20Handler, 0, count);
         bool ma50Upward = idcUpward(MA50Handler, 0, count);
         bool ma200Upward = idcUpward(MA200Handler, 0, count);
         bool upward = isUpward && ma20Upward && ma50Upward && ma200Upward;
      
         if(ma10 > ma20 && ma20 > ma50 && ma50 > ma200 && upward) {
            isBuy = true;
         } else if (ma10 > ma20 && ma10 > ma50 && ma10 > ma200 && ADX > 20 && ADX < 40) {
            isBuy = true;
         }

         isDownward = crossDownward(MA10Handler, 0, MA20Handler, 0, count);
         isDownward = isDownward || crossDownward(MA10Handler, 0, MA50Handler, 0, count);
         isDownward = isDownward || crossDownward(MA10Handler, 0, MA200Handler, 0, count);
         bool ma20Downward = idcDownward(MA20Handler, 0, count);
         bool ma50Downward = idcDownward(MA50Handler, 0, count);
         bool ma200Downward = idcDownward(MA200Handler, 0, count);
         bool downward = isDownward && ma20Downward && ma50Downward && ma200Downward;
         
         // Check for SELL signal
         if(ma10 < ma20 && ma20 < ma50 && ma50 < ma200 && downward) {
            isSell = true;
         } else if (ma10 < ma20 && ma10 < ma50 && ma10 < ma200 && ADX > 20 && ADX < 40) {
            isSell = true;
         }  
      }
   }


   //+------------------------------------------------------------------+
   //| CHECK DUPLICATE POSITIONS                                        |
   //+------------------------------------------------------------------+ 
   MqlTick lastTick;
   SymbolInfoTick(Symbol(),lastTick);
   
   if(isBuy || isSell) {
      datetime lastHours = TimeCurrent() - (delayHours * 60 * 60);
      for(int i=0; i<OrdersHistoryTotal(); i++) {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == true) {
            datetime closeTime = OrderCloseTime();

            if(closeTime > lastHours) {
               isBuy = false;
               isSell = false;
            }
         }
      }
   }


   // Manage orders
   if(isBuy) {
      MyAccount account("Nguyen", "Vo", magicNumber);
      isBuy = false;
      double TP = calTP(true, Ask,TPPips);
      double SL = calSL(true, Bid,SLPips);
      int orderID = OrderSend(NULL,OP_BUYLIMIT,0.01,Ask,10,SL,TP);
      if(orderID < 0) Alert("order rejected. Order error: " + GetLastError());
   } else if(isSell) {
      MyAccount account("Nguyen", "Vo", magicNumber);
      isSell = false;
      double TP = calTP(false, Ask,TPPips);
      double SL = calSL(false, Bid,SLPips);
      int orderID = OrderSend(NULL,OP_SELLLIMIT,0.01,Ask,10,SL,TP);
      if(orderID < 0) Alert("order rejected. Order error: " + GetLastError());
   }
   
   
   // Close positions
   //for(int i=0; i<PositionsTotal(); i++) {
   //   ulong ticket = PositionGetTicket(i);
   //   PositionSelectByTicket(ticket);
   //   double prevMa10 = NormalizeDouble(bufferMA10[count-1], Digits());
   //   double prevMa20 = NormalizeDouble(bufferMA10[count-1], Digits());
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
