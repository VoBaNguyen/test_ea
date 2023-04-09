//+------------------------------------------------------------------+
//|                                                   hedging_v1.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


/*
Hedging v9:
   + OUse OBV

*/


//+------------------------------------------------------------------+
//| Include custom models                                            |
//+------------------------------------------------------------------+
#include <common/utils.mqh>;


//+------------------------------------------------------------------+
//| Setup default parameters for the EA                              |
//+------------------------------------------------------------------+
input int slippage = 5;
input long EA_ID = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;
input double inputSize    = 0.01;   // Initial Lot Size
input ENUM_HOUR startTime = h02p5;  // Start trading time
input ENUM_HOUR endTime   = h22p5;  // End trading time
input double takeProfit = 5;      // Take Profit
input double obvThreshold = 5000;   // OBV Threshold
input int obvCandles = 10;  // OBV range


// Define global variables
double totalPosition = 0.0;   // Total position size
double equity = 0.0;          // Equity
double balance = 0.0;         // Balance
double maxDrawdown = 0;       // Max drag down
double drawdown = 0;
double TPPips, SLPips;
static datetime lastTime = 0; // Variable to store the last candle's time
double tradeMode = -1;         // Trade Mode
double initBalance, lotSize;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
	Print("Init hedging_v1 strategy");
   initBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   lotSize = inputSize;
	return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
	Print("Remove strategy");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {   

   // Call the function to update global variables
   UpdateAccountInfo();
   drawdown = balance - equity;
   maxDrawdown = MathMax(maxDrawdown, drawdown);
   
   // Display the values on the chart using Comment() function
   Comment(
          "BUY Position: " + countPosition(EA_ID, ORDER_TYPE_BUY) +
          "\nSELL Position: " + countPosition(EA_ID, ORDER_TYPE_SELL) +
          "\nEquity: " + DoubleToStr(equity, 2) +
          "\nBalance: " + DoubleToStr(balance, 2) +
          "\nMax drawdown: " + DoubleToStr(maxDrawdown, 2));

   // Check profit & close orders
   double profit = equity - balance;
   if(profit > 0) {
      if(profit > takeProfit) {
         closeAllOrders();
         tradeMode = -1;
         return;
      }
      
      // Contraction phase => Close all orders
      int signal = tradeSignal(); 
      if(signal == -1) {
         closeAllOrders();
         tradeMode = -1;
         return;
      }
   }

   if(!checkNewCandle()) {
      return;
   }
   
   // Check if current time in active hours
	if(!checkActiveHours(startTime, endTime)) return;

   // Check BUY/SELL signal
   int signal = tradeSignal();   
   
   // Open orders
   int totalPos = countPosition(EA_ID, ORDER_TYPE_BUY) + countPosition(EA_ID, ORDER_TYPE_SELL);
   if(totalPos == 0) {
      if(signal != -1) {
	      // lotSize = inputSize * NormalizeDouble(balance/initBalance, 2);
	      
         double ema20Shift = iMA(Symbol(), PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE, obvCandles); // Calculate EMA20 for the current symbol and timeframe
         double ema50Shift = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE, obvCandles); // Calculate EMA20 for the current symbol and timeframe

         // BUY, ema20 cut ema50 upward
         if(signal == 0 && ema20Shift < ema50Shift) {
	         openNewMarketOrder(signal);
	      }
	      // SELL, ema20 cut ema50 downward
	      else if(signal == 1 && ema20Shift > ema50Shift) {
	         openNewMarketOrder(signal);
	      }
	      
         tradeMode = signal;
         return;
      }
   }
   
   if(signal == tradeMode) {
      openNewMarketOrder(signal);
   }
}
//+------------------------------------------------------------------+

// Update global variables with relevant values
void UpdateAccountInfo() {
   totalPosition = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
}


int tradeSignal() {
   double obv = getOBVMaxMinDifference(0, obvCandles);
   if(obv > obvThreshold) {
      double ema20 = iMA(Symbol(), PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE, 0); // Calculate EMA20 for the current symbol and timeframe
      double ema50 = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE, 0); // Calculate EMA20 for the current symbol and timeframe

      double lastClose = Close[0]; // Get the last close price
      if (lastClose > ema20 && ema20 > ema50) {
        return 0; // Return "BUY" if last close price > EMA20
      } else if(lastClose < ema20 && ema20 < ema50) {
        return 1; // Return "SELL" if last close price < EMA20
      }
   }
   
  return -1;
}


double getOBVMaxMinDifference(int shift, int numCandles)
{
    double obvMax = 0; // Maximum OBV value
    double obvMin = 0; // Minimum OBV value

    // Loop through the candles from shift to (shift + numCandles)
    for (int i = shift; i < shift + numCandles; i++)
    {
        double obv = iOBV(Symbol(), PERIOD_CURRENT, 0, i); // Get OBV value of the i-th candle

        // Update obvMax and obvMin
        if (i == shift)
        {
            obvMax = obv;
            obvMin = obv;
        }
        else
        {
            if (obv > obvMax)
                obvMax = obv;
            if (obv < obvMin)
                obvMin = obv;
        }
    }

    // Return the difference between obvMax and obvMin
    return obvMax - obvMin;
}


int openNewMarketOrder(int signal) {
	// Send a market order
	if(signal == 0) {
	   RefreshRates();
	   sendOrder(Symbol(), ORDER_TYPE_BUY, lotSize, Ask, slippage, 0, 0, "Open BUY order.", EA_ID);
	}
	else if(signal == 1) {
	   RefreshRates();
	   sendOrder(Symbol(), ORDER_TYPE_SELL, lotSize, Bid, slippage, 0, 0, "Open SELL order.", EA_ID);
	}
	
	return 1;
}


void closePendingOrders() {
	// In case trigger first postion and still hanging the second position
	for(int i=0; i<OrdersTotal(); i++) {
		if(OrderSelect(i, SELECT_BY_POS) == true) {
			bool delStt = OrderDelete(OrderTicket());
		}
	}
}


// Function to close all orders at market price
void closeAllOrders() {
    int totalOrders = OrdersTotal();
    
    // Loop through all orders
    for (int i = totalOrders - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            // Check if the order is open and not a pending order
            if (OrderType() <= OP_SELL) {
                // Close the order at market price
                double closePrice;
                if (OrderType() == OP_BUY) {
                    closePrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
                } else {
                    closePrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
                }
                int ticket = OrderTicket();
                int result = OrderClose(ticket, OrderLots(), closePrice, slippage, clrNONE);
                
                // Check for errors in closing the order
                if (result < 0) {
                    Print("Error closing order #", ticket, ". Error code: ", GetLastError());
                } else {
                    Print("Order #", ticket, " closed at market price");
                }
            }
        }
    }
}


bool checkNewCandle()
{
    // Get the current bar's time
    datetime currentBarTime = Time[0];

    // Check if the current bar's time is greater than the last candle's time
    if (currentBarTime > lastTime)
    {
        lastTime = currentBarTime; // Update the last candle's time
        return true; // Return true if a new candle has appeared
    }

    return false; // Return false otherwise
}

