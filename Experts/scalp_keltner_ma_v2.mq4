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
input int TPPips = 20; //Take profit pips
input int SLPips = 20; //Take profit pips
input int delay = 2;
input int thresholdKN = 0.5; // Trend delta
input int thresholdMA = 0.5; // Trend delta
input long magicNumber = 8888; // Expert ID
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;

int slippage = 10;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double   bufMA1[5], 
         bufMA2[5], 
         keltnerUp[5], 
         keltnerMid[5], 
         keltnerLow[5],
         priceClose[5], 
         priceOpen[5];
int arrSize = 5;

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
   for(int i=0; i<arrSize; i++) {
      bufMA1[i] = iMA(Symbol(),TIME_FRAME,10,0,MODE_SMA,PRICE_CLOSE,i);
      bufMA2[i] = iMA(Symbol(),TIME_FRAME,200,0,MODE_SMA,PRICE_CLOSE,i);
      keltnerUp[i] = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",50,0,i);
      keltnerMid[i] = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",50,1,i);
      keltnerLow[i] = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",50,2,i);
   }
   
   CopyClose(Symbol(), TIME_FRAME, 0, arrSize, priceClose);
   CopyOpen(Symbol(), TIME_FRAME, 0, arrSize, priceOpen);
   
   // Last price
   int shift = 1;
   double ma1   = NormalizeDouble(bufMA1[shift], _Digits);
   double ma2   = NormalizeDouble(bufMA2[shift], _Digits);
   double upKN  = NormalizeDouble(keltnerUp[shift], _Digits);
   double midKN = NormalizeDouble(keltnerMid[shift], _Digits);
   double lowKN = NormalizeDouble(keltnerLow[shift], _Digits);
   double close = NormalizeDouble(priceClose[shift], _Digits);
   double open  = NormalizeDouble(priceOpen[shift], _Digits);

   // Signal
   bool isMA1Upward = false;
   bool isMA1Downward = false;
   bool isKNUpward = false;
   bool isKNDownward = false;
   bool isBuy = false;
   bool isSell = false;
   
   int totalPos  = countPosition(magicNumber);
   isMA1Upward   = idcUpward(bufMA1, arrSize, thresholdMA);   
   isMA1Downward = idcDownward(bufMA1, arrSize, thresholdMA);
   isKNUpward    = idcUpward(keltnerMid, arrSize, thresholdKN);
   isKNDownward  = idcDownward(keltnerMid, arrSize, thresholdKN);
   
   if(totalPos < maxPos) {     
      double SL;
      double keltnerWidth = MathAbs(lowKN-upKN);
      double curMA1 = NormalizeDouble(bufMA1[0], _Digits);
      double lastMA1 = NormalizeDouble(bufMA1[1], _Digits);
      // CANDLE COVER 2 KELTNER BAND
      // PRICE BELOW MID KELTNER AND 2 PREVIOUS CANDLES ARE RED
      
      
      // BUY
      if(isMA1Upward && isKNUpward) {
         if (close > upKN && isCandlesType(Symbol(),TIME_FRAME,2,0)) {
            if(inRange(close, upKN, keltnerWidth) && curMA1 > lastMA1) {
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
            if(inRange(close, lowKN, keltnerWidth) && curMA1 < lastMA1) {
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

