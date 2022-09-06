//+------------------------------------------------------------------+
//|                                                 test_keltner.mq4 |
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

   double trendUp[5], trendDown[5];

	int TrendCCI_Period = 14;
	bool Automatic_Timeframe_setting;
	int M1_CCI_Period = 14;
	int M5_CCI_Period = 14;
	int M15_CCI_Period = 14;
	int M30_CCI_Period = 14;
	int H1_CCI_Period = 14;
	int H4_CCI_Period = 14;
	int D1_CCI_Period = 14;
	int W1_CCI_Period = 14; 
	int MN_CCI_Period = 14;

   // Collect data
   for(int i=0; i<ArraySize(trendUp); i++) {
      trendUp[i] = iCustom(
      	Symbol(),
      	PERIOD_H1,
      	"super-trend-2",
      	M1_CCI_Period,
      	M5_CCI_Period,
      	M15_CCI_Period,
      	M30_CCI_Period,
      	H1_CCI_Period,
      	H4_CCI_Period,
      	D1_CCI_Period,
      	W1_CCI_Period,
      	MN_CCI_Period,
      	0,
      	i+1
      );
      trendDown[i] = iCustom(
      	Symbol(),
      	PERIOD_H1,
      	"super-trend-2",
      	M1_CCI_Period,
      	M5_CCI_Period,
      	M15_CCI_Period,
      	M30_CCI_Period,
      	H1_CCI_Period,
      	H4_CCI_Period,
      	D1_CCI_Period,
      	W1_CCI_Period,
      	MN_CCI_Period,
      	1,
      	i+1
      );
      Alert(i, ". Up: ", trendUp[i], " - Down: ", trendDown[i]);
   }
  }
//+------------------------------------------------------------------+
