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
#property indicator_buffers 3
#property indicator_color1 clrAqua
#property indicator_color2 clrRed
#property indicator_color3 clrYellow


#include <models/candle.mqh>;

extern ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
double CandleHammer[], CandleDoji[], CandleMarubozu[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   // Set buffer indicators
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(0, 234);
   SetIndexBuffer(0, CandleHammer);

   SetIndexStyle(1, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(1, 234);
   SetIndexBuffer(1, CandleDoji);

   SetIndexStyle(2, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(2, 234);
   SetIndexBuffer(2, CandleMarubozu);


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

   for(i=limit-1; i>1; i--) {
      string info[2];
      classifyCandle(i, info, TimeFrame);

      double dist = iATR(Symbol(), TimeFrame, 14, i) / 2;
      if(info[0] == "hammer") {
         CandleHammer[i] = High[i] + dist;
      } else if (info[0] == "doji") {
         CandleDoji[i] = High[i] + dist;
      } else if (info[0] == "marubozu") {
         CandleMarubozu[i] = High[i] + dist;
      }
   }


   return(0);
}

