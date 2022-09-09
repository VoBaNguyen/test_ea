//+------------------------------------------------------------------+
//|                                                 test_keltner.mq4 |
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
void OnStart() {
   // Get last trend lines
   Alert("===========================================");
   ENUM_OBJECT objType = OBJ_TREND;
   double lastTime = 0;
   double lastPrice = 0;
   for(int i=0; i<ObjectsTotal(0, 0, objType); i++) {
      string objName = ObjectName(ChartID(), i, 0, objType);
      double createTime = ObjectGet(objName, OBJPROP_CREATETIME);
      double openPrice = ObjectGet(objName, OBJPROP_PRICE1);
      lastTime = MathMax(lastTime, createTime);
      if(lastTime == createTime) {
         lastPrice = openPrice;
      }
   }
   for(int i=0; i<ObjectsTotal(0, 0, objType); i++) {
      string objName = ObjectName(ChartID(), i, 0, objType);
      datetime createTime = ObjectGet(objName, OBJPROP_CREATETIME);
      double openPrice = ObjectGet(objName, OBJPROP_PRICE1);
      if(lastTime == createTime) {
         Alert(i, ". lastTime: ", lastTime, "- createTime: ", createTime);
         Alert(i, ". Last openPrice: ", openPrice);
      }
   }
   
}