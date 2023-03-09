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
input double initLot      = 0.02;   // Initial Lot Size
input double rr           = 1;      // Reward/Risk
input ENUM_HOUR startHighFluctuate = h08p5;   // Start London sesison/NY session
input ENUM_HOUR endHighFluctuate   = h21p5;   // End London sesison/NY session
input double ATRMultiplier = 1.5;   // ATR Multiplier in high fluctuate sessions

// Calculate default setting
string firstTrade;
double initPrice;
double distance;
double TPPips;
double SLPips;
double k;

MyAccount account = MyAccount("nguyen", "vo", EA_ID);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
	Print("Init hedging_v1 strategy");
   firstTrade = "None";
   initPrice = 0;
   distance = minDistance;
   TPPips = distance*rr;
   SLPips = distance*(1+rr);
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
		closeOldPendingOrders();   
	   firstTrade = "None";
      initPrice = 0;
      
	   // Check ATR > Distance between BUY & SELL orders
      double ATR = iATR(Symbol(),TIME_FRAME,20,1);
      double RSI = iRSI(Symbol(), TIME_FRAME, 14, PRICE_CLOSE, 0);
      double ATRPips = NormalizeDouble(ATR/getPip(), Digits);
      
      PrintFormat("ATR: %.2f - ATR pips: %.2f", ATR, ATRPips);
		if(checkActiveHours(startHighFluctuate, endHighFluctuate)) {
			ATRPips = ATRPips*ATRMultiplier;
		}
      
		// OVERWRITE INITIAL SETTING!
		distance = MathMax(minDistance, ATRPips);
      TPPips = distance*rr;
      SLPips = distance*(1+rr);

		// Send a market order
		if(RSI >= 50) {
		   // RSI >= 50 => BUY => Entry = initBuy
		   firstTrade = ORDER_TYPE_BUY;
		   initPrice = Ask;
		   sendOrder(Symbol(), ORDER_TYPE_BUY, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
		}
		else if(RSI < 50) {
		   // RSI < 50 => SELL => Entry = initSell
		   firstTrade = ORDER_TYPE_SELL;
		   initPrice = Bid;
		   sendOrder(Symbol(), ORDER_TYPE_SELL, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
		}
		else {
		   Print("Something wrong  with RSI value");
		}
	}

	else {
	   if(firstTrade == "None" || initPrice == 0) {
	      Print("Setup not correct - Mode: ", firstTrade, " - Init price: ", initPrice);
	      return;
	   }
		
		int pendingOrders = countPosition(EA_ID, ORDER_TYPE_BUY_STOP) + countPosition(EA_ID, ORDER_TYPE_SELL_STOP);
		if(pendingOrders == 0) {
		   // If there's no pending order, we need to prepare for the next reverse of the price by open an opposite order.
		   // Modify SL/TP and send new pending order.
   		// Suppose firstTrade is BUY.
   		double initBuy = initPrice;
   		double initSell = calSL(true, initPrice, distance);
   	   if(firstTrade == ORDER_TYPE_SELL) {
   	      double initSell = initPrice;
      		double initBuy = calSL(false, initPrice, distance);
   	   }
    
   		double buyTP = calTP(true, initBuy, TPPips);
   		double sellTP = calTP(false, initSell, TPPips);
   		double buySL = sellTP;
   		double sellSL = buyTP;
   		
   		PrintFormat("distance: %.2f - initBuy: %.2f - initSell: %.2f - buyTP: %.2f - sellTP: %.2f", distance, initBuy, initSell, buyTP, sellTP);
   		
   		// Modify SL/TP of the first trade
   		if(totalPos == 1) {	
   			int lastTicket = lastOpenedOrder(EA_ID);
  			   OrderSelect(lastTicket, SELECT_BY_TICKET, MODE_TRADES);
			   initPrice = OrderOpenPrice();
            if(firstTrade == ORDER_TYPE_BUY) {
   			   modifyOrder(lastTicket, OrderOpenPrice(), buySL, buyTP, 0);
            }
            else if(firstTrade == ORDER_TYPE_SELL) {
   			   modifyOrder(lastTicket, OrderOpenPrice(), sellSL, sellTP, 0);
            }
		   }
		   
			int signum = MathPow(-1, totalPos+1);
			int lastTicket = lastOpenedOrder(EA_ID);
			if(selectOrder(lastTicket, SELECT_BY_TICKET, MODE_TRADES)){
				int lastOrdType = OrderType();
				Print("initPrice - Ask: ", initPrice);

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