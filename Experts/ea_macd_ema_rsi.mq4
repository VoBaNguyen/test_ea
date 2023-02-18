//+------------------------------------------------------------------+
//|                                                    ma_signal.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


//+------------------------------------------------------------------+
//| Include system modules                                           |
//+------------------------------------------------------------------+
#include <stderror.mqh>
#include <stdlib.mqh>

//+------------------------------------------------------------------+
//| Include custom modules                                           |
//+------------------------------------------------------------------+
#include <common/utils.mqh>;
#include <models/account.mqh>;

//+------------------------------------------------------------------+
//| Input EA                                                         |
//+------------------------------------------------------------------+
input double lotSize = 0.1; // Lot Size
input int maxPos = 1; //Max Position
input int TPPips = 25; //Take profit pips
input int SLPips = 25; //Take profit pips
input int delay = 2;
input double thresholdKN = 0.0; // Trend delta
input double thresholdMA = 0.25; // Trend delta
input long magicNumber = 8888; // Expert ID
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;

int slippage = 10;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double   bufMA50[4], 
         bufMA200[4], 

int arrSize = 4;
int periodMA1 = 10;
int periodMA2 = 200;
int periodLKN = 50;

int OnInit()
  {
//---
   Alert("Init Kelter MA scalping strategy");
//---
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Alert("Remove strategy");
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
   // Collect data   
   for(int i=1; i<arrSize+1; i++) {
      bufMA1[i-1]     = iMA(Symbol(),TIME_FRAME,periodMA1,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA2[i-1]     = iMA(Symbol(),TIME_FRAME,periodMA2,0,MODE_SMA,PRICE_CLOSE,i);
      keltnerUp[i-1]  = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",periodLKN,0,i);
      keltnerMid[i-1] = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",periodLKN,1,i);
      keltnerLow[i-1] = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",periodLKN,2,i);
   }
   CopyClose(Symbol(), TIME_FRAME, 0, arrSize, priceClose);
   CopyOpen(Symbol(), TIME_FRAME, 0, arrSize, priceOpen);
   
   // Last price
   int shift = 0;
   double ma1   = NormalizeDouble(bufMA1[shift], _Digits);
   double ma2   = NormalizeDouble(bufMA2[shift], _Digits);
   double upKN  = NormalizeDouble(keltnerUp[shift], _Digits);
   double midKN = NormalizeDouble(keltnerMid[shift], _Digits);
   double lowKN = NormalizeDouble(keltnerLow[shift], _Digits);
   double close = NormalizeDouble(priceClose[shift], _Digits);
   double open  = NormalizeDouble(priceOpen[shift], _Digits);


   int totalPos  = countPosition(magicNumber);
   if(totalPos < maxPos) {
   
      // Signal
      bool isMA1Upward   = idcUpward(bufMA1, arrSize, thresholdMA);   
      bool isMA1Downward = idcDownward(bufMA1, arrSize, thresholdMA);
      bool isKNUpward    = idcUpward(keltnerMid, arrSize, thresholdKN);
      bool isKNDownward  = idcDownward(keltnerMid, arrSize, thresholdKN);
      double keltnerWidth = MathAbs(lowKN-upKN);
      double curMA1 = NormalizeDouble(iMA(Symbol(),TIME_FRAME,periodMA1,0,MODE_SMA,PRICE_CLOSE,0), _Digits);
      double lastMA1 = NormalizeDouble(iMA(Symbol(),TIME_FRAME,periodMA1,0,MODE_SMA,PRICE_CLOSE,1), _Digits);
      bool isBuy = false;
      bool isSell = false;
      double SL;
      
      // Case 1: CANDLE COVER 2 KELTNER BAND
      // Case 2: PRICE BELOW MID KELTNER AND 2 PREVIOUS CANDLES ARE RED
      // BUY
      if(isMA1Upward && isKNUpward) {
         if (close > upKN && isCandlesType(Symbol(),TIME_FRAME,2,0)) {
            if(inRange(close, upKN, keltnerWidth/2) && curMA1 > lastMA1) {
               isBuy = true;
               SL = midKN;
            }
         } else if(open < lowKN && close > midKN && close < upKN) {
            isBuy = true;
            SL = lowKN;
         }
      }
      
      // SELL
      if(isMA1Downward && isKNDownward) {
         if(close < lowKN && isCandlesType(Symbol(),TIME_FRAME,2,1)) {
            if(inRange(close, lowKN, keltnerWidth/2) && curMA1 < lastMA1) {
               isSell = true;
               SL = midKN;
            }
         } else if(open > upKN && close < midKN && close > lowKN) {
            isSell = true;
            SL = upKN;
         }
      }
      
      
      //+------------------------------------------------------------------+
      //| CHECK DUPLICATE POSITIONS                                        |
      //+------------------------------------------------------------------+   
      if(isBuy || isSell) {
         long delaySec = delay * PeriodSeconds(TIME_FRAME);
         bool recentClose = isRecentClose(delaySec);   
         if(recentClose) {
            isBuy = false;
            isSell = false;
         }
      }
      
      //+------------------------------------------------------------------+
      //| SEND ORDERS                                                      |
      //+------------------------------------------------------------------+  
      if(isBuy || isSell) {
         // Manage orders
         if(isBuy) {
            sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, SL, 0, "", magicNumber);
         } else if(isSell) {
            sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, SL, 0, "", magicNumber);
         }
      }
   }


   if(totalPos >= maxPos) {
      //+------------------------------------------------------------------+
      //| MOVE STOPLOSS                                                    |
      //+------------------------------------------------------------------+
      for(int i=0; i<OrdersTotal(); i++) {
         double ref;
         if(OrderSelect(i, SELECT_BY_POS) == true) {
            int ticket = OrderTicket();
            double size = OrderLots();
            if(OrderType() == 0){
               // Move SL to middle band
               if(Bid > upKN) {
                  modifyOrder(ticket, OrderOpenPrice(), midKN, 0);
               }
            }
            
            if(OrderType() == 1) {
               // Move SL to middle band
               if(Ask < lowKN) {
                  modifyOrder(ticket, OrderOpenPrice(), midKN, 0);
               }
            }


            //TP 50%
            //if(orderProfit(ticket) > TPPips/2 && OrderLots() > lotSize/2) {
            //   if(OrderType() == 0) {
            //      closeOrder(ticket, OrderLots()/2, Bid, slippage);
            //   }
            //   if(OrderType() == 1) {
            //      closeOrder(ticket, OrderLots()/2, Ask, slippage);
            //   }
            //}
            
            // TAKE PROFIT
            if(orderProfit(ticket) > TPPips) {
               if(OrderType() == 0) {
                  closeOrder(ticket, OrderLots(), Bid, slippage);
               } else {
                  closeOrder(ticket, OrderLots(), Ask, slippage);
               }
            }
         }
      }
   }


  }
//+------------------------------------------------------------------+

