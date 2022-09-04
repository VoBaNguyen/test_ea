/***
 Description: MA signal V2
   - Su dung MA10,20,50,200
   - Ket hop ADX khung H1
   - Dung khung H4 de xac dinh suc manh cua xu huong - Tranh case sideway
   - Ket hop chot lai 50% o 100 pip va doi SL
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
double bufMA10[6], 
       bufMA20[6], 
       bufMA50[6], 
       bufMA200[6],
       priceClose[6], 
       priceOpen[6],
       bufADXFast[6],
       bufADXSlow[6];

double lotSize = 0.01;
int ticket = 0;


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

   bool isBuy = false;
   bool isSell = false;
   int totalPos = countPosition(magicNumber);
   
   if(totalPos < maxPos) {
      // Check for BUY signal
      bool ADXUpward = idcUpward(bufADXFast, arrSize, threshold);
      bool MA10Upward = idcUpward(bufMA10, arrSize, threshold);
      bool MA20Upward = idcUpward(bufMA20, arrSize, threshold);
      bool MA50Upward = idcUpward(bufMA50, arrSize, threshold);
      bool MA200Upward = idcUpward(bufMA200, arrSize, threshold);
      bool upward = MA10Upward && MA20Upward && MA50Upward && MA200Upward;
      
      bool MA10Downward = idcDownward(bufMA10, arrSize, threshold);
      bool MA20Downward = idcDownward(bufMA20, arrSize, threshold);
      bool MA50Downward = idcDownward(bufMA50, arrSize, threshold);
      bool MA200Downward = idcDownward(bufMA200, arrSize, threshold);
      bool downward = MA10Downward && MA20Downward && MA50Downward && MA200Downward;
      
      if(ADXUpward) {      
         if(ma10 > ma20 && ma20 > ma50 && ma50 > ma200 && upward) {
            isBuy = true;
         } else if (ma10 > ma20 && ma10 > ma50 && ADXFast > 20 && ADXFast < 40 && MA10Upward) {
            isBuy = true;
         }
      }
      if(ADXUpward) {      
         // Check for SELL signal
         if(ma10 < ma20 && ma20 < ma50 && ma50 < ma200 && downward) {
            isSell = true;
         } else if (ma10 < ma20 && ma10 < ma50 && ADXFast > 20 && ADXFast < 40 && MA10Downward) {
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
      
      
      if(isBuy || isSell) {
         MyAccount account("Nguyen", "Vo", magicNumber);
         lotSize = calcLot(account.info.BALANCE, riskLevel, SLPips);
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
         double ordLot = OrderLots();
         double profit = orderProfit(ticket);
         if(profit > TPPips/2 && ordLot == lotSize) {
            // Move SL to entry
            double open = OrderOpenPrice();            
            if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES) == true) {
               modifyOrder(ticket, open, open, OrderTakeProfit());//Modify it!
            }
            
            // TP 50%
            if(OrderType() == 0) {
               closeOrder(ticket, ordLot/2, Bid, slippage);
            }
            if(OrderType() == 1) {
               closeOrder(ticket, ordLot/2, Ask, slippage);
            }
         }
      }
   }
   
  }
//+------------------------------------------------------------------+
