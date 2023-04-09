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

double getPip(string symbol="") {
   if(symbol == "") {
      symbol = _Symbol;
   }
   /*
   double bid    = MarketInfo(symbol, MODE_BID);
   double ask    = MarketInfo(symbol, MODE_ASK);
   double point  = MarketInfo(symbol, MODE_POINT);
   int    digits = (int)MarketInfo(symbol, MODE_DIGITS);
   int    spread = (int)MarketInfo(symbol, MODE_SPREAD);
   */

   return getPoints()*10;
}


double getPoints()
{
   // If there are 3 or fewer digits (JPY, for example), then return 0.01, which is the pip value.
   if (Digits <= 3){
      return(0.01);
   }
   // If there are 4 or more digits, then return 0.0001, which is the pip value.
   else if (Digits >= 4){
      return(0.00001);
   }
   // In all other cases, return 0.
   else return(0);
}


int calcPip(double price1, double price2) {
   double _delta = MathAbs(price1 - price2);
   int pips = MathRound(_delta/getPip());
   return pips;
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
               double lot, double entry, int _slippage, 
               double SL, double TP, string comment, int EA) {
   Alert("Send order. Symbol: ", symbol, ", Type: ", ordType, 
         " - Lot: ", lot, " - Entry: ", entry,
         " - SL: ", SL, " - TP: ", TP,
         " - Ask: ", Ask, " - Bid: ", Bid, " - Spread: ", MarketInfo( _Symbol, MODE_SPREAD ));
   int orderID = OrderSend(symbol,ordType,lot,entry,_slippage,SL,TP,comment,EA);
   if(orderID < 0) {
      Alert("Order ID: ", orderID, " - Send order ERROR: ", getErr());
      if(GetLastError() == 138) {
         Alert("Requote - Try again in 1 seconds");
         Sleep(1000);
         return -1;
      } else if(GetLastError() == 130) {
         Alert("Invalid stops - Stop trading for 1 hour");
         Sleep(1000*60*60);
         return -1;
      }else {
         ExpertRemove();
      }
   }
   return orderID;
}


double orderProfit(int ticket) {
   double _delta, pips, entry;
   
   if(selectOrder(ticket, SELECT_BY_TICKET, MODE_TRADES)){      
      entry = OrderOpenPrice();
      if(OrderType() == 0) {
         _delta = Ask - entry;
      } else {
         _delta = entry - Bid;
      }
      pips = NormalizeDouble(_delta/getPip(), 1);
      return pips;
   } else {
      return 0;
   }
}


bool closeOrder(int ticket, double lotSize, double price, int slippage) {
   bool stt = OrderClose(ticket, lotSize, price, slippage, 0);
   if (stt == false) {
      Alert ("Failed to close order: ", getErr());
   }
   
   return stt;
}


void modifyOrder(int ticket, double open, double SL, double TP, double _delta = 0.05) {
   bool selectStt = OrderSelect(ticket, SELECT_BY_TICKET);
   if(OrderStopLoss() != SL && MathAbs(OrderStopLoss() - SL) > _delta) {
      Print("Modifying order ", ticket, " - Open: ", open, " - SL: ", SL, " - TP: ", TP);
      bool modStt = OrderModify(ticket,open,SL,TP,0, Black);
      if (!modStt) {
         Alert ("Failed to modify order: ", getErr());
      }
   }
}


int countPosition(long magicNumber, int orderType=-1) {
   int count = 0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == false) {
         Alert("Fail to select position with ticket: ", OrderTicket());
         return 9999;
      }
      if(magicNumber == OrderMagicNumber()) {
         if(orderType != -1) {
            if(OrderType() == orderType) {
               count += 1;
            }
         }
         else {
            count += 1;
         }
      }
   }
   return count;
}


int lastOpenedOrder(int EA_ID) {
   int latestId = -1;
   
   // No order was opened
   if(countPosition(EA_ID) == 0) {
      return latestId;
   }
   
   // Get latest opened order
   datetime latestTime = D'2015.01.01 00:00';
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == false) {
         Alert("Fail to select position with ticket: ", OrderTicket());
         continue;
      }

      if(latestId == -1) {
         latestId = OrderTicket();
         latestTime = OrderOpenTime();
         continue;
      };
   
      datetime openTime = OrderOpenTime();
      if(openTime > latestTime) {
         latestId = OrderTicket();
         latestTime = openTime;
      }
   }
   
   return latestId;   
}


bool isRecentOpen(int delaySeconds) {
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         datetime openTime = OrderOpenTime();
         datetime limitTime = openTime + delaySeconds;
         if(TimeCurrent() < limitTime) {
            return true;
         }
      }
   }
   return false;
}


bool isRecentClose(int delaySeconds) {
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


double sumLot (string symbol, ENUM_ORDER_TYPE orderType) {
   double totalLot = 0.0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         if(OrderType() == orderType) {
            totalLot += OrderLots();
         }
      }
   }
   return totalLot;
}


