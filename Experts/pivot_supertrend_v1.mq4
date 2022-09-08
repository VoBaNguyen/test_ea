//+------------------------------------------------------------------+
//|                                          pivot_supertrend_v1.mq4 |
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
input int TrendCCI_Period = 14;
input bool Automatic_Timeframe_setting = true;
input int M1_CCI_Period = 14;
input int M5_CCI_Period = 14;
input int M15_CCI_Period = 14;
input int M30_CCI_Period = 14;
input int H1_CCI_Period = 14;
input int H4_CCI_Period = 14;
input int D1_CCI_Period = 14;
input int W1_CCI_Period = 14; 
input int MN_CCI_Period = 14;

input double riskLevel = 0.05;
input int TPPips = 200;
input int SLPips = 100;
input int maxPos = 1; //Max Position
input int delay = 1;
input int slippage = 10;
input long magicNumber = 1111; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_H1;

double lotSize = 0.1;
int ticket = 0;
double   trendUp[4], 
         trendDown[4],
         MA50[6];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Alert("Init pivot super trend EA v1!");
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Alert("Remove pivot super trend EA v1!");
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Collect data
   for(int i=0; i<ArraySize(trendUp); i++) {
      trendUp[i] = iCustom(
      	Symbol(),
      	TIME_FRAME,
      	"super-trend-2",
			M1_CCI_Period, M5_CCI_Period, M15_CCI_Period, M30_CCI_Period,
			H1_CCI_Period, H4_CCI_Period, D1_CCI_Period, W1_CCI_Period, MN_CCI_Period,
      	0,
      	i+1
      );
      trendDown[i] = iCustom(
      	Symbol(),
      	TIME_FRAME,
      	"super-trend-2",
			M1_CCI_Period, M5_CCI_Period, M15_CCI_Period, M30_CCI_Period,
			H1_CCI_Period, H4_CCI_Period, D1_CCI_Period, W1_CCI_Period, MN_CCI_Period,
      	1,
      	i+1
      );
   }
   
   for(int i=0; i<ArraySize(MA50); i++) {
      MA50[i] = iMA(Symbol(), TIME_FRAME, 50, 0, MODE_SMA, PRICE_CLOSE, i+1);
   }
   
   
   bool isUptrend = isPivotUp(trendUp, trendDown);
   bool isDowntrend = isPivotDown(trendUp, trendDown);
   bool isSideway = isPivotSideway(trendUp, trendDown);
   bool isMAUpward = idcUpward(MA50);
   bool isMADownward = idcDownward(MA50);
   bool isBuy = false;
   bool isSell = false;
   int totalPos = countPosition(magicNumber);   

   if(totalPos == maxPos) {
      if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES) == true) {
         if(OrderType() == 0 && (isDowntrend || isSideway)) {
            closeOrder(ticket, OrderLots(), Bid, slippage);
         } else if(OrderType() == 1 && (isUptrend || isSideway)) {
            closeOrder(ticket, OrderLots(), Ask, slippage);
         }
      }
   }
   
   
   // NEW SIGNAL
   if(totalPos < maxPos) {
      if(isDowntrend) {
         isSell = true;
      } else if(isUptrend) {
         isBuy = true;
      }
   }

   
   if(totalPos < maxPos && (isBuy || isSell)) {
      //+------------------------------------------------------------------+
      //| CHECK DUPLICATE POSITIONS                                        |
      //+------------------------------------------------------------------+   
      //if(isBuy || isSell) {
      //   long delaySec = delay * PeriodSeconds(TIME_FRAME);
      //   bool recentClose = isRecentClose(delaySec);   
      //   if(recentClose) {
      //      isBuy = false;
      //      isSell = false;
      //   }
      //}
      
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

  }
//+------------------------------------------------------------------+

bool isPivotSideway(double& trendUp[], double& trendDown[]) {
   for(int i=0; i<ArraySize(trendUp); i++) {
      if(trendUp[i] != trendDown[i]) {
         return false;
      }
   }
   return true;
}


bool isPivotUp(double& trendUp[], double& trendDown[]) {
   int threshold = 1000000;
   if(trendUp[0] < threshold && trendDown[0] > threshold) {
      return true;
   }
   return false;
}


bool isPivotDown(double& trendUp[], double& trendDown[]) {
   int threshold = 1000000;
   if(trendUp[0] > threshold && trendDown[0] < threshold) {
      return true;
   }
   return false;
}
