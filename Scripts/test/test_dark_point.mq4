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
void OnStart()
  {
//---

   double darkPoint[30];

   // Collect data
   //for(int lineIdx=0; lineIdx<30; lineIdx++) {
   //   Alert("========== Line index: ", lineIdx, " =============");
   //   for(int i=0; i<ArraySize(darkPoint); i++) {
   //      darkPoint[i] = iCustom(Symbol(), PERIOD_CURRENT,"Dark Point",50,lineIdx,i);
   //      Alert(i, " - Line index: ", lineIdx, " - darkPoint: ", darkPoint[i]);
   //   }
   //}
   
   
   //Alert(ObjectsTotal(OBJ_TREND));

   Alert(ChartSymbol(ChartID()), " - ", Period());

   Alert("Total: ", ObjectsTotal(0, 0, -1));
   // Alert("Name: ", ChartIndicatorName(ChartID(), 0, 0));
   Alert("#Idc: ", ChartIndicatorsTotal(ChartID(), 0));
   Alert("============================");
   ///////////////////////////////
   Alert("OBJ_TREND: ", ObjectsTotal(ChartID(), 0, OBJ_TREND));
   Alert("OBJ_ARROW: ", ObjectsTotal(ChartID(), 0, OBJ_ARROW));
   Alert("OBJ_TEXT: ", ObjectsTotal(ChartID(), 0, OBJ_TEXT));
   Alert("OBJ_LABEL: ", ObjectsTotal(ChartID(), 0, OBJ_LABEL));

   ENUM_OBJECT objType = OBJ_TEXT;
   
   for ( int i=0; i<ObjectsTotal(0, 0, objType); i++ ) {
      Alert("==============================================");
      string objName = ObjectName(ChartID(), i, 0, objType);
      Alert("Name: ", objName);
      string strTime = StringSubstr(objName, 12, 11);
      datetime createTime = StrToInteger(strTime);
      Alert("createTime: ", createTime);
      Alert("OBJPROP_CREATETIME: ", (datetime) ObjectGet(objName, OBJPROP_CREATETIME));
      Alert("Description: ", ObjectDescription(objName));
      //Alert("Tooltip: ", ObjectGetString(ChartID(),objName,OBJPROP_TOOLTIP));
      //Alert("OBJPROP_TIME1: ", (datetime) ObjectGet(objName, OBJPROP_TIME1));
      //Alert("OBJPROP_TIME2: ", (datetime) ObjectGet(objName, OBJPROP_TIME2));
      //Alert("OBJPROP_TIME3: ", (datetime) ObjectGet(objName, OBJPROP_TIME3));
      //Alert("OBJPROP_PRICE1: ", ObjectGet(objName, OBJPROP_PRICE1));
      //Alert("OBJPROP_PRICE2: ", ObjectGet(objName, OBJPROP_PRICE2));
      //Alert("OBJPROP_PRICE3: ", ObjectGet(objName, OBJPROP_PRICE3));
      //ObjectSet(objName, OBJPROP_SELECTABLE, true);
   }
  }
//+------------------------------------------------------------------+

//string getLastSignal() {
//   ENUM_OBJECT objType = OBJ_ARROW;
//   for ( int i=0; i<ObjectsTotal(0, 0, objType); i++ ) {
//      Alert("==============================================");
//      string objName = ObjectName(ChartID(), i, 0, objType);
//      Alert("Name: ", objName);
//      Alert("Time: ", ObjectGet(objName, OBJPROP_CREATETIME));
//      Alert("Description: ", ObjectDescription(objName));
//      Alert("Tooltip: ", ObjectGetString(ChartID(),objName,OBJPROP_TOOLTIP));
//      Alert("OBJPROP_TIME1: ", ObjectGet(objName, OBJPROP_TIME1));
//      Alert("OBJPROP_TIME2: ", ObjectGet(objName, OBJPROP_TIME2));
//      Alert("OBJPROP_TIME3: ", ObjectGet(objName, OBJPROP_TIME3));
//      Alert("OBJPROP_PRICE1: ", ObjectGet(objName, OBJPROP_PRICE1));
//      Alert("OBJPROP_PRICE2: ", ObjectGet(objName, OBJPROP_PRICE2));
//      Alert("OBJPROP_PRICE3: ", ObjectGet(objName, OBJPROP_PRICE3));
//   }
//}