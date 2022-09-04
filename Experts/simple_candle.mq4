//+------------------------------------------------------------------+
//|                                                simple_candle.mq4 |
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
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;

int ticket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Alert("Init simple EA candle action");
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   int c0 = candleType(Symbol(), TIME_FRAME, 1);
   int c1 = candleType(Symbol(), TIME_FRAME, 2);
   int c2 = candleType(Symbol(), TIME_FRAME, 3);
   
   bool isBuy = false;
   bool isSell = false;
   // BUY
   if(c0 == 0 && c1 == 1 && c2 == 0 || c0 == 0 && c1 == 0 ) {
      isBuy = true;
   }
   // SELL
   if(c0 == 1 && c1 == 0 && c2 == 1 || c0 == 1 && c1 == 1 ) {
      isSell = true;
   }

   int totalPos = countPosition(magicNumber);
   if(isBuy || isSell) {
      MyAccount account("Nguyen", "Vo", magicNumber);
      double lotSize = calcLot(account.info.BALANCE, riskLevel, SLPips);   
      
      //+------------------------------------------------------------------+
      //| CHECK DUPLICATE POSITIONS                                        |
      //+------------------------------------------------------------------+   
      long delaySec = delay * PeriodSeconds(TIME_FRAME);
      bool recentClose = isRecentClose(delaySec);   
      if(!recentClose) {

         //+------------------------------------------------------------------+
         //| SEND ORDER                                                       |
         //+------------------------------------------------------------------+ 
         if(totalPos == 0) {
            if(isBuy) {
               ticket = sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, 0, 0, "Candle action", magicNumber);
            } else if(isSell) {
               ticket = sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, 0, 0, "Candle action", magicNumber);
            }
         }
         //+------------------------------------------------------------------+
         //| CLOSE OORDER AND OPEN OPPOSITE ORDER                            |
         //+------------------------------------------------------------------+ 
         else {
            selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES);
            if(OrderType() == 0 && isSell) {
               closeOrder(ticket, OrderLots(), Bid, slippage);
               ticket = sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, 0, 0, "Candle action", magicNumber);
            }
            if(OrderType() == 1 && isBuy) {
               closeOrder(ticket, OrderLots(), Ask, slippage);
               ticket = sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, 0, 0, "Candle action", magicNumber);
            }
         }
      }
   }

  }
//+------------------------------------------------------------------+