bool deletePendingOrders(int orderType=-1) {
   // In case trigger first postion and still hanging the second position
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         if(OrderType() == ORDER_TYPE_BUY_STOP || OrderType() == ORDER_TYPE_SELL_STOP) {
            if(orderType != -1) {
               if(orderType == OrderType()) {
                  bool stt = OrderDelete(OrderTicket());
               }
            } else {
               bool stt = OrderDelete(OrderTicket());
            }
         }
      }
   }
   return true;
}


bool closeAllOrder(int slippage) {
   bool finalStt = True;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         if(OrderType() == ORDER_TYPE_BUY) {
            bool stt = closeOrder(OrderTicket(), OrderLots(), Bid, slippage);
            finalStt = finalStt && stt;
         } 
         
         else if(OrderType() == ORDER_TYPE_SELL) {
            bool stt = closeOrder(OrderTicket(), OrderLots(), Ask, slippage);
            finalStt = finalStt && stt;
         }
      }
   }
   
   return finalStt;
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


bool idcUpward(double& buffer[], double threshold = 0.0) {
   int size = ArraySize(buffer);
   bool upward = isArrIncrease(buffer);
   if(upward) {
      double _delta = MathAbs(buffer[0] - buffer[size-1]);
      if(_delta > threshold) {
         return true;
      }
   }
   return false;
}


bool idcDownward(double& buffer[], double threshold = 0.0) {
   int size = ArraySize(buffer);
   bool downward = isArrDecrease(buffer);
   if(downward) {
      double _delta = MathAbs(buffer[0] - buffer[size-1]);
      if(_delta > threshold) {
         return true;
      }
   }
   return false;
}


bool isParallel(double& line1[], double& line2[], double& line3[]) {
   int size = ArraySize(line1);
   for(int i=1; i<size-1; i++) {
      if(!(line1[i] > line2[i] && line2[i] > line3[i])) {
         return false;
      }
   }
   return true;
}


bool isDivergence(double& line1[], double& line2[]) {
   int size = ArraySize(line1);
   int midIdx = MathRound(size/2) + 1;
   double firstDiff = MathAbs(line2[size-1] - line1[size-1]);
   double midDiff   = MathAbs(line2[midIdx] - line1[midIdx]);
   double lastDiff  = MathAbs(line2[0] - line1[0]);
   
   // printf("firstDiff: %.2f, midDiff: %.2f, lastDiff: %.2f", firstDiff, midDiff, lastDiff);
   if(firstDiff <= midDiff && midDiff <= lastDiff) {
      return true;
   }
   return false;
}


bool isConvergence(double& line1[], double& line2[], double threshold = 999) {
   int size = ArraySize(line1);
   int midIdx = MathRound(size/2) + 1;
   double firstDiff = MathAbs(line2[size-1] - line1[size-1]);
   double midDiff   = MathAbs(line2[midIdx] - line1[midIdx]);
   double lastDiff  = MathAbs(line2[0] - line1[0]);
   
   // printf("firstDiff: %.2f, midDiff: %.2f, lastDiff: %.2f", firstDiff, midDiff, lastDiff);
   if(firstDiff >= midDiff && midDiff >= lastDiff && lastDiff < threshold) {  
      return true;
   }
   return false;
}


