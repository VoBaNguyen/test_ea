//+------------------------------------------------------------------+
//|                                               master_pattern.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int checkTime, periodTime;
int candles = 7;
double markPriceH4 = 0;
int rangeH4 = 75;
double markPriceM15 = 0;
int rangeM15 = 15;
int mode = -1;
double lotSize = 0.05;
int sleepTime = 3600;
double profitTarget = 100.0; // Close all orders with a profit of at least 100
int tradeTime = 0;

int OnInit()
  {
//---
   checkTime = 0;
   periodTime = GetCurrentPeriodInSeconds();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   if(TimeCurrent() < tradeTime) {
      return;
   }

   // Example usage
   int buyPositions = 0;
   int sellPositions = 0;
   
   CountOpenPositions(buyPositions, sellPositions);
   if( buyPositions + sellPositions > 0 ) {
   
      bool nextContractionH4 = drawBlueRectangleIfInRange(PERIOD_H4, candles, rangeH4);
      if(nextContractionH4) {
         CloseOrdersIfTotalProfitReached(profitTarget);
      }
   }

   if(markPriceH4 > 0) {
      if( mode == -1 ) {
         double closePrice = iClose(_Symbol, PERIOD_H4, 0);
         if( closePrice > increasePriceByPips(markPriceH4, rangeH4 ) ) {
            mode = 0; // BUY
         } 
         else if( closePrice < increasePriceByPips(markPriceH4, - rangeH4) ) {
            mode = 1; // SELL
         }
      }
      
      else {
         double closePrice = iClose(_Symbol, PERIOD_H4, 0);
         if(mode == 0 && closePrice < markPriceH4) {
            SendMarketOrder(_Symbol, OP_BUY, lotSize);
            tradeTime = TimeCurrent() + sleepTime;
         }
         else if(mode == 1 && closePrice > markPriceH4) {
            SendMarketOrder(_Symbol, OP_SELL, lotSize);
            tradeTime = TimeCurrent() + sleepTime;
         }
      }
      
      /*
      if(mode != -1) {
         bool contractionM15 = drawBlueRectangleIfInRange(PERIOD_M15, candles, rangeM15);
         // If the current bar is outside the range, return false
         if(contractionM15) {
            if (highPrice > increasePriceByPips(Ask, pipRange) || lowPrice < increasePriceByPips(Bid, - pipRange)) {
               return false;
            }
         }
      */
      
   } else {
      bool contractionH4 = drawBlueRectangleIfInRange(PERIOD_H4, candles, rangeH4);
   }

  }
//+------------------------------------------------------------------+

void CountOpenPositions(int &buyPositions, int &sellPositions) {
    buyPositions = 0;
    sellPositions = 0;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() == OP_BUY && OrderStopLoss() == 0 && OrderTakeProfit() == 0) {
                buyPositions++;
            } else if (OrderType() == OP_SELL && OrderStopLoss() == 0 && OrderTakeProfit() == 0) {
                sellPositions++;
            }
        }
    }
}


void CloseOrdersIfTotalProfitReached(double profitTarget) {
    int totalOrders = OrdersTotal();
    double totalProfit = 0.0;
    
    for (int i = totalOrders - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            totalProfit += OrderProfit();
        }
    }
    
    if (totalProfit >= profitTarget) {
        for (int i = totalOrders - 1; i >= 0; i--) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                bool closeResult = OrderClose(OrderTicket(), OrderLots(), Bid, 5, Green);
                
                if (closeResult) {
                    Print("Order #", OrderTicket(), " closed successfully at ", Bid);
                } else {
                    Print("Order #", OrderTicket(), " close failed with error code ", GetLastError());
                }
            }
        }
    }
}


void SleepSeconds(int seconds) {
    Sleep(seconds * 1000);
}


void SendMarketOrder(string symbol, int tradeType, double lotSize) {
    int slippage = 5; // Set desired slippage value here
    double stopLoss = 0; // Set desired stop loss value here
    double takeProfit = 0; // Set desired take profit value here
    
    int ticket = OrderSend(symbol, tradeType, lotSize, MarketInfo(symbol, MODE_ASK), slippage, stopLoss, takeProfit, "", 0, 0, Green);
    
    if (ticket > 0) {
        Print("Order sent successfully. Ticket #", ticket);
    } else {
        Print("Order send failed. Error code:", GetLastError());
    }
}


