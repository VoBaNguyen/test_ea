//+------------------------------------------------------------------+
//|                                                       candle.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+


void classifyCandle(int idx, string &info[], ENUM_TIMEFRAMES TimeFrame) { 
   // GET CANDLE PRICE
   double open  = iOpen(Symbol(), TimeFrame, idx);
   double close = iClose(Symbol(), TimeFrame, idx);
   double high  = iHigh(Symbol(), TimeFrame, idx);
   double low   = iLow(Symbol(), TimeFrame, idx);
   double candleBody = MathAbs(open - close);
   double candleSize = high - low;

   // CONFIG
   double tailShort = candleBody/6;
   double bodyShort = candleSize/6;
   double bodyDoji = candleSize/10;
   double seemZero = candleBody/20;
   double seemLong = candleBody*2;
   double seemEqual = candleBody/20;
   double marubozuMaxTail = candleBody/5;

   string candleType;
   if(open <= close) {
      candleType = "Bull";
   } else {
      candleType = "Bear";
   }
   
   // Calculate candle tails
   double upperTail = (high - MathMax(open, close));
   double lowerTail = (MathMin(open, close)-low);

   //+------------------------------------------------------------------+
   //| CLASSIFY CANDLES                                                 |
   //+------------------------------------------------------------------+

   // Marubozu:
   // Dac diem: Chi co than, khong co dau/duoi
   // Y nghia: Dau hieu tiep tuc tang/giam manh
   double atr = iATR(Symbol(), TimeFrame, 14, idx);
   if(candleBody > 2*atr
      && isEqual(MathMax(open, close), high, marubozuMaxTail) 
      && isEqual(MathMin(open, close), low, marubozuMaxTail)
   ) {
      info[0] = "marubozu";
      info[1] = candleType;
      return;
   }
   
   // Spinning Tops: 
   // Dac diem: Than nho 
   // Y nghia: Tam ly nha dau tu dang do du trong viec mua/ban
   
   
   // Doji
   // Dac diem: Gia open/close xap xi ngang nhau
   // Y nghia: The hien su do du trong viec xac dinh vi the cua nha dau tu
   if(candleBody < bodyDoji && MathMin(upperTail, lowerTail) > 3*bodyDoji) {
      info[0] = "doji";
      info[1] = candleType;
      return;
   }
   
   // Hammer
   // Dac diem: Nen co rau dai hon phan than nen thuc. Rau nen rat nho hoac khong co
   // Y nghia: Bao hieu xu huong yeu di, dao chieu cuc ki manh
   else if(MathMin(upperTail, lowerTail) < tailShort && candleBody < bodyShort) {
      info[0] = "hammer";
      info[1] = candleType;
      return;
   }
   
   // Dragonfly
   // Dac diem: Khong co rau nen phia tren/rau nen phia duoi dai
   // Y nghia: Thuong gap o dinh/day cua thi truong
   if(MathMin(lowerTail, upperTail) < seemZero && MathMax(lowerTail, upperTail) > seemLong) {
      info[0] = "dragon_fly";
      info[1] = candleType;
      return;
   }
   
   info[0] = "undefined";
   info[1] = candleType;
   return;
}

bool isEqual(double A, double B, double delta) {
   if(MathAbs(A-B) < delta) {
      return true;
   }
   
   return false;
}