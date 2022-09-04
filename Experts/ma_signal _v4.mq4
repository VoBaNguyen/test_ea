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
int threshold = 0.0;
int convergenceThreshold = 1; 


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


int arrSize = 10;
double idcMAPrev[10],
       idcMACur[10],
       idcADX[10];
int shiftMA = 1;

double lotSize = 0.01;
int ticket = 0;


int OnInit()
  {
   Alert("Init MA Scaplt strategy");
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
   for(int i=1; i<arrSize+1; i++) {
      idcMAPrev[i-1] = iMA(Symbol(),TIME_FRAME,10,shiftMA,MODE_SMA,PRICE_CLOSE,i);
      idcMACur[i-1] = iMA(Symbol(),TIME_FRAME,10,0,MODE_SMA,PRICE_CLOSE,i);
      idcADX[i-1] = iADX(NULL, TIME_FRAME, 20, PRICE_CLOSE, MODE_MAIN,i);
   }
   
   // Signal
   int totalPos = countPosition(magicNumber);   
   if(totalPos < maxPos) {
      bool isBuy = false;
      bool isSell = false;
      
      // Check for BUY signal
      bool MAPrevUpward   = idcUpward(idcMAPrev, threshold);
      bool MAPrevDownward = idcDownward(idcMAPrev, threshold);
      bool MACurUpward    = idcUpward(idcMACur, threshold);
      bool MACurDownward  = idcDownward(idcMACur, threshold);

       if(MAPrevUpward && !MACurUpward) {
         isSell = true;
       }
       if(MAPrevDownward && !MACurDownward) {
         isBuy = true;
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
         if(orderProfit(ticket) > TPPips/2 && OrderLots() == lotSize) {
            // Move SL to entry
            double open = OrderOpenPrice();            
            if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES) == true) {
               modifyOrder(ticket, open, open, OrderTakeProfit());//Modify it!
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
