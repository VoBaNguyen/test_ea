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
   double bodyPinbar = candleSize/10;
   double seemZero = candleBody/20;
   double seemLong = candleBody*2;
   double seemEqual = candleBody/20;
   double marubozuMaxTail = candleBody/5;

   string candleType;
   if(open <= close) {
      candleType = "bull";
   } else {
      candleType = "bear";
   }
   
   // Calculate candle tails
   double upperTail = MathAbs(high - MathMax(open, close));
   double lowerTail = MathAbs(MathMin(open, close) - low);

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
   
   // Doji
   // Dac diem: Gia open/close xap xi ngang nhau
   // Y nghia: The hien su do du trong viec xac dinh vi the cua nha dau tu
   if(candleBody < bodyPinbar && MathMin(upperTail, lowerTail) > 3*bodyPinbar) {
      info[0] = "pinbar";
      info[1] = candleType;
      return;
   }
   
   // Hammer
   // Dac diem: Nen co rau dai hon phan than nen thuc. Rau nen rat nho hoac khong co
   // Y nghia: Bao hieu xu huong yeu di, dao chieu cuc ki manh
   if(MathMin(upperTail, lowerTail) < tailShort && candleBody < bodyShort) {
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

void classifyGrpCandle(int idx, string &grpInfo[], ENUM_TIMEFRAMES TimeFrame) {
   // GET CANDLE PRICE
   double open1  = iOpen(Symbol(), TimeFrame, idx+1);
   double close1 = iClose(Symbol(), TimeFrame, idx+1);
   double high1  = iHigh(Symbol(), TimeFrame, idx+1);
   double low1   = iLow(Symbol(), TimeFrame, idx+1);
   double body1  = MathAbs(open1 - close1);

   double open2  = iOpen(Symbol(), TimeFrame, idx);
   double close2 = iClose(Symbol(), TimeFrame, idx);
   double high2  = iHigh(Symbol(), TimeFrame, idx);
   double low2   = iLow(Symbol(), TimeFrame, idx);
   double body2  = MathAbs(open2 - close2);
   
   // Xet xu huong giam, dao chieu tang
   double atr = iATR(Symbol(), TimeFrame, 14, idx);
   // Left candle cover right candle
   if(low1 < low2 && high1 > high2 && body2 > body1/2 && body1 > atr*0.75) {
      // Do - Xanh
      if(open1 > close1 && open2 < close2 && open1 > MathMax(open2, close2)) {
         // Red cover Green - Nen nhan chim giam 
         grpInfo[0] = "buy"; // Mode buy
         grpInfo[1] = "insidebar"; // Insidebar
      }
      // Xanh - Do
      else if (open1 < close1 && open2 > close2 && open1 < MathMin(open2, close2)) {
         // Red cover Green - Nen nhan chim tang
         grpInfo[0] = "sell"; // Mode sell
         grpInfo[1] = "insidebar"; // Insidebar
      }
   }
   
   // Right candle cover left candle
   if(low1 > low2 && high1 < high2 && body1 > body2/2 && body2 > atr*0.75) {
      // Do - Xanh
      if(open1 > close1 && open2 < close2 && close2 > MathMax(open1, close1)) {
         // Red cover Green - Nen nhan chim giam 
         grpInfo[0] = "buy"; // Mode buy
         grpInfo[1] = "insidebar"; // Insidebar
      }
      // Xanh - Do
      else if (open1 < close1 && open2 > close2 && close2 < MathMin(open1, close1)) {
         // Red cover Green - Nen nhan chim tang
         grpInfo[0] = "sell"; // Mode sell
         grpInfo[1] = "insidebar"; // Insidebar
      }
   }
}


bool isEqual(double A, double B, double delta) {
   if(MathAbs(A-B) < delta) {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CLASSIFY CANDLES - VERSION 2.0                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

void classifySingleCandle(int idx, string &info[], ENUM_TIMEFRAMES TimeFrame) { 
   // GET CANDLE PRICE
   double open  = iOpen(Symbol(), TimeFrame, idx);
   double close = iClose(Symbol(), TimeFrame, idx);
   double high  = iHigh(Symbol(), TimeFrame, idx);
   double low   = iLow(Symbol(), TimeFrame, idx);
   double candleBody = MathAbs(open - close);
   double candleSize = high - low;

   // CONFIG
   double bodyShort = candleSize/6;
   double seemZero = candleBody/20;
   double seemLong = candleBody*2;
   double seemEqual = candleBody/20;
   double bodyPinbar = candleSize/6;

   string candleType;
   if(open <= close) {
      candleType = "bull";
   } else {
      candleType = "bear";
   }
   
   // Calculate candle tails
   double upperTail = MathAbs(high - MathMax(open, close));
   double lowerTail = MathAbs(MathMin(open, close) - low);

   //+------------------------------------------------------------------+
   //| CLASSIFY CANDLES                                                 |
   //+------------------------------------------------------------------+
   double atr = iATR(Symbol(), TimeFrame, 7, idx);
   // longTail
   // Dac diem: Rau tren/duoi dai
   // Y nghia: The hien su tranh chap, xu huong chinh dang yeu dan
   if(MathMax(upperTail, lowerTail) > candleBody 
      && (upperTail + lowerTail) > 2*candleBody
      && candleSize > atr/2) {


      // Pin Bar
      // Dac diem: Nen co rau dai hon phan than nen thuc. Rau nen tren or duoi rat nho hoac khong co
      // Y nghia: Bao hieu xu huong yeu di, dao chieu cuc ki manh
      if(MathMin(upperTail, lowerTail) < bodyPinbar && 
         MathMax(upperTail, lowerTail) > 2*candleBody &&
         candleBody < bodyPinbar) {
         if(upperTail > lowerTail) {
            info[0] = "pinbarSell";
         } else {
            info[0] = "pinbarBuy";
         }
         info[1] = candleType;
         return;
      }
      
      // Long Tail
      if(upperTail > 1.5*lowerTail) {
         info[0] = "longTailSell";
         info[1] = candleType;
         return;
      }
      
      if (upperTail < 1.5*lowerTail) {
         info[0] = "longTailBuy";
         info[1] = candleType;
         return;
      }

      return;
   }
   
   info[0] = "undefined";
   info[1] = candleType;
   return;
}


void classifyGroupCandle(int idx, string &grpInfo[], ENUM_TIMEFRAMES TimeFrame) {
   // GET CANDLE PRICE
   double open1  = iOpen(Symbol(), TimeFrame, idx+1);
   double close1 = iClose(Symbol(), TimeFrame, idx+1);
   double high1  = iHigh(Symbol(), TimeFrame, idx+1);
   double low1   = iLow(Symbol(), TimeFrame, idx+1);
   double body1  = MathAbs(open1 - close1);
   double size1  = high1 - low1;

   double open2  = iOpen(Symbol(), TimeFrame, idx);
   double close2 = iClose(Symbol(), TimeFrame, idx);
   double high2  = iHigh(Symbol(), TimeFrame, idx);
   double low2   = iLow(Symbol(), TimeFrame, idx);
   double body2  = MathAbs(open2 - close2);
   double size2  = high2 - low2;
   
   double atr = iATR(Symbol(), TimeFrame, 14, idx);
   double delta = 0.01;
   double minSize1 = size1/5;
   
   // Englufing dao chieu giam
   //      |
   //      |          |
   //     _|_ _|_    _|_ _|_
   //     |^| |v|    |^| |v|
   //     |^| |v|    |^| |v|
   //     |_| |v|    |_| |v|
   //      |  |v|     |  |v|
   //         |_|     |  |_|
   //          |      |   |
   //          |          |
   //      STRONG     WEAK
   
   if(body1*1.2 > body2) return;
   
   if(size1*1.2 > size2) return;
   
   if(body2 < atr) return;
   
   if(body1 > minSize1 &&  // Filter Pin Bar
      open1 < close1 &&   // Candle 1 is bull
      open2 > close2 &&   // Candle 2 is bear
      MathMax(open1, close1) < high2+delta && 
      MathMin(open1, close1) > close2-delta &&
      low1 > low2  // Candle 1 was covered by candle 2
   ) {
      grpInfo[0] = "insidebar"; // Mode buy
      grpInfo[1] = "sell"; // Insidebar
   }
   

   // Englufing dao chieu tang
   //          |                  
   //         _|_         |   |   
   //         |^|         |  _|_  
   //     _|_ |^|        _|_ |^|  
   //     |v| |^|        |v| |^|  
   //     |v| |^|        |v| |^|  
   //     |_| |_|        |_| |_|  
   //      |   |          |   |   
   //      |              |       
   //      |                     
   //      STRONG         WEAK
   if(body1 > minSize1 &&  // Filter Pin Bar
      open1 > close1 &&   // Candle 1 is bull
      open2 < close2 &&   // Candle 2 is bear
      MathMax(open1, close1) < high2 &&
      MathMin(open1, close1) > open2-delta &&
      high1 < high2  // Candle 1 was covered by candle 2
   ) {
      grpInfo[0] = "insidebar"; // Mode buy
      grpInfo[1] = "buy"; // Insidebar
   }

}