//+------------------------------------------------------------------+
//|                                                   hedging_v1.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


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
input int earnPerTrade    = 5;     // Least earn per trade (pips)
input double minDistance  = 20;     // Min distance between BUY/SELL (pips)
input double initLot      = 0.01;   // Initial Lot Size
input double rr           = 1;      // Reward/Risk
input ENUM_HOUR startHighFluctuate = h07p5;   // Start London sesison/NY session
input ENUM_HOUR endHighFluctuate   = h22p5;   // End London sesison/NY session
input double ATRMultiplier = 1.5;   // ATR Multiplier in high fluctuate sessions
input int ATRPeriod = 20;           // ATR Period
input int RSIPeriod = 7;            // RSI Period

// Calculate default setting
string tradeMode;
double initPrice;
double distance;
double TPPips;
double SLPips;
double k;
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
   distance = minDistance;
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
	int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);

	if(totalPos == 0) {	
	   // RESET: Close pending order from previous setup hedging.
		closePendingOrders();   
	   tradeMode = "None";
      initPrice = 0;
      
      double RSI = iRSI(Symbol(), TIME_FRAME, RSIPeriod, PRICE_CLOSE, 0);

	   // Check ATR > Distance between BUY & SELL orders
      double ATR = iATR(Symbol(),TIME_FRAME,ATRPeriod,1);
      double ATRPips = NormalizeDouble(ATR/getPip(), Digits);    
		if(checkActiveHours(startHighFluctuate, endHighFluctuate)) {
			ATRPips = ATRPips*ATRMultiplier;
		}
      PrintFormat("ATR: %.2f - ATR pips: %.2f - ATRMultiplier: %.1f", ATR, ATRPips, ATRMultiplier);
      
      
		// OVERWRITE INITIAL SETTING!
		distance = MathMax(minDistance, ATRPips);
      TPPips = distance*rr;
      SLPips = distance*(1+rr);

		// Send a market order
		if(RSI >= 50) {
		   // RSI >= 50 => BUY => Entry = initBuy
		   tradeMode = ORDER_TYPE_BUY;
		   RefreshRates();
		   initPrice = Ask;
		   sendOrder(Symbol(), ORDER_TYPE_BUY, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
		}
		else if(RSI < 50) {
		   // RSI < 50 => SELL => Entry = initSell
		   tradeMode = ORDER_TYPE_SELL;
		   RefreshRates();
		   initPrice = Bid;
		   sendOrder(Symbol(), ORDER_TYPE_SELL, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
		}
		else {
		   Print("Something wrong  with RSI value");
		}
	}

	else {
	   if(tradeMode == "None" || initPrice == 0) {
	      Print("Setup not correct - Mode: ", tradeMode, " - Init price: ", initPrice);
	      return;
	   }
		
		int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
		if(pendingOrders == 0) {
		   // If there's no pending order, we need to prepare for the next reverse of the price by open an opposite order.
		   // Modify SL/TP and send new pending order.
   		// Suppose tradeMode is BUY.
   		calculateOrder(initPrice, tradeMode);
         Print("initPrice: ", initPrice);
         Print("initBuy: ", initBuy);
         Print("initSell: ", initSell);
         PrintFormat("distance: %.2f - TPPips: %.2f - SLPips: %.2f", distance, TPPips, SLPips);

   		// Modify SL/TP of the first trade
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
            Print("initBuy: ", initBuy);
            Print("initSell: ", initSell);
            Print("lastOrdType: ", lastOrdType);
            Print("ORDER_TYPE_BUY: ", ORDER_TYPE_BUY);
            Print("ORDER_TYPE_SELL: ", ORDER_TYPE_SELL);

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
	}
}
//+------------------------------------------------------------------+



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