//+------------------------------------------------------------------+
//|                                               test_indicator.mq4 |
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
   // Collect data
   int count = 5;
   double bufferMA10[5];
   for(int i=0; i<count; i++) {
      bufferMA10[i] = NormalizeDouble(iMA(NULL,0,10,0,MODE_SMA,PRICE_CLOSE,i), _Digits);
   }
   Alert(bufferMA10[0]," - ", bufferMA10[1]," - ", bufferMA10[2]);
   Alert(idcDownward(bufferMA10, 5));
  }
//+------------------------------------------------------------------+




bool idcDownward(double& buffer[], int size, double threshold=0) {
   bool downward = isDecrease(buffer);
   Alert("downward: ", downward);
   if(downward) {
      double delta = MathAbs(buffer[0] - buffer[size-1]);
      if(delta < threshold) {
         downward = false;
      }
   }

   return downward;
}



bool isArrIncrease(double& data[]) {
   int size = ArraySize(data);
   double curValue = data[0];
   for(int i=1; i<size-1; i++) {
      double nextValue = data[i];
      if(curValue <= nextValue) {
         return false;
      } else {
         curValue = nextValue;
      }
   }
   return true;
}

bool isArrDecrease(double& data[]) {
   int size = ArraySize(data);
   double curValue = data[0];
   for(int i=1; i<size-1; i++) {
      double nextValue = data[i];
      Alert("curValue: ", curValue, " - nextValue: ", nextValue);
      if(curValue >= nextValue) {
         return false;
      } else {
         curValue = nextValue;
      }
   }
   return true;
}