bool drawBlueRectangleIfInRange(ENUM_TIMEFRAMES period, int numCandles, int pipRange) {
    datetime startTime = 0;
    datetime endTime = 0;
    double maxPrice = 0;
    double minPrice = 0;

    // Loop through the last numCandles bars
    for (int i = 0; i < numCandles; i++) {
        // Get the open and close prices of the current bar
        double openPrice = iOpen(_Symbol, period, i);
        double closePrice = iClose(_Symbol, period, i);

        // Find the maximum and minimum prices of the current bar
        double highPrice = MathMax(openPrice, closePrice);
        double lowPrice = MathMin(openPrice, closePrice);

        // If this is the first iteration, set the start and end times
        if (i == 0) {
            startTime = iTime(_Symbol, period, i);
        }
        endTime = iTime(_Symbol, period, i);

        // Update the MathMax and MathMin prices for all bars
        if (highPrice > maxPrice) {
            maxPrice = highPrice;
        }
        if (minPrice == 0 || lowPrice < minPrice) {
            minPrice = lowPrice;
        }
        
        // If the current bar is outside the range, return false
        if (highPrice > increasePriceByPips(Ask, pipRange) || lowPrice < increasePriceByPips(Bid, - pipRange)) {
            return false;
        }
    }

    // If all bars are inside the range, draw the rectangle and return true
    string rectName = "BlueRect_" + TimeToString(Time[0], TIME_DATE | TIME_MINUTES);
    string segName = "Seg_" + TimeToString(Time[0], TIME_DATE | TIME_MINUTES);
    ObjectCreate(rectName, OBJ_RECTANGLE, 0, startTime, maxPrice, endTime, minPrice);
    ObjectSet(rectName, OBJPROP_COLOR, Blue);
    
    double avgPrice = (maxPrice + minPrice)/2;
    ObjectCreate(segName, OBJ_TREND, 0, endTime, avgPrice, endTime + PeriodSeconds() * 10, avgPrice);
    ObjectSet(segName, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSet(segName, OBJPROP_COLOR, Red);
    ObjectSet(segName, OBJPROP_WIDTH, 1);
    
    if(period == PERIOD_H4) {
      markPriceH4 = avgPrice;
    } else if(period == PERIOD_M15) {
      markPriceM15 = avgPrice;
    }
    
    return true;
}


double increasePriceByPips(double price, double pips) {
    double pipSize = Point();
    string symbol = Symbol();

    if (symbol == "XAUUSDm") {
        pipSize = 0.1;
    } else if (symbol == "EURUSDm") {
        pipSize = 0.0001;
    } else {
        int digits = MarketInfo(symbol, MODE_DIGITS);
        pipSize = pipSize / MathPow(10, digits);
    }

    return (price + (pips * pipSize));
}


// Get the current chart period in seconds
int GetCurrentPeriodInSeconds()
{
    // Get the current chart period
    int chartPeriod = Period();

    // Convert chart period to seconds
    int chartPeriodInSeconds = 0;

    switch (chartPeriod)
    {
        case PERIOD_M1:
            chartPeriodInSeconds = 60;
            break;
        case PERIOD_M5:
            chartPeriodInSeconds = 5 * 60;
            break;
        case PERIOD_M15:
            chartPeriodInSeconds = 15 * 60;
            break;
        case PERIOD_M30:
            chartPeriodInSeconds = 30 * 60;
            break;
        case PERIOD_H1:
            chartPeriodInSeconds = 60 * 60;
            break;
        case PERIOD_H4:
            chartPeriodInSeconds = 4 * 60 * 60;
            break;
        case PERIOD_D1:
            chartPeriodInSeconds = 24 * 60 * 60;
            break;
        case PERIOD_W1:
            chartPeriodInSeconds = 7 * 24 * 60 * 60;
            break;
        case PERIOD_MN1:
            chartPeriodInSeconds = 30 * 24 * 60 * 60;
            break;
    }

    return chartPeriodInSeconds;
}
