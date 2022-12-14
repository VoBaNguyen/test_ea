//+------------------------------------------------------------------+
//|                                           MA-Crossover_Alert.mq4 |
//|         Copyright © 2005, Jason Robinson (jnrtrading)            |
//|                   http://www.jnrtading.co.uk                     |
//| Modified by Robert Hill to add LSMA and alert or send email      |
//| Added Global LastAlert to try to have alert only on new cross    |
//| but does not seem to work. So indicator does alert every bar     |
//+------------------------------------------------------------------+

/*
  +------------------------------------------------------------------+
  | Allows you to enter two ma periods and it will then show you at  |
  | Which point they crossed over. It is more usful on the shorter   |
  | periods that get obscured by the bars / candlesticks and when    |
  | the zoom level is out. Also allows you then to remove the  mas   |
  | from the chart. (emas are initially set at 5 and 20)              |
  +------------------------------------------------------------------+
*/   
#property copyright "Copyright © 2005, Jason Robinson (jnrtrading)"
#property link      "http://www.jnrtrading.co.uk"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 clrGreenYellow
#property indicator_color2 clrRed

#include <models/candle.mqh>;

//extern ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
//extern string color1 = "Aqua";         // Hammer

ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
string color1 = "Aqua";         // Hammer


double BullBases[], 
       BearBases[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   // Set buffer indicators
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(0, 233);
   SetIndexBuffer(0, BullBases);
   SetIndexDrawBegin(0, 0);

   SetIndexStyle(1, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(1, 234);
   SetIndexBuffer(1, BearBases);
   SetIndexDrawBegin(1, 0);

   return(0);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
   return(0);
  }


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start() {
   int limit, i;

   int countedBars=IndicatorCounted();
   if(countedBars<0) return(-1);
   if(countedBars>0) countedBars--;

   limit=Bars-countedBars;

   for(i=limit-50; i>1; i--) {
      string info[2];
      classifySingleCandle(i, info, TimeFrame);
      double dist = iATR(Symbol(), TimeFrame, 14, i) / 4;
      
      bool isBullBase = isBullBearBaseOneSide(i, "bull", TimeFrame);
      if(isBullBase) {
         BullBases[i] = Low[i] - dist;
         continue;
      }

      bool isBearBase = isBullBearBaseOneSide(i, "bear", TimeFrame);
      if(isBearBase) {
         BearBases[i] = High[i] + dist;
         continue;
      }
   }
   
   return(0);
}



bool isBullBearBaseOneSide(int candleIdx,string type, ENUM_TIMEFRAMES TimeFrame, double delta=0) {
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

////////////////////////////////////////////////////////////
////////////////////////// BACKUP //////////////////////////
////////////////////////////////////////////////////////////
bool isBullBearBaseBothSide(int candleIdx,string type, ENUM_TIMEFRAMES TimeFrame, double delta=0) {
   double priceArr[16];
   int range = ArraySize(priceArr);
   int endIdx = MathMax(candleIdx - range/2, 1);
   if(type == "bull") {
      for(int idx=0; idx<range; idx++) {
         priceArr[idx] = High[endIdx+idx];
      }
      int maxIdx = ArrayMaximum(priceArr, WHOLE_ARRAY, 0);
      double lastVal = High[candleIdx] + delta;
      if(lastVal >= priceArr[maxIdx]) {
         return True;
      }
   }
   
   else if (type == "bear") {
      for(int idx=0; idx<range; idx++) {
         priceArr[idx] = Low[endIdx+idx];
      }
      int minIdx = ArrayMinimum(priceArr, WHOLE_ARRAY, 0);
      double lastVal = Low[candleIdx] - delta;
      if(lastVal <= priceArr[minIdx]) {
         return True;
      }
   }
   
   return false;
}
