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
input ENUM_HOUR startHour = h00; // Start operation hour
input ENUM_HOUR lastHour  = h23; // Last operation hour
input int margin     = 10;        // Least earn per trade
input int delta   = 10;        // Distance between BUY/SELL vs Entry
input double initLot = 0.1;      // Initial Lot Size
input int SLPips     = 20;       // Stoploss Pips
input int TPPips     = 60;       // Takeprofit Pips

// Calculate default setting
int k = SLPips + TPPips;
double initPrice = 0;

//+------------------------------------------------------------------+
//| Setup Keltner                                                    |
//+------------------------------------------------------------------+

double   bufMA1[4], 
         keltnerUp[4], 
         keltnerMid[4], 
         keltnerLow[4],
         priceClose[4], 
int arrSize = 4;
int periodMA1 = 10;
int periodLKN = 50;
input double thresholdKN = 0.0; // Trend delta
input double thresholdMA = 0.25; // Trend delta





//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Alert("Init Kelter MA Hedging scalping strategy");
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
		// Check active hours
		if(!checkActiveHours(startHour, lastHour)) {
			return;
		}
	
		// Close pending order from previous setup hedging.
		closeOldPendingOrders();
		
		if(pendingOrders == 0) {
		
		   // Check Kelter MA signal - If yes - Open new order
	      double results[2];   
         results[0] = -1;
         results[1] = -1;
		
		   checkKeltnerMASignal(bufMA1, bufMA2, keltnerUp, keltnerMid, keltnerLow, priceClose, 
		                        TIME_FRAME, arrSize, periodLKN, periodMA1, results);
		
		   if(results[0] != -1) {
   			// SETUP FOR THE NEXT HEDGING ROUND!
   			initPrice = results[1];
   			double initBuy = calTP(true, initPrice, delta);
   			double initSell = calTP(false, initPrice, delta);
   			double buyTP = calTP(true, initBuy, TPPips);
   			double sellTP = calTP(false, initSell, TPPips);
   			double buySL = sellTP;
   			double sellSL = buyTP;
   			Print("New initPrice - Ask: ", initPrice);
   			if(results[0] == 0) {
   			   sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, initLot, initBuy, slippage, buySL, buyTP, "", EA_ID);
   			} else if(results[0] == 1) {
   			   sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, initLot, initSell, slippage, sellSL, sellTP, "", EA_ID);
   			}
   	   }
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
					double lot = (sumLot(_Symbol, ORDER_TYPE_BUY)*(k + margin))/TPPips 
									  - sumLot(_Symbol, ORDER_TYPE_SELL);
					lot = NormalizeDouble(lot, 2);
					int orderID = sendOrder(_Symbol, ORDER_TYPE_SELL_STOP, lot, initSell, slippage, sellSL, sellTP, "", EA_ID);
				}
				
				// Last order is SELL => Open BUY stop order
				else if(orderType == ORDER_TYPE_SELL) {
					double lot = (sumLot(_Symbol, ORDER_TYPE_SELL)*(k + margin))/TPPips 
									  - sumLot(_Symbol, ORDER_TYPE_BUY);
					lot = NormalizeDouble(lot, 2);
					int orderID = sendOrder(_Symbol, ORDER_TYPE_BUY_STOP, lot, initBuy, slippage, buySL, buyTP, "", EA_ID);
				}
			}
		}
	}
}
//+------------------------------------------------------------------+


void checkKeltnerMASignal(double& _bufMA1[], double& _bufMA2[], 
                        double& _keltnerUp[], double& _keltnerMid[], double& _keltnerLow[],
                        double& _priceClose[], ENUM_TIMEFRAMES TIME_FRAME, 
                        int _arrSize, int _periodLKN, int _periodMA1, double& results[]) {
   // Collect data   
   for(int i=1; i<_arrSize+1; i++) {
      _bufMA1[i-1]     = iMA(Symbol(),TIME_FRAME,_periodMA1,0,MODE_SMA,PRICE_CLOSE,i);
      _keltnerUp[i-1]  = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",_periodLKN,0,i);
      _keltnerMid[i-1] = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",_periodLKN,1,i);
      _keltnerLow[i-1] = iCustom(Symbol(),TIME_FRAME,"Keltner_Channel",_periodLKN,2,i);
   }
   
   CopyClose(Symbol(), TIME_FRAME, 0, _arrSize, _priceClose);
   
   // Last price
   int shift = 0;
   double upKN  = NormalizeDouble(_keltnerUp[shift], _Digits);
   double midKN = NormalizeDouble(_keltnerMid[shift], _Digits);
   double lowKN = NormalizeDouble(_keltnerLow[shift], _Digits);
   double close = NormalizeDouble(_priceClose[shift], _Digits);

   // Signal
   bool isMA1Upward   = idcUpward(_bufMA1, thresholdMA);   
   bool isMA1Downward = idcDownward(_bufMA1, thresholdMA);
   bool isKNUpward    = idcUpward(_keltnerMid, thresholdKN);
   bool isKNDownward  = idcDownward(_keltnerMid, thresholdKN);

   // BUY
   if(isMA1Upward && close > upKN) {
      results[0] = 0;
      results[1] = Ask;
   }
   
   // SELL
   if(isMA1Downward && close < lowKN) {
      results[0] = 1;
      results[1] = Bid;
   }
}



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