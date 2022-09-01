//+------------------------------------------------------------------+
//|                                                   test_order.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   //Alert("Total: ", OrdersTotal());
   //for(int i=0; i<OrdersTotal(); i++) {
   //   OrderSelect(i, SELECT_BY_POS);
   //   Alert(i, ": ", OrderOpenTime());
   //}
   
  // retrieving info from trade history
  int hstTotal=OrdersHistoryTotal();
  Alert("History: ", hstTotal);
  for(int i=0;i<hstTotal;i++){
     if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false){
        Print("Access to history failed with error (",GetLastError(),")");
        break;
      }
      Alert(i, " - ", OrderOpenPrice(), " - ", OrderOpenTime(), " - ", OrderCloseTime());
   }
   Alert(isDuplicateOrder(100));
   
   
  }
//+------------------------------------------------------------------+



bool isDuplicateOrder(long delaySeconds) {
   bool isDuplicate = false;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == true) {
         datetime openTime = OrderOpenTime();
         datetime limitTime = openTime + delaySeconds;
         if(TimeCurrent() < limitTime) {
            isDuplicate = true;
         }
      }
   }
   return isDuplicate;
}