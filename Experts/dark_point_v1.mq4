//+------------------------------------------------------------------+
//|                                                dark_point_v1.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include custom modules                                           |
//+------------------------------------------------------------------+
#include <common/utils.mqh>;
#include <models/account.mqh>;


//+------------------------------------------------------------------+
//| Input EA                                                         |
//+------------------------------------------------------------------+
input double riskLevel = 0.05;
input int maxPos = 1; //Max Position
input int slippage = 10;
input long magicNumber = 2222; //EA Id
input ENUM_TIMEFRAMES TIME_FRAME = PERIOD_H1;

int ticket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   // SIMPLE VERSION - ONLY ONE SL1 - TP1
   
   // Get previous signal
   int totalPos = countPosition(magicNumber);   
   if(totalPos < maxPos) {
      // Get last trend lines
      ENUM_OBJECT objType = OBJ_TEXT;

      // Collect new signal
      double TP1 = 0;
      double SL1 = 0;
      Alert("============================================");
      Alert("Total objects: ", ObjectsTotal(0, 0, objType));
      for(int i=0; i<ObjectsTotal(0, 0, objType); i++) {
         string objName = ObjectName(ChartID(), i, 0, objType);
         string strTime = StringSubstr(objName, 12, 11);
         datetime createTime = StrToInteger(strTime);
         datetime curTime = TimeCurrent();
         datetime prevTime = curTime - (datetime) 2*PeriodSeconds(TIME_FRAME);
         Alert(objName, " - createTime: ", createTime, " - curTime: ", curTime);
         if(prevTime < createTime && createTime < TimeCurrent()) {
            string descr = ObjectDescription(objName);
            double createPrice = ObjectGet(objName, OBJPROP_PRICE1);
            if (descr == "TP 1") {
               Alert("Detect TP1: ", TP1);
               TP1 = createPrice;
            } else if (descr == "SL 1") {
               Alert("Detect SL1: ", SL1);
               SL1 = createPrice;
            }
         }
      }

      //MyAccount account("Nguyen", "Vo", magicNumber);
      //lotSize = calcLot(account.info.BALANCE, riskLevel, SLPips);

      if (TP1 > 0 && SL1 > 0) {
         double lotSize = 0.1;
         if (TP1 > SL1) {
            if (SL1 > Ask) {
               SL1 = calSL(true, Ask, 50);
            }
            ticket = sendOrder(Symbol(), OP_BUY, lotSize, Ask, slippage, SL1, TP1, "Dark Point BUY", magicNumber);
         } else if (TP1 < SL1) {
            if (SL1 < Bid) {
               SL1 = calSL(false, Bid, 50);
            }
            ticket = sendOrder(Symbol(), OP_SELL, lotSize, Bid, slippage, SL1, TP1, "Dark Point SELL", magicNumber);
         }
      }
   }
  }
//+------------------------------------------------------------------+
