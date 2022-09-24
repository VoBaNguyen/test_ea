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
#include <models/candle.mqh>;

//+------------------------------------------------------------------+
//| Input EA                                                         |
//+------------------------------------------------------------------+
input double riskLevel = 0.01;
input int TPPips = 200;
input int SLPips = 100;
input int maxPos = 1; //Max Position
input int delay = 1;
input int slippage = 10;
input long magicNumber = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;
int threshold = 0.0;
int convergenceThreshold = 1; 


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+



double lotSize = 0.1;
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
   // Signal
   int totalPos = countPosition(magicNumber);   
   if(totalPos < maxPos) {
      bool isBuy = false;
      bool isSell = false;
      
      // Check insidebar
      string grpInfo[2];
      grpInfo[0] = "undefined";
      grpInfo[1] = "undefined";
      classifyGrpCandle(1, grpInfo, PERIOD_CURRENT);
      if(grpInfo[1] == "insidebar") {
         if(grpInfo[0] == "sell") {
            isSell = true;
         }
         else if(grpInfo[0] == "buy") {
            isBuy = true;
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
      //| SEND ORDERS                                                      |
      //+------------------------------------------------------------------+   
      if(isBuy || isSell) {
         MyAccount account("Nguyen", "Vo", magicNumber);
         double ATRCurr = 2*iATR(Symbol(),PERIOD_CURRENT,14,1);
         
         lotSize = calcLot(account.info.BALANCE, riskLevel, ATRCurr/getPip());
         // Manage orders
         if(isBuy) {
            double TP = Ask + ATRCurr;
            double SL = Ask - ATRCurr;
            ticket = sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, SL, TP, "Buy MA", magicNumber);
         } else if(isSell) {
            double TP = Ask - ATRCurr;
            double SL = Ask + ATRCurr;
            ticket = sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, SL, TP, "Buy MA", magicNumber);
         }
      }
   }



//   if(totalPos == maxPos) {
//      +------------------------------------------------------------------+
//      | TAKE PROFIT 50%                                                  |
//      +------------------------------------------------------------------+
//      if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
//         if(orderProfit(ticket) > TPPips/2 && OrderLots() == lotSize) {
//             Move SL to entry
//            double open = OrderOpenPrice();            
//            if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES) == true) {
//               modifyOrder(ticket, open, open, OrderTakeProfit());//Modify it!
//            }
//            
//             TP 50%
//            if(OrderType() == 0) {
//               closeOrder(ticket, OrderLots()/2, Bid, slippage);
//            }
//            if(OrderType() == 1) {
//               closeOrder(ticket, OrderLots()/2, Ask, slippage);
//            }
//         }
//      }
//   }
   
  }
//+------------------------------------------------------------------+
