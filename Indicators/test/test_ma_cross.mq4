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
#property indicator_color2 clrRed
#property indicator_color3 clrAqua
#property indicator_color4 clrRed

extern ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
extern int FastEMA_Period = 25;
extern int SlowEMA_Period = 200;

double EMAFast[], EMASlow[], CrossUp[], CrossDown[];
double prevEMAFast = 0;
double prevEMASlow = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   // Set buffer indicators
   // Draw 2 EMA lines
   SetIndexStyle(0, DRAW_LINE, EMPTY, 1, clrAqua);
   SetIndexBuffer(0, EMAFast);
   
   SetIndexStyle(1, DRAW_LINE, EMPTY, 1, clrRed);
   SetIndexBuffer(1, EMASlow);

   // Draw arrow   
   SetIndexStyle(2, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(2, 233);
   SetIndexBuffer(2, CrossUp);
   
   SetIndexStyle(3, DRAW_ARROW, EMPTY, 1);
   SetIndexArrow(3, 234);
   SetIndexBuffer(3, CrossDown);

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

   for(i = limit-1; i >= 0; i--) {
      EMAFast[i] = iMA(Symbol(), TimeFrame, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE, i);
      EMASlow[i] = iMA(Symbol(), TimeFrame, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE, i);
      prevEMAFast = iMA(Symbol(), TimeFrame, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE, i+1);
      prevEMASlow = iMA(Symbol(), TimeFrame, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE, i+1);
      double dist = iATR(Symbol(), TimeFrame, 14, i) / 2;
      if((prevEMAFast <= prevEMASlow) && (EMAFast[i] > EMASlow[i])) {
         CrossUp[i] = Low[i] - dist;
      } else if ((prevEMAFast >= prevEMASlow) && (EMAFast[i] < EMASlow[i])) {
         CrossDown[i] = High[i] + dist;
      }

   }


   return(0);
}

