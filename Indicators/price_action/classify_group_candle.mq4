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
#property indicator_color1 clrYellow
#property indicator_color2 clrYellow


#include <models/candle.mqh>;
#include <common/utils.mqh>;

//extern ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
//extern string color1 = "Aqua";         // Hammer

ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
string color1 = "Aqua";         // Hammer


double InsidebarSell[];
double InsidebarBuy[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   // Set buffer indicators
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(0, 234);
   SetIndexBuffer(0, InsidebarSell);
   SetIndexDrawBegin(0, 0);

   SetIndexStyle(1, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(1, 233);
   SetIndexBuffer(1, InsidebarBuy);
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

   for(i=limit-1; i>1; i--) {
      string info[2];
      classifyGroupCandle(i, info, TimeFrame);
      double dist = iATR(Symbol(), TimeFrame, 14, i) / 4;
      if(info[0] == "insidebar" && info[1] == "sell") {
         bool isExtrama = isLocalExtremum(i, "high", TimeFrame);
         if(isExtrama) InsidebarSell[i] = High[i] + dist;
      } 
      else if(info[0] == "insidebar" && info[1] == "buy") {
         bool isExtrama = isLocalExtremum(i, "low", TimeFrame);
         if(isExtrama) InsidebarBuy[i] = Low[i] - dist;
      }
   }
   return(0);
}

