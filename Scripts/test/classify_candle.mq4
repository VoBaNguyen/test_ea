//+------------------------------------------------------------------+
//|                                              classify_candle.mq4 |
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
   int idx = 19;
   string info[2];
   classifyCandle(idx, info);
   Alert(idx, " .Name: ", info[0], " - Type: ", info[1]);

//---   
  }
//+------------------------------------------------------------------+



void classifyCandle(int idx, string &info[]) {
   // CONFIG
   double tailShort = 0.05;
   double bodyShort = 0.1;
   double bodyDoji = 0.01;
   double seemZero = 0.01;
   double seemLong = 0.9;
   double seemEqual = 0.02;
   
   // GET CANDLE PRICE
   double open  = iOpen(Symbol(), PERIOD_M15, idx);
   double close = iClose(Symbol(), PERIOD_M15, idx);
   double high  = iHigh(Symbol(), PERIOD_M15, idx);
   double low   = iLow(Symbol(), PERIOD_M15, idx);
   double candleSize = high - low;
   double candleBody = MathAbs(open - close);
      
   string candleType;
   if(open <= close) {
      candleType = "Bull";
   } else {
      candleType = "Bear";
   }
   
   // Calculate candle tails
   double upperTail = (high - MathMax(open, close))/candleSize;
   double lowerTail = (MathMin(open, close)-low)/candleSize;

   //+------------------------------------------------------------------+
   //| CLASSIFY CANDLES                                                 |
   //+------------------------------------------------------------------+

   // Marubozu:
   // Dac diem: Chi co than, khong co dau/duoi
   // Y nghia: Dau hieu tiep tuc tang/giam manh
   if(isEqual(MathMax(open, close), high, seemEqual) && isEqual(MathMin(open, close), low, seemEqual)) {
      info[0] = "marubozu";
      info[1] = candleType;
   }
   
   // Spinning Tops: 
   // Dac diem: Than nho 
   // Y nghia: Tam ly nha dau tu dang do du trong viec mua/ban
   
   
   // Hammer
   // Dac diem: Nen co rau dai hon phan than nen thuc. Rau nen rat nho hoac khong co
   // Y nghia: Bao hieu xu huong yeu di, dao chieu cuc ki manh
   else if(MathMin(upperTail, lowerTail) < tailShort && candleBody < bodyShort) {
      info[0] = "hammer";
      info[1] = candleType;
   }


   // Doji
   // Dac diem: Gia open/close xap xi ngang nhau
   // Y nghia: The hien su do du trong viec xac dinh vi the cua nha dau tu
   else if(MathAbs(open - close) < bodyDoji) {
      info[0] = "doji";
      info[1] = candleType;
   }
   
   // Dragonfly
   // Dac diem: Khong co rau nen phia tren/rau nen phia duoi dai
   // Y nghia: Thuong gap o dinh/day cua thi truong
   else if(MathMin(lowerTail, upperTail) < seemZero && MathMax(lowerTail, upperTail) > seemLong) {
      info[0] = "dragon_fly";
      info[1] = candleType;
   }
   
   else {
      info[0] = "undefined";
      info[1] = candleType;
   }
}

bool isEqual(double A, double B, double delta) {
   if(MathAbs(A-B) < delta) {
      return true;
   }
   
   return false;
}