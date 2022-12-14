//+------------------------------------------------------------------+
//|                                                   Supertrend.mq4 |
//|                   Copyright © 2005, Jason Robinson (jnrtrading). |
//|                                      http://www.jnrtrading.co.uk |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2005, Jason Robinson (jnrtrading)."
#property link      "http://www.jnrtrading.co.uk"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Red

double CloseOffset[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicators

   SetIndexStyle(0, DRAW_LINE, 0, 1);
   SetIndexBuffer(0, CloseOffset);
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custor indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
//---- 
   
//----
   return(0);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int limit, i;

   int countedBars = IndicatorCounted();
//---- check for possible errors
   if(countedBars < 0) return(-1);
//---- last counted bar will be recounted
   if(countedBars > 0) countedBars--;

   limit=Bars-countedBars;
   

   //cciPeriod = TrendCCI_Period;
   SetIndexLabel(0, ("CloseOffset "));
   for(i = limit; i >= 0; i--) {
      CloseOffset[i] = Close[i] + 10;
   }
         
//---- 

//----
   return(0);
  }
//+------------------------------------------------------------------+