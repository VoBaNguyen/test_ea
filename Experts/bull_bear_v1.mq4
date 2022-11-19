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
input int slippage = 100;
input double atrMultiplier = 1; //ATR Multiplier
input long magicNumber = 7777; //EA Id
input ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
int threshold = 0.0;
int convergenceThreshold = 1; 
double bufMA20[3];

int bullAttacks = 0;
int bearAttacks = 0;
int limitAttacks = 3;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+



double lotSize = 0.1;
int ticket = 0;


int OnInit()
  {
   Alert("Init MA Scaplt strategy");
   iCustom(NULL,TimeFrame,"price_action\\xac_dinh_dinh_day",0,0);
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |7
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Alert("Remove strategy");
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   // Signal
   int totalPos = countPosition(magicNumber);

   //+------------------------------------------------------------------+
   //| CHECK CLOSE SIGNALS                                              |
   //+------------------------------------------------------------------+
   if(totalPos == maxPos) {
      // Close BUY signal
      bool isClose = false;
   
      // Close based on num attacks
      if(isBullBearBaseOneSide(1, "bull")) {
         bullAttacks++;
      } else if(isBullBearBaseOneSide(1, "bear")) {
         bearAttacks++;
      }
   
      if(bullAttacks >= limitAttacks || bearAttacks >= limitAttacks) {
         isClose = true;
      }
   
      //if(buySignal(2, 20) && !isBullBearBaseOneSide(1, "bull")) {
      //   isClose = true;
      //}
      
      // 2 consecutive candles is not bull
      if(!isBullBearBaseOneSide(1, "bull") && !isBullBearBaseOneSide(2, "bull")) {
         isClose = true;
      }
      
      if(isBullBearBaseOneSide(1, "bear")) {
         isClose = true;
      }
      
      RefreshRates();
      if(isClose) {
         selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES);
         closeOrder(ticket, OrderLots(), Bid, 100);
      }
      
   }   

   //+------------------------------------------------------------------+
   //| CHECK BUY/SELL SIGNAL                                            |
   //+------------------------------------------------------------------+  
   if(totalPos < maxPos) {
      bool isBuy = buySignalV2(1, 10);
      bool isSell = false;

      //+------------------------------------------------------------------+
      //| CHECK DUPLICATE POSITIONS                                        |
      //+------------------------------------------------------------------+   
      if(isBuy || isSell) {
         long delaySec = delay * PeriodSeconds(TimeFrame);
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
         double ATRCurr = iATR(Symbol(),TimeFrame,14,1);
         lotSize = calcLot(account.info.BALANCE, riskLevel, ATRCurr/getPip());
         lotSize = 0.5;
         // Manage orders
         double TP = 0;
         double SL = 0;
         if(isBuy) {
            ticket = sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, SL, TP, "Buy MA", magicNumber);
            bullAttacks = 0;
         } else if(isSell) {
            ticket = sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, SL, TP, "Buy MA", magicNumber);
            bearAttacks = 0;
         }
      }
   }
   
}
//+------------------------------------------------------------------+

bool buySignalV2(int shift, int range) {
   // Check Bull Attack Bear
   bool isBullAttack = isBullBearBaseOneSide(shift, "bull");
   if(isBullAttack) {

      // Count Bear attacks in this range
      int bullAttacks = 0;
      for(int idx=shift+1; idx<range; idx++) {
         if(isBullBearBaseOneSide(idx, "bull")) {
            return false;
         }
      }
   }
   
   return false;
}



bool buySignal(int shift, int range) {
   // Check Bull Attack Bear
   bool isBullAttack = isBullBearBaseOneSide(shift, "bull");
   if(isBullAttack) {
      // There's no Bull attack before this
      int lastBullAttackIdx = shift+range;
      for(int idx=1; idx<range; idx++) {
         if(isBullBearBaseOneSide(shift+idx, "bull")) {
            lastBullAttackIdx = shift+idx;
         }
         break;
      }
      
      // Count Bear attacks in this range
      int bearAttacks = 0;
      for(int idx=shift; idx<lastBullAttackIdx; idx++) {
         if(isBullBearBaseOneSide(idx, "bear")) {
            bearAttacks++;
         }
      }
      
      // Confirm signal
      // Alert("Bear attacks: ", bearAttacks);
      if(bearAttacks > 4) {
         return true;
      }
   }
   
   return false;
}



bool isBullBearBaseOneSide(int candleIdx, string type, double delta=0) {
   double priceArr[10];
   int range = ArraySize(priceArr);
   if(type == "bull") {
      for(int idx=0; idx<range; idx++) {
         priceArr[idx] = High[candleIdx+idx];
      }
      int maxIdx = ArrayMaximum(priceArr, WHOLE_ARRAY, 0);
      double lastVal = High[candleIdx] + delta;
      if(lastVal >= priceArr[maxIdx]) {
         return True;
      }
   }
   
   else if (type == "bear") {
      for(int idx=0; idx<range; idx++) {
         priceArr[idx] = Low[candleIdx+idx];
      }
      int minIdx = ArrayMinimum(priceArr, WHOLE_ARRAY, 0);
      double lastVal = Low[candleIdx] - delta;
      if(lastVal <= priceArr[minIdx]) {
         return True;
      }
   }
   
   return false;
}