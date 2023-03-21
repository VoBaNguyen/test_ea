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
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_CURRENT;
input int earnPerTrade    = 5;     // Least earn per trade (pips)
input double minDistance  = 20;     // Min distance between BUY/SELL (pips)
input double initLot      = 0.01;   // Initial Lot Size
input double rr           = 1;      // Reward/Risk
input ENUM_HOUR startHighFluctuate = h08p5;   // Start London sesison/NY session
input ENUM_HOUR endHighFluctuate   = h21p5;   // End London sesison/NY session
input double ATRMultiplier = 1.5;   // High Fluctuate Multiplier in high fluctuate sessions
input int ATRPeriod = 20;           // ATR Period

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
	MyAccount account("Nguyen", "Vo", EA_ID);
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
	   tradeMode = "None";
      initPrice = 0;
		closeOldPendingOrders();   

      // Last price
      double upKN  = iCustom(NULL,TIME_FRAME,"Keltner_Channel",50,0,1);
      double lowKN = iCustom(NULL,TIME_FRAME,"Keltner_Channel",50,2,1);
      double close = iClose(Symbol(),TIME_FRAME,1);
      double open  = iOpen(Symbol(),TIME_FRAME,1);
      
      double ATR = iATR(Symbol(),TIME_FRAME,ATRPeriod,1);
      double ATRPips = NormalizeDouble(ATR/(Point()*100), Digits);    
		if(checkActiveHours(startHighFluctuate, endHighFluctuate)) {
			ATRPips = ATRPips*ATRMultiplier;
		}
		
		// OVERWRITE INITIAL SETTING!
		distance = MathMax(minDistance, ATRPips);
      TPPips = distance*rr;
      SLPips = distance*(1+rr);
		
      // BUY
      if (close > upKN) {
		   tradeMode = ORDER_TYPE_BUY;
		   initPrice = Ask;
		   sendOrder(Symbol(), ORDER_TYPE_BUY, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
      }
      
      // SELL
      if(close < lowKN) {
		   tradeMode = ORDER_TYPE_SELL;
		   initPrice = Bid;
		   int orderID = sendOrder(Symbol(), ORDER_TYPE_SELL, initLot, initPrice, slippage, 0, 0, "Open first order.", EA_ID);
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
		   
         calculateOrder(initPrice, tradeMode);
         Print("initPrice: ", initPrice);
         Print("initBuy: ", initBuy);
         Print("initSell: ", initSell);
         PrintFormat("distance: %.2f - TPPips: %.2f - SLPips: %.2f", distance, TPPips, SLPips);

   		// Modify SL/TP of the first trade
   		if(totalPos == 1) {	
   			int lastTicket = lastOpenedOrder(EA_ID);
  			   OrderSelect(lastTicket, SELECT_BY_TICKET, MODE_TRADES);
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


void closeOldPendingOrders() {
	// In case trigger first postion and still hanging the second position
	for(int i=0; i<OrdersTotal(); i++) {
		if(OrderSelect(i, SELECT_BY_POS) == true) {
			bool delStt = OrderDelete(OrderTicket());
		}
	}
}
