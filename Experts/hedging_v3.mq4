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
input int slippage = 0;
input long EA_ID = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_M15;
input ENUM_HOUR startHour = h09;  // Start operation hour
input ENUM_HOUR lastHour  = h21;  // Last operation hour
input int earnPerTrade    = 10;    // Least earn per trade
input int delta           = 10;   // Distance between BUY/SELL vs Entry
input double minATR       = 1.5;    // Min ATR
input double initLot      = 0.02; // Initial Lot Size
input double rr           = 0.5;    // Reward/Risk

// Calculate default setting
double distance = delta*2;
double TPPips = distance*rr;
int k = distance + TPPips;
double initPrice = 0;

MyAccount account = MyAccount("nguyen", "vo", EA_ID);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
	Print("Init hedging_v1 strategy");
//---
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
	if(initPrice == 0) {
		initPrice = Ask;
	}

	// Count BUY/SELL position to calculate
	int totalPos = countPosition(EA_ID, ORDER_TYPE_BUY) + countPosition(EA_ID, ORDER_TYPE_SELL);
	int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);

	if(totalPos == 0) {
	
	   // Close pending order from previous setup hedging.
		closeOldPendingOrders();
	
		// Check active hours
		if(!checkActiveHours(startHour, lastHour)) {
			return;
		}      

		if(pendingOrders == 0) {
		   // Check ATR > Distance between BUY & SELL orders
         double ATRFast = iATR(Symbol(),TIME_FRAME,10,1);
         double ATRSlow = iATR(Symbol(),TIME_FRAME,50,1);
         double ATRPips = NormalizeDouble(ATRFast/getPip(), 2);
         if(ATRFast < ATRSlow || ATRFast < minATR) {
            return;
         } else {
   			// OVERWRITE INITIAL SETTING!
   			double delta = ATRPips/3;
   			double distance = delta*2;
            double TPPips = distance*rr;
            int k = distance + TPPips;
         }
         
			// SETUP FOR THE NEXT HEDGING ROUND!
			initPrice = Ask;
			double initBuy = calTP(true, initPrice, delta);
			double initSell = calTP(false, initPrice, delta);
			double buyTP = calTP(true, initBuy, TPPips);
			double sellTP = calTP(false, initSell, TPPips);
			double buySL = sellTP;
			double sellSL = buyTP;
			Print("New initPrice - Ask: ", initPrice);
			sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, initLot, initBuy, slippage, buySL, buyTP, "", EA_ID);
			sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, initLot, initSell, slippage, sellSL, sellTP, "", EA_ID);
		}
	}

	else {
		double initBuy = calTP(true, initPrice, delta);
		double initSell = calTP(false, initPrice, delta);
		double buyTP = calTP(true, initBuy, TPPips);
		double sellTP = calTP(false, initSell, TPPips);
		double buySL = sellTP;
		double sellSL = buyTP;
		
		// In case trigger first postion and still hanging the second position
		for(int i=0; i<OrdersTotal(); i++) {
			if(OrderSelect(i, SELECT_BY_POS) == true) {
				if(OrderType() == ORDER_TYPE_BUY_STOP || OrderType() == ORDER_TYPE_SELL_STOP) {
					if(OrderLots() == initLot) {
						bool delStt = OrderDelete(OrderTicket());
					}
				}
			}
		}
		
		// If there's no pending order, we need to prepare for the next reverse of the price by open an opposite order.
		int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
		if(pendingOrders == 0) {
			int signum = MathPow(-1, totalPos+1);
			int lastTicket = lastOpenedOrder(EA_ID);
			if(selectOrder(lastTicket, SELECT_BY_TICKET, MODE_TRADES)){
				int orderType = OrderType();
				Print("initPrice - Ask: ", initPrice);

				// Last order is BUY => Open SELL stop order
				if(orderType == ORDER_TYPE_BUY) {
					double lot = (sumLot(_Symbol, ORDER_TYPE_BUY)*(k + earnPerTrade))/TPPips 
									  - sumLot(_Symbol, ORDER_TYPE_SELL);
					lot = NormalizeDouble(lot, 2);
					int orderID = sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, lot, initSell, slippage, sellSL, sellTP, "", EA_ID);
				}
				
				// Last order is SELL => Open BUY stop order
				else if(orderType == ORDER_TYPE_SELL) {
					double lot = (sumLot(_Symbol, ORDER_TYPE_SELL)*(k + earnPerTrade))/TPPips 
									  - sumLot(_Symbol, ORDER_TYPE_BUY);
					lot = NormalizeDouble(lot, 2);
					int orderID = sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, lot, initBuy, slippage, buySL, buyTP, "", EA_ID);
				}
			}
		}
	}
}
//+------------------------------------------------------------------+



void closeOldPendingOrders() {
	// In case trigger first postion and still hanging the second position
	for(int i=0; i<OrdersTotal(); i++) {
		if(OrderSelect(i, SELECT_BY_POS) == true) {
			if(OrderType() == ORDER_TYPE_BUY_STOP || OrderType() == ORDER_TYPE_SELL_STOP) {
				if(OrderType() == ORDER_TYPE_BUY_STOP && Ask < OrderStopLoss()) {
					bool delStt = OrderDelete(OrderTicket());
				} 
				else if (OrderType() == ORDER_TYPE_SELL_STOP && Bid > OrderStopLoss()) {
					bool delStt = OrderDelete(OrderTicket());
				}
			}
		}
	}
}