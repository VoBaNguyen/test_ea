//+------------------------------------------------------------------+
//|                                                     test_obv.mq4 |
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
   double obvDiff = getOBVMaxMinDifference(0, 10);
   Alert(obvDiff);
   
   
  }
//+------------------------------------------------------------------+

double getOBVMaxMinDifference(int shift, int numCandles)
{
    double obvMax = 0; // Maximum OBV value
    double obvMin = 0; // Minimum OBV value

    // Loop through the candles from shift to (shift + numCandles)
    for (int i = shift; i < shift + numCandles; i++)
    {
        double obv = iOBV(Symbol(), PERIOD_CURRENT, 0, i); // Get OBV value of the i-th candle

        // Update obvMax and obvMin
        if (i == shift)
        {
            obvMax = obv;
            obvMin = obv;
        }
        else
        {
            if (obv > obvMax)
                obvMax = obv;
            if (obv < obvMin)
                obvMin = obv;
        }
    }

    // Return the difference between obvMax and obvMin
    PrintFormat("Obv max: %.2f - Obv min: %.2f", obvMax, obvMin);
    return obvMax - obvMin;
}
