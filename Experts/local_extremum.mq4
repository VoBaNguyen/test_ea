//+------------------------------------------------------------------+
//|                                               local_extremum.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

int numCandles = 24;
datetime lastCandleTime = 0;
double lotSize = 0.05;
int buyCount, sellCount;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
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
   if(isNewCandle()) {
      markCandle(numCandles, "max");
      markCandle(numCandles, "min");
   }
   
   CloseOrdersIfTotalProfitGreaterThan(100);
  }
//+------------------------------------------------------------------+

void CountOpenOrders(int& buyCount, int& sellCount)
{
    buyCount = 0;
    sellCount = 0;
    int totalOrders = OrdersTotal();
    for (int i = 0; i < totalOrders; i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderType() == OP_BUY)
            {
                buyCount++;
            }
            else if (OrderType() == OP_SELL)
            {
                sellCount++;
            }
        }
    }
}


bool isNewCandle() {
    // Check if the current candle's time is greater than the last candle's time
    if (Time[0] > lastCandleTime) {
        lastCandleTime = Time[0];
        return true;
    } else {
        return false;
    }
}


void markCandle(int numCandles, string mode) {
    // Define variables
    double highestHigh = High[Highest(NULL, 0, MODE_HIGH, numCandles, 1)];
    double lowestLow = Low[Lowest(NULL, 0, MODE_LOW, numCandles, 1)];
    double ema20 = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    // Calculate the ATR 14 value
    double atr = iATR(NULL, 0, 14, 1);
    int arrowCode;

    // Check if the highest/lowest high/low price of the last candle meets the criteria
    // PrintFormat("High: %.4f - Max: %.4f - Low: %.4f - Min: %.4f", High[0], highestHigh, Low[0], lowestLow);
    CountOpenOrders(buyCount, sellCount);
    if (mode == "max" && High[1] == highestHigh && highestHigh > ema20) {
        arrowCode = 234; // red down arrow code
        string arrowName = "MaxArrow_" + IntegerToString(Bars) + "_" + IntegerToString(TimeCurrent());
        ObjectCreate(arrowName, OBJ_ARROW, 0, Time[0], highestHigh);
        ObjectSet(arrowName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSet(arrowName, OBJPROP_COLOR, Red);
        ObjectSet(arrowName, OBJPROP_WIDTH, 2);
        ObjectSet(arrowName, OBJPROP_SELECTABLE, false);
        ObjectSet(arrowName, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, arrowName, OBJPROP_YDISTANCE, MathRound(atr));
        if(buyCount == 0 || sellCount > 0) {
            SendMarketOrder(_Symbol, OP_SELL, lotSize);
        }
        
    } else if (mode == "min" && Low[1] == lowestLow && lowestLow < ema20) {
        arrowCode = 233; // blue up arrow code
        string arrowName = "MinArrow_" + IntegerToString(Bars) + "_" + IntegerToString(TimeCurrent());
        ObjectCreate(arrowName, OBJ_ARROW, 0, Time[0], lowestLow);
        ObjectSet(arrowName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSet(arrowName, OBJPROP_COLOR, Blue);
        ObjectSet(arrowName, OBJPROP_WIDTH, 2);
        ObjectSet(arrowName, OBJPROP_SELECTABLE, false);
        ObjectSet(arrowName, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, arrowName, OBJPROP_YDISTANCE, MathRound(atr));
        SendMarketOrder(_Symbol, OP_SELL, lotSize);
        if(sellCount == 0 || buyCount > 0) {
            SendMarketOrder(_Symbol, OP_BUY, lotSize);
        }
    }
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


void CloseOrdersIfTotalProfitGreaterThan(double profit)
{
    // Get the total profit of all open orders
    double totalProfit = 0.0;
    int totalOrders = OrdersTotal();
    for (int i = 0; i < totalOrders; i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            double orderProfit = OrderProfit();
            totalProfit += orderProfit;
        }
    }
    
    // Close all orders if the total profit is greater than the input value
    if (totalProfit > profit)
    {
        for (int i = 0; i < totalOrders; i++)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
            }
        }
    }
}
