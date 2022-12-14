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
input double riskLevel = 0.01;
input int TPPips = 30;
input int SLPips = 30;
input int maxPos = 1; //Max Position
input int delay = 1;
input int slippage = 10;
input long magicNumber = 9999; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_M5;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double EMA50[4], 
       EMA100[4], 
       EMA150[4], 
       priceClose[4], 
       priceOpen[4];

double lotSize = 0.01;
int ticket = 0;
int arrSize = 4;
int sidewayThreshold = 0.2;
double multiple = 1;
double deltaPrice = 2;

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
   for(int i=0; i < arrSize; i++) {
      EMA50[i] = iMA(NULL,TIME_FRAME,50,0,MODE_EMA,PRICE_CLOSE,i);
      EMA100[i] = iMA(NULL,TIME_FRAME,100,0,MODE_EMA,PRICE_CLOSE,i);
      EMA150[i] = iMA(NULL,TIME_FRAME,150,0,MODE_EMA,PRICE_CLOSE,i);
      priceClose[i] = iClose(NULL, TIME_FRAME,i);
      priceOpen[i] = iOpen(NULL, TIME_FRAME,i);  
   }
   
   // Last price
   int shift = 0;
   double ema50 = NormalizeDouble(EMA50[shift], _Digits);
   double ema100 = NormalizeDouble(EMA100[shift], _Digits);
   double ema150 = NormalizeDouble(EMA150[shift], _Digits);
   double close = NormalizeDouble(priceClose[shift], _Digits);
   double open  = NormalizeDouble(priceOpen[shift], _Digits);


   // Signal

   bool isBuy = false;
   bool isSell = false;
   int totalPos = countPosition(magicNumber);
   
   if(totalPos < maxPos) {
      // Check for BUY signal
      bool EMA50Up = idcUpward(EMA50, arrSize);
      bool EMA100Up = idcUpward(EMA100, arrSize);
      bool EMA150Up = idcUpward(EMA150, arrSize);
      bool upward = EMA50Up && EMA100Up && EMA150Up;
      
      bool EMA5Down = idcDownward(EMA50, arrSize);
      bool EMA10Down = idcDownward(EMA100, arrSize);
      bool EMA15Down = idcDownward(EMA150, arrSize);
      bool downward = EMA5Down && EMA10Down && EMA15Down;
      
      bool divergence = isDivergence(EMA50, EMA100, arrSize);
      bool sideway = isSideway(EMA50, EMA100, arrSize, sidewayThreshold);
      
      // Check for BUY signal
      if(ema50 > ema100 && upward && divergence && !sideway) {
         bool parallel = isParallel(EMA50, EMA100, EMA150, arrSize);
         double limitPrice = ema50 + deltaPrice;
         if(parallel && Ask < limitPrice && !sideway) {
            isBuy = true;
         }
      }
      
      // Check for SELL signal
      if(ema50 < ema100 && downward && divergence && !sideway) {
         bool parallel = isParallel(EMA150, EMA100, EMA50, arrSize);
         double limitPrice = ema50 - deltaPrice;
         if(parallel && Bid > limitPrice && !sideway) {
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
      

      //+------------------------------------------------------------------+
      //| SEND ORDER                                                       |
      //+------------------------------------------------------------------+ 
      if(isBuy || isSell) {
         MyAccount account("Nguyen", "Vo", magicNumber);
         lotSize = calcLot(account.info.BALANCE, riskLevel, SLPips);
         // Manage orders
         if(isBuy) {
            double TP = calTP(true, Ask,TPPips);
            double SL = calSL(true, Bid,SLPips);
            if(close > ema50) {
               SL = ema50;
            }
            ticket = sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, SL, 0, "Buy MA", magicNumber);
         } else if(isSell) {
            double TP = calTP(false, Ask,TPPips);
            double SL = calSL(false, Bid,SLPips);
            if(close < ema50) {
               SL = ema50;
            }
            ticket = sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, SL, 0, "Buy MA", magicNumber);
         }
      }
   }



   if(totalPos == maxPos) {
      //+------------------------------------------------------------------+
      //| MOVE STOPLOSS                                                    |
      //+------------------------------------------------------------------+
      if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
         double oldSL = OrderStopLoss();
         double newSL = ema50;
         if(OrderType() == 0 && close > ema50) {
            if(newSL > oldSL) {
               modifyOrder(ticket, OrderOpenPrice(), newSL, OrderTakeProfit());
            }  
         }
         if(OrderType() == 1 && close < ema50) {
            if(newSL < oldSL) {
               modifyOrder(ticket, OrderOpenPrice(), newSL, OrderTakeProfit());
            }
         }
         
         // CLOSE ORDER BASE ON PROFIT
         int range = 2;
         bool recentOpen = isRecentOpen(range*PeriodSeconds(TIME_FRAME));         
         bool isGreen = isCandlesType(Symbol(), TIME_FRAME, range, 0);
         bool isRed = isCandlesType(Symbol(), TIME_FRAME, range, 1);

         if(!recentOpen) {
            if(OrderType() == 0 && isRed) {
               closeOrder(ticket, OrderLots(), Bid, slippage);
            } else if (OrderType() == 1 && isGreen) {
               closeOrder(ticket, OrderLots(), Ask, slippage);
            }
         }
      }      
   }
  }
//+------------------------------------------------------------------+
