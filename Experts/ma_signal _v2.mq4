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
input int slippage = 10;
input long magicNumber = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_H1;
input ENUM_TIMEFRAMES TIME_FRAME_SLOW = PERIOD_H4;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double bufMA10[4], 
       bufMA20[4], 
       bufMA50[4], 
       bufMA200[4],
       priceClose[4], 
       priceOpen[4],
       bufADX[4];
int ticket = 0;
double lotSize = 0.0;
int threshold = 4;


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
   int arrSize = ArraySize(bufMA10);
   for(int i=1; i < ArraySize(bufMA10)+1; i++) {
      bufMA10[i-1] = iMA(Symbol(),TIME_FRAME,10,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA20[i-1] = iMA(Symbol(),TIME_FRAME,20,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA50[i-1] = iMA(Symbol(),TIME_FRAME,50,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA200[i-1] = iMA(Symbol(),TIME_FRAME,200,0,MODE_SMA,PRICE_CLOSE,i);
      bufADX[i-1] = iADX(Symbol(), TIME_FRAME, 20, PRICE_CLOSE, MODE_MAIN,i);
      Alert(bufMA10[i-1]);
   }
   Alert("====================\n\n");
   
   
   CopyClose(Symbol(), TIME_FRAME, 0, arrSize, priceClose);
   CopyOpen(Symbol(), TIME_FRAME, 0, arrSize, priceOpen);
   
   // Last price
   int shift = 0;
   double ma10  = NormalizeDouble(bufMA10[shift], _Digits);
   double ma20  = NormalizeDouble(bufMA20[shift], _Digits);
   double ma50  = NormalizeDouble(bufMA50[shift], _Digits);
   double ma200 = NormalizeDouble(bufMA200[shift], _Digits);
   double close = NormalizeDouble(priceClose[shift], _Digits);
   double open  = NormalizeDouble(priceOpen[shift], _Digits);
   double ADX   = NormalizeDouble(bufADX[1], _Digits);
   int totalPos = countPosition(magicNumber);
   
   if(totalPos < maxPos) {
      bool isBuy = false;
      bool isSell = false;      
      bool ADXUpward = idcUpward(bufADX, threshold);

      bool MA10Upward = idcUpward(bufMA10);
      bool MA20Upward = idcUpward(bufMA20);
      bool MA50Upward = idcUpward(bufMA50);
      bool upward = MA10Upward && MA20Upward && MA50Upward;
       
      bool MA10Downward = idcDownward(bufMA10);
      bool MA20Downward = idcDownward(bufMA20);
      bool MA50Downward = idcDownward(bufMA50);
      bool downward = MA10Downward && MA20Downward && MA50Downward;
   
   
      if(ADXUpward && 20 < ADX && ADX < 45) {
         if(ma10 > ma20 && ma20 > ma50 && upward) {
            isBuy = true;
         }
         //else if (MA20Upward && ma10 > ma20 && ma10 > ma50 && ma10 > ma200 && ADX > 20 && ADX < 40) {
         //   isBuy = true;
         //}
            
         if(ma10 < ma20 && ma20 < ma50 && downward) {
            isSell = true;
         } 
         //else if (MA20Downward && ma10 < ma20 && ma10 < ma50 && ma10 < ma200 && ADX > 20 && ADX < 40) {
         //   isSell = true;
         //}
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
   
      //+------------------------------------------------------------------+
      //| SEND ORDERS                                                      |
      //+------------------------------------------------------------------+   
      if(isBuy || isSell) {
         MyAccount account("Nguyen", "Vo", magicNumber);
         lotSize = calcLot(account.info.BALANCE, riskLevel, SLPips);
         if(isBuy && idcUpward(bufMA200)) {
            lotSize = lotSize*2;
         } else if(isSell && idcDownward(bufMA200)) {
            lotSize = lotSize*2;
         }
         
         // Manage orders
         if(isBuy) {
            double TP = calTP(true, Ask,TPPips);
            double SL = calSL(true, Bid,SLPips);
            ticket = sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, SL, TP, "Buy MA", magicNumber);
         } else if(isSell) {
            double TP = calTP(false, Ask,TPPips);
            double SL = calSL(false, Bid,SLPips);
            ticket = sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, SL, TP, "Buy MA", magicNumber);
         }
      }
   }


   if(totalPos == maxPos) {
      //+------------------------------------------------------------------+
      //| TAKE PROFIT 50%                                                  |
      //+------------------------------------------------------------------+
      if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
         if(orderProfit(ticket) > TPPips/2 && OrderLots() > lotSize/2) {
            // Move SL to entry
            double open = OrderOpenPrice();            
            if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES) == true) {
               modifyOrder(ticket, open, open, OrderTakeProfit());
            }
            
            // TP 50%
            if(OrderType() == 0) {
               closeOrder(ticket, OrderLots()/2, Bid, slippage);
            }
            if(OrderType() == 1) {
               closeOrder(ticket, OrderLots()/2, Ask, slippage);
            }
         }
      }
   }
   
   
  }
//+------------------------------------------------------------------+


//void takeProfitPart(int ticket, int TPPips, int tpTimes) {
//   // Move SL to entry
//   double open = OrderOpenPrice();            
//   if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES) == true) {
//      modifyOrder(ticket, open, open, OrderTakeProfit());
//   }
//   
//   // TP 50%
//   if(OrderType() == 0) {
//      closeOrder(ticket, OrderLots()/2, Bid, slippage);
//   }
//   if(OrderType() == 1) {
//      closeOrder(ticket, OrderLots()/2, Ask, slippage);
//   }
//}