bool isSideway(double& line1[], double& line2[], double threshold) {
   int size = ArraySize(line1);
   double sum = 0;
   for(int i=0; i<size-1; i++) {
      double _delta = MathAbs(line2[i] - line1[i]);
      sum += _delta;
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
   for(int i=1; i<size; i++) {
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
   for(int i=1; i<size; i++) {
      double nextValue = data[i];
      if(curValue >= nextValue) {
         return false;
      } else {
         curValue = nextValue;
      }
   }
   return true;
}


/*********************************
*        CANDEL METHODS          *
*********************************/

bool isCandlesType(string symbol, ENUM_TIMEFRAMES TimeFrame, int range, int type) {
   for(int i=1; i<=range; i++) {
      int eleType = candleType(symbol, TimeFrame, i);
      if (eleType != type) {
         return false;
      }      
   }
   return true;
}


int candleType(string symbol, ENUM_TIMEFRAMES TimeFrame, int shift) {
   double open = iOpen(symbol, TimeFrame,shift); 
   double close = iClose(symbol, TimeFrame,shift);
   if(open < close) {
      return 0;   //GREEN
   }
   return 1;      //RED
}


string determineTrend(int numCandle, ENUM_TIMEFRAMES TimeFrame) {
   int bull = 0;
   int bear = 0;

   for(int idx=1; idx<=numCandle; idx++) {
      double open  = iOpen(Symbol(), TimeFrame, idx);
      double close = iClose(Symbol(), TimeFrame, idx);
      if(open < close) bull++;
      if(open > close) bear++; 
   }
   
   if(bull > bear) return "buy";
   if(bear > bull) return "sell";
   return "wait";
}


bool isLocalExtremum(int candleIdx,string type, ENUM_TIMEFRAMES TimeFrame, double _delta=0) {
   double priceArr[4];
   int range = ArraySize(priceArr);
   if(type == "high") {
      for(int idx=0; idx<range; idx++) {
         priceArr[idx] = High[candleIdx+idx];
      }
      int maxIdx = ArrayMaximum(priceArr, WHOLE_ARRAY, 0);
      double lastVal = High[candleIdx] + _delta;
      if(lastVal >= priceArr[maxIdx]) {
         return true;
      }
   }
   
   else if (type == "low") {
      for(int idx=0; idx<range; idx++) {
         priceArr[idx] = Low[candleIdx+idx];
      }
      int minIdx = ArrayMinimum(priceArr, WHOLE_ARRAY, 0);
      double lastVal = Low[candleIdx] - _delta;
      if(lastVal <= priceArr[minIdx]) {
         return true;
      }
   }
   
   return false;
}


void addToDoubleArray( double& theArray[][], double size, double price ) {
   ArrayResize( theArray, ArraySize( theArray ) + 1 );
   theArray[ ArraySize( theArray ) ][0] = size;
   theArray[ ArraySize( theArray ) ][1] = price;
}


/*********************************
*      MATHEMATIC METHODS        *
*********************************/
bool inRange(double value, double center, double _delta) {
   if(center - _delta <= value && value <= center + _delta) {
      return true;
   }
   return false;
}



/*********************************
*         TRADING HOURS          *
*********************************/
// Definition of an hour. This is necessary for a drop down menu for hours input.
enum ENUM_HOUR
{
   h00 = 000, // 00:00
   h01 = 010, // 01:00
   h02 = 020, // 02:00
   h03 = 030, // 03:00
   h04 = 040, // 04:00
   h05 = 050, // 05:00
   h06 = 060, // 06:00
   h07 = 070, // 07:00
   h08 = 080, // 08:00
   h09 = 090, // 09:00
   h10 = 100, // 10:00
   h11 = 110, // 11:00
   h12 = 120, // 12:00
   h13 = 130, // 13:00
   h14 = 140, // 14:00
   h15 = 150, // 15:00
   h16 = 160, // 16:00
   h17 = 170, // 17:00
   h18 = 180, // 18:00
   h19 = 190, // 19:00
   h20 = 200, // 20:00
   h21 = 210, // 21:00
   h22 = 220, // 22:00
   h23 = 230, // 23:00
   h00p5 = 005, // 00:30
   h01p5 = 015, // 01:30
   h02p5 = 025, // 02:30
   h03p5 = 035, // 03:30
   h04p5 = 045, // 04:30
   h05p5 = 055, // 05:30
   h06p5 = 065, // 06:30
   h07p5 = 075, // 07:30
   h08p5 = 085, // 08:30
   h09p5 = 095, // 09:30
   h10p5 = 105, // 10:30
   h11p5 = 115, // 11:30
   h12p5 = 125, // 12:30
   h13p5 = 135, // 13:30
   h14p5 = 145, // 14:30
   h15p5 = 155, // 15:30
   h16p5 = 165, // 16:30
   h17p5 = 175, // 17:30
   h18p5 = 185, // 18:30
   h19p5 = 195, // 19:30
   h20p5 = 205, // 20:30
   h21p5 = 215, // 21:30
   h22p5 = 225, // 22:30
   h23p5 = 235, // 23:30   

};

bool checkActiveHours(ENUM_HOUR StartHour, ENUM_HOUR LastHour)
{
   // Set operations disabled by default.
   StartHour = StartHour/10;
   LastHour = LastHour/10;
   bool OperationsAllowed = false;
   // Check if the current hour is between the allowed hours of operations. If so, return true.
   if ((StartHour == LastHour) && (Hour() == StartHour))
      OperationsAllowed = true;
   if ((StartHour < LastHour) && (Hour() >= StartHour) && (Hour() <= LastHour))
      OperationsAllowed = true;
   if ((StartHour > LastHour) && (((Hour() >= LastHour) && (Hour() <= 23)) || ((Hour() <= StartHour) && (Hour() > 0))))
      OperationsAllowed = true;
   return OperationsAllowed;
}


/*******************************
* UTILS BY GPT
*******************************/
int getLastOpenedOrderIdByType() {
    int lastOrder = OrdersTotal() - 1; // Get the index of the last order
    if (lastOrder >= 0) { // Check if there is at least one order
        for (int i = lastOrder; i >= 0; i--) { // Loop through orders in reverse order
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { // Select the order
                if (OrderType() == ORDER_TYPE_BUY || OrderType() == ORDER_TYPE_SELL) { // Check if the order type matches
                    int lastOrderId = OrderTicket(); // Get the order ID
                    return lastOrderId; // Return the order ID
                }
            } else {
                Print("Error selecting order: ", GetLastError());
            }
        }
    } else {
        Print("No orders found.");
    }
    return 0; // Return 0 if no matching order is found
}


int randomZeroOrOne()
{
    int randomNum = MathRand();
    int zeroOrOne = randomNum % 2;
    return zeroOrOne;
}


double calculateClosedProfit(datetime from, datetime to)
{
    double profit = 0;
    int total = OrdersHistoryTotal();
    for (int i = total - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if (OrderCloseTime() >= from && OrderCloseTime() <= to) {
                profit += OrderProfit();
            }
        }
    }
    return profit;
}

