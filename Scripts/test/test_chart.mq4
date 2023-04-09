//+------------------------------------------------------------------+
//|                                                   test_chart.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
double price = Bid;
int timeframe = PERIOD_CURRENT;
int chartId = ChartID();

// Draw a line segment
Alert(ChartID());
Alert(Period());
Alert(Time[0]);
Alert(Time[0] - 100 * Period());
ObjectCreate(chartId, "MyLine", OBJ_TREND, timeframe, Time[0] - 100 * Period(), price, Time[0] , price);

  }
//+------------------------------------------------------------------+
