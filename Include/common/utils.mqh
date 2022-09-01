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


/*********************************
*         COMMON METHODS         *
*********************************/

double getPip() {
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


/*********************************
*          ORDER METHODS         *
*********************************/

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


bool isDuplicateOrder(long delaySeconds) {
   bool isDuplicate = false;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         datetime openTime = OrderOpenTime();
         datetime limitTime = openTime + delaySeconds;
         if(TimeCurrent() < limitTime) {
            isDuplicate = true;
         }
      }
   }
   return isDuplicate;
}

bool isRecentClose(long delaySeconds) {
   bool isRecent = false;
   for(int i=0; i<OrdersHistoryTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         datetime closeTime = OrderCloseTime();
         datetime limitTime = closeTime + delaySeconds;
         if(TimeCurrent() < limitTime) {
            isRecent = true;
         }
      }
   }
   return isRecent;
}



/*********************************
*         INDICATOR TREND        *
*********************************/

bool crossDownward(double a0, double a1, double b0, double b1) {
   if(a0 < b0 && a1 >= b1) {
      return true;
   }
   return false;
}


bool crossUpward(double a0, double a1, double b0, double b1) {
   if(a0 > b0 && a1 <= b1) {
      return true;
   }
   return false;
}


bool idcUpward(double& buffer[], int size, double threshold=0) {
   bool upward = isArrIncrease(buffer);
   if(upward) {
      double delta = MathAbs(buffer[0] - buffer[size-1]);
      if(delta < threshold) {
         upward = false;
      }
   }

   return upward;
}


bool idcDownward(double& buffer[], int size, double threshold=0) {
   bool downward = isArrDecrease(buffer);
   if(downward) {
      double delta = MathAbs(buffer[0] - buffer[size-1]);
      if(delta < threshold) {
         downward = false;
      }
   }

   return downward;
}



/*********************************
*         ARRAY METHODS          *
*********************************/
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
      if(curValue >= nextValue) {
         return false;
      } else {
         curValue = nextValue;
      }
   }
   return true;
}