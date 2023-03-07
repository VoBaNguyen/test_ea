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
input int slippage = 3;
input long EA_ID = 7777; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_M15;
input ENUM_HOUR startHour = h00;  // Start operation hour
input ENUM_HOUR lastHour  = h23;  // Last operation hour
input int earnPerTrade    = 10;    // Least earn per trade (pips)
input double minATR       = 2;    // Min ATR
input double initLot      = 0.02; // Initial Lot Size
input double rr           = 1;    // Reward/Risk

// Calculate default setting
string mode = "None";
double initPrice = 0;
double distance = NormalizeDouble(minATR/getPip(), Digits);
double TPPips = distance*rr;
double SLPips = distance*(1+rr);
double k = distance*(1+rr);

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
         double ATR = iATR(Symbol(),TIME_FRAME,10,1);
         double RSI = iRSI(Symbol(), TIME_FRAME, 14, PRICE_CLOSE, 0);
         double ATRPips = NormalizeDouble(ATR/getPip(), Digits);
         /* if(ATR < minATR) {
            return;
         } */
         
			// OVERWRITE INITIAL SETTING!
			double distance = ATRPips;
         double TPPips = distance*rr;
         double SLPips = distance*(1+rr);
         double k = distance + TPPips;

			// Send a market order
			if(RSI >= 50) {
			   // RSI >= 50 => BUY => Entry = initBuy
			   mode = OP_BUY;
			   initPrice = Ask;
			   sendOrder(Symbol(), OP_BUY, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
			} 
			else if(RSI < 50) {
			   // RSI < 50 => SELL => Entry = initSell
			   mode = OP_SELL;
			   initPrice = Bid;
			   sendOrder(Symbol(), OP_SELL, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
			} 
			else {
			   Print("Something wrong  with RSI value");
			}
		}
	}

	else {
      
	   if(mode == "None" || initPrice == 0) {
	      Print("Setup not correct - Mode: ", mode, " - Init price: ", initPrice);
	      return;
	   }
		
		// If there's no pending order, we need to prepare for the next reverse of the price by open an opposite order.
		int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
		if(pendingOrders == 0) {
		
		
		   // Modify SL/TP and send new pending order
		   
		   
   		// Suppose mode is BUY
   		double initBuy = initPrice;
   		double initSell = calTP(false, initPrice, distance);
   	   if(mode == OP_SELL) {
      		double initBuy = calTP(true, initPrice, distance);
      		double initSell = initPrice;
   	   }
   
   		double buyTP = calTP(true, initBuy, TPPips);
   		double sellTP = calTP(false, initSell, TPPips);
   		double buySL = sellTP;
   		double sellSL = buyTP;
   		
   		// 
   		if(totalPos == 1) {	
   			int lastTicket = lastOpenedOrder(EA_ID);
  			   OrderSelect(lastTicket, SELECT_BY_TICKET, MODE_TRADES);
			   initPrice = OrderOpenPrice();
            if(mode == OP_BUY) {
   			   double buyTP = calTP(true, initPrice, TPPips);
   			   double buySL = calSL(true, initPrice, SLPips);
   			   modifyOrder(lastTicket, OrderOpenPrice(), buySL, buyTP, 0);
            }
            else if(mode == OP_SELL) {
   			   double sellTP = calTP(False, initPrice, TPPips);
   			   double sellSL = calSL(False, initPrice, SLPips);
   			   modifyOrder(lastTicket, OrderOpenPrice(), sellSL, sellTP, 0);
            }
		   }
		   
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