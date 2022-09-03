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

//+------------------------------------------------------------------+
//| Include system modules                                           |
//+------------------------------------------------------------------+
#include <stderror.mqh>
#include <stdlib.mqh>


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

bool selectOrder(int id, int idType, int mode) {
   bool stt = OrderSelect(id, idType, mode);
   if(!stt) {
      Alert("Failed to select order: ", id);
   }
   return stt;
}

int sendOrder(string symbol, ENUM_ORDER_TYPE ordType, 
               double lot, double entry, int slippage, 
               double SL, double TP, string comment, int EA) {
   Alert("Send order. Type: ", ordType, 
         " - Lot: ", lot, " - Entry: ", entry,
         " - SL: ", SL, " - TP: ", TP);
   int orderID = OrderSend(symbol,ordType,lot,entry,slippage,SL,TP,comment,EA);
   if(orderID < 0) {
      Alert("Send order ERROR: " + getErr());
   }
   return orderID;
}


double orderProfit(int ticket) {
   double delta, pips, entry;
   if(OrderSelect(ticket, SELECT_BY_TICKET) == true) {
      
      entry = OrderOpenPrice();
      if(OrderType() == 0) {
         delta = Ask - entry;
      } else {
         delta = entry - Bid;
      }
      pips = NormalizeDouble(delta/getPip(), 1);
      return pips;
   } else {
      Alert("Failed to select order with ticket: ", ticket);
      return 0;
   }
}


void closeOrder(int ticket, double lotSize, double price, int slippage) {
   Alert ("Close order: ",ticket,". Awaiting response..");
   bool stt = OrderClose(ticket, lotSize, price, slippage, 0);
   if (stt == false) {
      Alert ("Failed to close order: ", getErr());
   }
}


void modifyOrder(int ticket, double open, double SL, double TP) {
   Alert("Modification order: ",ticket,". Awaiting response...");
   bool stt = OrderModify(ticket,open,SL,TP,0, Black);
   if (stt == false) {
      Alert ("Failed to modify order: ", getErr());
   }
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
   for(int i=0; i<OrdersHistoryTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == true) {
         datetime limitTime = OrderCloseTime() + delaySeconds;
         if(TimeCurrent() < limitTime) {
            return true;
         }
      }
   }
   return false;
}


double calcLot(double balance, double riskLevel, int pipRange) {
   // 1 lot -> 1 pip = 10$
   // pips * 10 * lot = maxLoss
   double maxLoss = riskLevel*balance;
   double lot = NormalizeDouble(maxLoss/(pipRange*10), 2);
   printf("Balance: %.2f - Risk: %.2f - Max loss: %.2f - Lot: %.2f", balance, riskLevel, maxLoss, lot);
   return lot;
}


string getErr() {
   string errMsg = ErrorDescription(GetLastError());
   return errMsg;
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


bool isParallel(double& line1[], double& line2[], double& line3[], int size) {
   for(int i=1; i<size-1; i++) {
      if(!(line1[i] > line2[i] && line2[i] > line3[i])) {
         return false;
      }
   }
   return true;
}


bool isDivergence(double& line1[], double& line2[], int size) {
   int midIdx = MathRound(size/2);
   double firstDiff = MathAbs(line2[size-1] - line1[size-1]);
   double midDiff   = MathAbs(line2[midIdx] - line1[midIdx]);
   double lastDiff  = MathAbs(line2[0] - line1[0]);
   
   printf("firstDiff: %.2f, midDiff: %.2f, lastDiff: %.2f", firstDiff, midDiff, lastDiff);
   if(firstDiff < midDiff && midDiff < lastDiff) {
      return true;
   }
   return false;
}


bool isConvergence(double& line1[], double& line2[], int size) {
   int midIdx = MathRound(size/2);
   double firstDiff = MathAbs(line2[size-1] - line1[size-1]);
   double midDiff   = MathAbs(line2[midIdx] - line1[midIdx]);
   double lastDiff  = MathAbs(line2[0] - line1[0]);
   
   printf("firstDiff: %.2f, midDiff: %.2f, lastDiff: %.2f", firstDiff, midDiff, lastDiff);
   if(firstDiff > midDiff && midDiff > lastDiff) {
      return true;
   }
   return false;
}


bool isSideway(double& line1[], double& line2[], int size, double threshold) {
   double sum = 0;
   for(int i=0; i<size-1; i++) {
      double delta = MathAbs(line2[i] - line1[i]);
      sum += delta;
   }
   double avg = sum/size;
   if(avg > threshold) {
      return false;
   }
   
   return true;
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