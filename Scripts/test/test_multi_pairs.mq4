//+------------------------------------------------------------------+
//|                                                          jkh.mq4 |
//|                      Copyright © 2009, MetaQuotes Software Corp. |
//|                                        http://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, MetaQuotes Software Corp."
#property link      "http://www.metaquotes.net"

bool wannaBuy = true;
bool wannaBuy1 = true;
extern double LotSize = 0.01;
extern string symbol1 = "EURUSD";
extern string symbol2 = "USDCHF";
extern int MaxDifference = 6;
extern int Slippage = 3;
extern int Magicnumber1 = 786;
extern int Magicnumber2 = 123;
int sendticket = 3;
string pairs[18];

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
pairs[0] = symbol1;
pairs[1] = symbol2;
wannaBuy = true;
wannaBuy1 = true;

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
   // Send order for EURUSD & USDCHF
   if (wannaBuy) {   
   int ticket1;
   RefreshRates();
   ticket1 = OrderSend(symbol1, OP_BUY, LotSize, MarketInfo(symbol1,MODE_ASK), Slippage, 0, 0, 0,0,Magicnumber1,0) & OrderSend(symbol2, OP_BUY, LotSize, MarketInfo(symbol2,MODE_ASK), Slippage, 0, 0, 0,0,Magicnumber2,0);
   if (ticket1 <0 )
   {
   Print ("OrderSend failed with error #", GetLastError());
   return(0);
   }
   wannaBuy = false;
   }

//----
   return(0);
  }
//+------------------------------------------------------------------+