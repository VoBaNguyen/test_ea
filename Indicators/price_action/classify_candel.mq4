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
#property indicator_buffers 4
#property indicator_color1 clrAqua
#property indicator_color2 clrAqua
#property indicator_color3 clrPurple
#property indicator_color4 clrPurple

#include <models/candle.mqh>;

//extern ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
//extern string color1 = "Aqua";         // Hammer

ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
string color1 = "Aqua";         // Hammer


double CandleLongTailSell[], 
       CandleLongTailBuy[],
       CandlePinbarBuy[], 
       CandlePinbarSell[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   // Set buffer indicators
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(0, 234);
   SetIndexBuffer(0, CandleLongTailSell);
   SetIndexDrawBegin(0, 0);

   SetIndexStyle(1, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(1, 233);
   SetIndexBuffer(1, CandleLongTailBuy);
   SetIndexDrawBegin(1, 0);

   SetIndexStyle(2, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(2, 233);
   SetIndexBuffer(2, CandlePinbarBuy);
   SetIndexDrawBegin(2, 0);

   SetIndexStyle(3, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(3, 234);
   SetIndexBuffer(3, CandlePinbarSell);
   SetIndexDrawBegin(3, 0);

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
      classifySingleCandle(i, info, TimeFrame);
      double dist = iATR(Symbol(), TimeFrame, 14, i) / 4;
      
      // Pin Bar
      if(info[0] == "pinbarBuy") {
         CandlePinbarBuy[i] = Low[i] - dist;
         continue;
      }
      if(info[0] == "pinbarSell") {
         CandlePinbarSell[i] = High[i] + dist;
         continue;
      }
      
      // Long Tail
      if(info[0] == "longTailSell") {
         CandleLongTailSell[i] = High[i] + dist;
         continue;
      }
      if(info[0] == "longTailBuy") {
         CandleLongTailBuy[i] = Low[i] - dist;
         continue;
      }

   }
   return(0);
}

