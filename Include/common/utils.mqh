//+------------------------------------------------------------------+
//|                                                        utils.mqh |
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


double getPip() {
   Alert("Digits: ", _Digits);
   return MathPow(10, -_Digits+2);
}


double calTP(bool isLong, double entry, int pips) {
   double TP;
   if(isLong) {
      TP = entry + pips * getPip();
   } else {
      TP = entry - pips * getPip();
   }
   return TP;
}


double calSL(bool isLong, double entry, int pips) {
   double SL;
   if(isLong) {
      SL = entry - pips * getPip();
   } else {
      SL = entry + pips * getPip();
   }
   return SL;
}


int countPosition(long magicNumber) {
   int count = 0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == false) {
         Alert("Fail to select position with ticket: ", OrderTicket());
         return 9999;
      }
      if(magicNumber == OrderMagicNumber()) {
         count += 1;
      }
   }
   return count;
}


bool crossUpward(int idcHandler1, int idx1, double idcHandler2, int idx2, int count) {
   double buffer1[], buffer2[];
   CopyBuffer(idcHandler1, idx1, 0, count, buffer1);
   CopyBuffer(idcHandler2, idx2, 0, count, buffer2);
   int idxBefore = count-3;
   int idxAfter = count-2;
   if(buffer1[idxBefore] < buffer2[idxBefore] && buffer1[idxAfter] >= buffer2[idxAfter]) {
      return true;
   }
   return false;
}


bool crossDownward(int idcHandler1, int idx1, double idcHandler2, int idx2, int count) {
   double buffer1[], buffer2[];
   CopyBuffer(idcHandler1, idx1, 0, count, buffer1);
   CopyBuffer(idcHandler2, idx2, 0, count, buffer2);
   int idxBefore = count-3;
   int idxAfter = count-2;
   if(buffer1[idxBefore] > buffer2[idxBefore] && buffer1[idxAfter] <= buffer2[idxAfter]) {
      return true;
   }
   return false;
}


bool idcUpward(int idcHandler, int idx, int count, double threshold=0) {
   double buffer[];
   CopyBuffer(idcHandler, idx, 0, count, buffer);
   bool upward = true;
   double curValue = buffer[0];
   for(int i=1; i<count-1; i++) {
      double nextValue = buffer[i];
      if(curValue >= nextValue) {
         upward = false;
      } else {
         curValue = nextValue;
      }
   }
   
   if(upward) {
      double delta = MathAbs(buffer[0] - buffer[count-1]);
      if(delta < threshold) {
         upward = false;
      }
   }
   
   return upward;
}


bool idcDownward(int idcHandler, int idx, int count, double threshold=0) {
   double buffer[];
   CopyBuffer(idcHandler, idx, 0, count, buffer);
   bool downward = true;
   double curValue = buffer[0];
   for(int i=1; i<count-1; i++) {
      double nextValue = buffer[i];
      if(curValue <= nextValue) {
         downward = false;
      } else {
         curValue = nextValue;
      }
   }

   if(downward) {
      double delta = MathAbs(buffer[0] - buffer[count-1]);
      if(delta < threshold) {
         downward = false;
      }
   }

   return downward;
}


bool isDuplicateOrder(long delay) {
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         datetime openTime = OrderOpenTime();
         datetime boundTime = TimeCurrent() + delay;
         if(TimeCurrent() > boundTime) {
            return true;
         }
      }
   }
   return false;
}