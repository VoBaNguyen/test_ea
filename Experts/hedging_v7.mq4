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
Hedging v7:
   + Open first trade randomly
   + Only trade in specific time that the market is stable

*/


//+------------------------------------------------------------------+
//| Include custom models                                            |
//+------------------------------------------------------------------+
#include <models/account.mqh>;
#include <common/utils.mqh>;


//+------------------------------------------------------------------+
//| Setup default parameters for the EA                              |
//+------------------------------------------------------------------+
input int slippage = 5;
input long EA_ID = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;
input int earnPerTrade    = 10;      // Least earn per trade (pips)
input double distance     = 20;     // Min distance between BUY/SELL (pips)
input double initLot      = 0.02;   // Initial Lot Size
input double rr           = 1.5;    // Reward/Risk
input ENUM_HOUR startTime = h04p5;   // Start trading time
input ENUM_HOUR endTime   = h19p5;   // End trading time
input int ATRPeriod = 16;           // ATR Period
input int targetProfit = 150 ;      // Profit target per day


// Calculate default setting
string tradeMode;
double initPrice, TPPips, SLPips, k;
double buySL, buyTP, sellSL, sellTP, initBuy, initSell;

MyAccount account = MyAccount("nguyen", "vo", EA_ID);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
	Print("Init hedging_v1 strategy");
   tradeMode = "None";
   initPrice = 0;
   TPPips = distance*rr;
   SLPips = distance*(1+rr);
   buySL = 0;
   buyTP = 0;
   sellSL = 0;
   sellTP = 0;
   initBuy = 0;
   initSell = 0;
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

	// Count BUY/SELL position to calculate
	int totalPos = countPosition(EA_ID, ORDER_TYPE_BUY) + countPosition(EA_ID, ORDER_TYPE_SELL);
	if(totalPos == 0) {

      // RESET: Close pending order from previous setup hedging.
   	closePendingOrders();   
      tradeMode = "None";
      initPrice = 0;
   
      // Check if current time in active hours
   	if(!checkActiveHours(startTime, endTime)) {
         return;
      }

      // If meet target profit - Close all order - Stop trading
      // Get the current date and time
      datetime now = TimeCurrent();
      // Set the time to midnight
      datetime deltaTime = StrToTime(TimeToStr(now)) % (24*60*60);
      datetime midnight = StrToTime(TimeToStr(now)) - deltaTime;
      
      // Calculate the profit for yesterday
      double todayProfit = calculateClosedProfit(midnight, now);
      if( todayProfit > targetProfit ) {
         printf("Today profit: %.2f > Target profit: %.2f", todayProfit, targetProfit);
         return;
      }

      openNewMarketOrder();
      return;
	}

   // Check if the first market order was execute successfully
   if(tradeMode == "None" || initPrice == 0) {
      Print("Setup not correct - Mode: ", tradeMode, " - Init price: ", initPrice);
      return;
   }
	
	// Check to open new STOP order
	int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
	if(pendingOrders == 0) {
      openNewStopOrder();
	}

}
//+------------------------------------------------------------------+


int openNewMarketOrder() {
   TPPips = distance*rr;
   SLPips = distance*(1+rr);

   // BUY as default
   RefreshRates();
   tradeMode = ORDER_TYPE_BUY;
   initPrice = Ask;
   sendOrder(Symbol(), ORDER_TYPE_BUY, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);

	// Send a market order
	/*
	if(randomZeroOrOne() == 0) {
	   RefreshRates();
	   tradeMode = ORDER_TYPE_BUY;
	   initPrice = Ask;
	   sendOrder(Symbol(), ORDER_TYPE_BUY, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
	}
	else if(randomZeroOrOne() == 1) {
	   RefreshRates();
	   tradeMode = ORDER_TYPE_SELL;
	   initPrice = Bid;
	   sendOrder(Symbol(), ORDER_TYPE_SELL, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
	}
	*/
	
	return 1;
}


void openNewStopOrder() {
   // If there's no pending order, we need to prepare for the next reverse of the price by open an opposite order.
   // Modify SL/TP and send new pending order. Suppose tradeMode is BUY.
	calculateOrder(initPrice, tradeMode);
   PrintFormat("initPrice: %.2f - initBuy: %.2f - initSell: %.2f", initPrice, initBuy, initSell);
   PrintFormat("distance: %.2f - TPPips: %.2f - SLPips: %.2f", distance, TPPips, SLPips);

	// Modify SL/TP of the first trade
	int totalPos = countPosition(EA_ID, ORDER_TYPE_BUY) + countPosition(EA_ID, ORDER_TYPE_SELL);
	if(totalPos == 1) {	
		int lastTicket = lastOpenedOrder(EA_ID);
	   OrderSelect(lastTicket, SELECT_BY_TICKET, MODE_TRADES);
	   initPrice = OrderOpenPrice();
      if(tradeMode == ORDER_TYPE_BUY) {
		   modifyOrder(lastTicket, OrderOpenPrice(), buySL, buyTP, 0);
      }
      else if(tradeMode == ORDER_TYPE_SELL) {
		   modifyOrder(lastTicket, OrderOpenPrice(), sellSL, sellTP, 0);
      }
   }
   
	int signum = MathPow(-1, totalPos+1);
	int lastTicket = getLastOpenedOrderIdByType();
	if(selectOrder(lastTicket, SELECT_BY_TICKET, MODE_TRADES)){
		int lastOrdType = OrderType();
      Print("lastOrdType: ", lastOrdType);
      PrintFormat("initBuy: %.2f - initSell: %.2f", initBuy, initSell);
      // PrintFormat("ORDER_TYPE_BUY: %d - ORDER_TYPE_SELL: %d", ORDER_TYPE_BUY, ORDER_TYPE_SELL);

		// Last order is BUY => Open SELL stop order
		if(lastOrdType == ORDER_TYPE_BUY) {
			double lot = (sumLot(Symbol(), ORDER_TYPE_BUY)*(SLPips + earnPerTrade))/TPPips 
							  - sumLot(Symbol(), ORDER_TYPE_SELL);
			lot = MathMax(NormalizeDouble(lot, 2), 0.01);
			int orderID = sendOrder(Symbol(), ORDER_TYPE_SELL_STOP, lot, initSell, slippage, sellSL, sellTP, "", EA_ID);
		}
		
		// Last order is SELL => Open BUY stop order
		else if(lastOrdType == ORDER_TYPE_SELL) {
			double lot = (sumLot(Symbol(), ORDER_TYPE_SELL)*(SLPips + earnPerTrade))/TPPips 
							  - sumLot(Symbol(), ORDER_TYPE_BUY);
			lot = MathMax(NormalizeDouble(lot, 2), 0.01);
			int orderID = sendOrder(Symbol(), ORDER_TYPE_BUY_STOP, lot, initBuy, slippage, buySL, buyTP, "", EA_ID);
		}
	}
}




void closePendingOrders() {
	// In case trigger first postion and still hanging the second position
	for(int i=0; i<OrdersTotal(); i++) {
		if(OrderSelect(i, SELECT_BY_POS) == true) {
			bool delStt = OrderDelete(OrderTicket());
		}
	}
}


void calculateOrder(double inputPrice, int inputMode) {
		initBuy = inputPrice;
		initSell = calSL(true, inputPrice, distance);
	   if(inputMode == ORDER_TYPE_SELL) {
	      initSell = initPrice;
   		initBuy = calTP(true, inputPrice, distance);
	   }
 
		buyTP = calTP(true, initBuy, TPPips);
		sellTP = calTP(false, initSell, TPPips);
		buySL = sellTP;
		sellSL = buyTP;
}

