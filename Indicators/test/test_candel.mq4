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
#property indicator_buffers 5
#property indicator_color1 clrAqua
#property indicator_color2 clrPurple
#property indicator_color3 clrYellow
#property indicator_color4 clrWhite
#property indicator_color5 clrWhite


#include <models/candle.mqh>;

//extern ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
//extern string color1 = "Aqua";         // Hammer
//extern string color2 = "Red";          // Doji
//extern string color3 = "Yellow";       // Marubozu
//extern string color4 = "Inside Bars";  // Insidebar Up
//extern string color5 = "Inside Bars";  // Insidebar Down

ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
string color1 = "Aqua";         // Hammer
string color2 = "Red";          // Doji
string color3 = "Yellow";       // Marubozu
string color4 = "Inside Bars";  // Insidebar Up
string color5 = "Inside Bars";  // Insidebar Down

double CandleHammer[], CandleDoji[], CandleMarubozu[], InsideBarsUp[], InsideBarsDown[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   // Set buffer indicators
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(0, 234);
   SetIndexBuffer(0, CandleHammer);
   SetIndexDrawBegin(0, 0);

   SetIndexStyle(1, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(1, 234);
   SetIndexBuffer(1, CandleDoji);
   SetIndexDrawBegin(1, 0);

   SetIndexStyle(2, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(2, 234);
   SetIndexBuffer(2, CandleMarubozu);
   SetIndexDrawBegin(2, 0);

   SetIndexStyle(3, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(3, 233);
   SetIndexBuffer(3, InsideBarsUp);
   SetIndexDrawBegin(3, 0);

   SetIndexStyle(4, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(4, 234);
   SetIndexBuffer(4, InsideBarsDown);
   SetIndexDrawBegin(4, 0);

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
   
      // Check insidebar
      string grpInfo[2];
      grpInfo[0] = "undefined";
      grpInfo[1] = "undefined";
      classifyGrpCandle(i, grpInfo, TimeFrame);
      if(grpInfo[1] == "insidebar") {
         if(grpInfo[0] == "sell") {
            InsideBarsDown[i] = High[i] + dist;
         }
         else if(grpInfo[0] == "buy") {
            InsideBarsUp[i] = Low[i] - dist;
         } 

      }
   }


   return(0);
}

