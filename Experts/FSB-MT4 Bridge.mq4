//+--------------------------------------------------------------------+
//| File name:  FSB-MT4 Bridge.mq4                                     |
//| Copyright:  © 2016, Miroslav Popov - All rights reserved!          |
//| Website:    http://forexsb.com/                                    |
//| Support:    http://forexsb.com/forum/                              |
//| License:    Freeware under the following circumstances:            |
//|                                                                    |
//| This code is a part of Forex Strategy Builder. It is free for      |
//| use and distribution as an integral part of Forex Strategy Builder.|
//| One can modify it in order to improve the code or to fit it for    |
//| personal use. This code or any part of it cannot be used in        |
//| another applications without a permission. Contact information     |
//| cannot be changed.                                                 |
//|                                                                    |
//| NO LIABILITY FOR CONSEQUENTIAL DAMAGES                             |
//|                                                                    |
//| In no event shall the author be liable for any damages whatsoever  |
//| (including, without limitation, incidental, direct, indirect and   |
//| consequential damages, damages for loss of business profits,       |
//| business interruption, loss of business information, or other      |
//| pecuniary loss) arising out of the use or inability to use this    |
//| product, even if advised of the possibility of such damages.       |
//+--------------------------------------------------------------------+
#include <WinUser32.mqh>

#property copyright "Copyright © 2016, Miroslav Popov"
#property link      "http://forexsb.com/"
#property strict

#define EXPERT_VERSION           "11" // 2015-09-16
#define SERVER_SEMA_NAME         "FSB-MT4 Bridge ID - "
#define TRADE_SEMA_NAME          "TradeIsBusy"
#define TRADE_SEMA_WAIT          100
#define TRADE_SEMA_TIMEOUT       10000
#define TRADE_RETRY_COUNT        4
#define TRADE_RETRY_WAIT         100

#define FSB_REQ_ACCOUNT_INFO     3
#define FSB_REQ_BARS             4
#define FSB_REQ_ORDER_SEND       7
#define FSB_REQ_ORDER_MODIFY     8
#define FSB_REQ_ORDER_CLOSE      9
#define FSB_REQ_PING             11
#define FSB_REQ_MARKET_INFO_ALL  12
#define FSB_REQ_TERMINAL_INFO    13
#define FSB_REQ_SET_LTF_META     14

#define FSB_ERR_INVALID_REQUEST  -1
#define FSB_ERR_WRONG_ORD_TYPE   -10005
#define FSB_ERR_POS_ALREADY_OPEN -10010
#define FSB_ERR_NO_OPEN_POSITION -10015

#define OP_FLAT                -1

#import "FSB-MT4 Bridge.dll"
string FSB_LibraryVersion();
void FSB_OpenConnection(int id);
void FSB_CloseConnection(int id);
void FSB_Ping(int id,string symbol,int period,int time,double bid,double ask,
   int spread,double tickval,double &rates[][6],int bars,
   double accountBalance,double accountEquity,double accountProfit,
   double accountFreeMargin,int positionTicket,
   int positionType,double positionLots,double positionOpenPrice,
   int positionOpenTime,double positionStopLoss,
   double positionTakeProfit,double positionProfit,
   string positionComment,string parameters);
int FSB_Tick(int id,string symbol,int period,int time,double bid,double ask,
   int spread,double tickval,double &rates[][6],int bars,
   double accountBalance,double accountEquity,double accountProfit,
   double accountFreeMargin,int positionTicket,
   int positionType,double positionLots,double positionOpenPrice,
   int positionOpenTime,double positionStopLoss,
   double positionTakeProfit,double positionProfit,
   string positionComment,string parameters);
void FSB_MarketInfoAll(int id,double point,double digits,double spread,
   double stoplevel,double lotsize,
   double tickvalue,double ticksize,double swaplong,
   double swapshort,double starting,double expiration,
   double tradeallowed,double minlot,double lotstep,
   double maxlot,double swaptype,double profitcalcmode,
   double margincalcmode,double margininit,
   double marginmaintenance,double marginhedged,
   double marginrequired,double freezelevel);
void FSB_AccountInfo(int id,string name,int number,string company,
   string server,string currency,int leverage,
   double balance,double equity,double profit,
   double credit,double margin,double freemarginmode,
   double freemargin,int stopoutmode,int stopout,int isdemo);
void FSB_TerminalInfo(int id,string symbol,string company,string path,
   string expertversion);
void FSB_Bars(int id,string symbol,int period,double &rates[][6],int bars);
int  FSB_Request(int id,string &symbol,int &iargs[],int icount,
   double &dargs[],int dcount,string &param);
void FSB_Response(int id,int ok,int code);
#import

// -----------------------    External variables   ----------------------- //

// Connection_ID serves to identify the expert when multiple copies
// of Forex Strategy Builder are used.
// It must be a unique number between 0 and 1000.
// The same number has to be entered in Forex Strategy Builder.
extern int Connection_ID=0; // Connection ID

// If account equity drops below this value, the expert will close out
// all positions and stop automatic trade.
// The value must be set in account currency. Example:
// Protection_Min_Account = 700 will close positions if the equity drops
// below 700 USD (EUR if you account is in EUR).
extern int Protection_Min_Account=0; // Stop trading at Min Account

// The expert checks the open positions at every tick and if found no
// SL or SL lower (higher for short) than selected,
// It sets SL to the defined value. The value is in points. Example:
// Protection_Max_StopLoss = 200 means 200 pips for 4 digit broker
// and 20 pips for 5 digit broker.
extern int Protection_Max_StopLoss=0; // Ensure maximum Stop Loss

// A unique number of the expert's orders.
extern int Expert_Magic=20011023;  // Expert Magic Number

// Expert writes a log file when Write_Log_File = true.
extern bool Write_Log_File=true;  // Write Log File

// ----------------------------    Options   ---------------------------- //

// Have to be set to true for STP brokers that cannot set SL and TP together
// with the position (with OrderSend()).
// When Separate_SL_TP = true, the expert first opens the position and after
// that sets StopLoss and TakeProfit.
bool Separate_SL_TP=false;

// TrailingStop_Moving_Step determines the step of changing the Trailing Stop.
// 0 <= TrailingStop_Moving_Step <= 2000
// If TrailingStop_Moving_Step = 0, the Trailing Stop trails at every new
// extreme price in the position's direction.
// If TrailingStop_Moving_Step > 0, the Trailing Stop moves at steps equal
// to the number of points chosen.
int TrailingStop_Moving_Step=10;

// FIFO (First In First Out) forces the expert to close positions starting
// from the oldest one. This rule complies with the new NFA regulations.
// If you want to close the positions from the newest one (FILO), change
// the variable to "false".
// This doesn't change the normal work of Forex Strategy Builder.
bool FIFO_order=true;

int MaxLogLinesInFile=2000;
const double Epsilon=0.000001;

// --------------------------------------------------------------------- //

bool     IsServer         = false;
bool     ConnectedToDLL   = false;
int      LastError        = 0;
bool     FSB_Connected    = false;
datetime TimeLastPing     = 0;
double   PipsValue        = 0;
int      PipsPoint        = 0;
int      StopLevel        = 0;

// Aggregate position.
int      PositionTicket      = 0;
int      PositionType        = OP_FLAT;
datetime PositionTime        = D'2050.01.01 00:00';
double   PositionLots        = 0;
double   PositionOpenPrice   = 0;
double   PositionStopLoss    = 0;
double   PositionTakeProfit  = 0;
double   PositionProfit      = 0;
double   PositionCommission  = 0;
string   PositionComment     = "";
int      ConsecutiveLosses   = 0;
double   ActivatedStopLoss   = 0;
double   ActivatedTakeProfit = 0;
double   ClosedSLTPLots      = 0;

// Set by Forex Strategy Builder
string Request      = "";
int    TrailingStop = 0;
string TrailingMode = "";
int    BreakEven    = 0;

datetime barHighTime    = 0;
datetime barLowTime     = 0;
double   currentBarHigh = 0;
double   currentBarLow  = 1000000;
int      logLines       = 0;

string ltfSymbols[];
int    ltfPeriods[];
int    ltfLength=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int init()
  {
   string message="FSB-MT4 Bridge version "+EXPERT_VERSION+
                     " loaded. Started an environment test...";
   Comment(message);
   Print(message);

// Checks the requirements.
   bool isEnvironmentGood=CheckEnvironment();

   if(!isEnvironmentGood)
     {   // There is a non fulfilled condition, therefore we must exit.
      Sleep(20*1000);
      PostMessageA(WindowHandle(Symbol(),Period()),WM_COMMAND,33050,0);

      return (-1);
     }

   message="The environment test was accomplished successfully.";
   Comment(message);
   Print(message);

   if(Write_Log_File)
     {
      CreateLogFile(GetLogFileName());
      WriteLogLine("FSB-MT4 Bridge version "+EXPERT_VERSION+" Loaded.");
      WriteLogLine("Connection_ID="              +IntegerToString(Connection_ID)+
                   ", Protection_Min_Account="   +IntegerToString(Protection_Min_Account)+
                   ", Protection_Max_StopLoss="  +IntegerToString(Protection_Max_StopLoss)+
                   ", Expert_Magic="             +IntegerToString(Expert_Magic)+
                   ", Separate_SL_TP="           +IntegerToString(Separate_SL_TP)+
                   ", Write_Log_File="           +IntegerToString(Write_Log_File)+
                   ", TrailingStop_Moving_Step=" +IntegerToString(TrailingStop_Moving_Step)+
                   ", FIFO_order="               +IntegerToString(FIFO_order));
      FlushLogFile();
     }

   ReleaseTradeContext();

   Server(); // It's OK. We start the server.

   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
// We don't have to do anything here.
// The new incoming ticks are processed by the server.

   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int deinit()
  {
   if(Write_Log_File)
      CloseLogFile();

   Comment("");
   if(ConnectedToDLL)
      FSB_CloseConnection(Connection_ID);

// Releases the global variable so the Expert
// can be started on another chart.
   ReleaseServerSema();

   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckEnvironment()
  {
   string message;

// Checks if DLL is allowed.
   if(IsDllsAllowed()==false)
     {
      message="\n"+
               "DLL call is not allowed."+"\n"+
               "Please allow DLL loading in the MT options and restart the expert.";
      Comment(message);
      Print(message);
      return (false);
     }

// Checks the FSB-MT4 Bridge.dll version
   message="\n"+
            "Cannot load \"FSB-MT4 Bridge.dll\"."+"\n"+
            "Please find more information about this error in the support forum.";
   Comment(message);
   string libraryVersion=FSB_LibraryVersion();
   if(libraryVersion!="")
     {
      message="FSB-MT4 Bridge.dll version "+libraryVersion+" loaded successfully.";
      Comment(message);
      Print(message);
     }
   else
     {   // MetaTrader stops if it cannot load the dll.
      // Error 126 is displayed.
      return (false);
     }

// Checks if you are logged in.
   if(AccountNumber()==0)
     {
      message="\n"+"You are not logged in. Please login first.";
      Comment(message);
      for(int attempt=0; attempt<200; attempt++)
        {
         if(AccountNumber()==0)
            Sleep(300);
         else
            break;
        }
      if(AccountNumber()==0)
         return (false);
     }

// Checks the amount of bars available.
   int barsNecessary=300;
   if(!CheckChartBarsCount(Symbol(),Period(),barsNecessary))
     {
      message="\n"+
        "Cannot load enough bars! The expert needs minimum "+
        IntegerToString(barsNecessary)+" bars for this time frame."+"\n"+
        "Please load more data in the chart window and restart the expert.";
      Comment(message);
      Print(message);
      return (false);
     }

// Checks the open positions.
   if(SetAggregatePosition()==-1)
     {   // Some error with the current positions.
      return (false);
     }

// Checks whether the expert was started on another chart.
   IsServer=GetServerSema();
   if(!IsServer)
     {
      string expert="FSB-MT4 Bridge ";
      if(Connection_ID>0)
         expert="FSB-MT4 Bridge ID = "+IntegerToString(Connection_ID)+" ";

      message="\n"+expert+"is already running on another chart!"+"\n"+
        "Please stop all the instances and restart the expert."+"\n"+"\n"+
        "If you cannot find the expert on the other charts, "+"\n"+
        "open the \"Global Variables\" window of MetaTrader (short key F3) and "+"\n"+
        "delete the FSB-MT4 Bridge ID - X variable. Restart the expert after that."+"\n"+"\n"+
        "If you want to use the expert on several charts, you have to set a unique Connection_ID for "+"\n"+
        "all the experts and to do the same in FSB. (The option must be switched on from Tools menu).";
      Comment(message);
      Print(message);
      return (false);
     }

   FSB_OpenConnection(Connection_ID);
   ConnectedToDLL=true;

   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CloseExpert()
  {
   PostMessageA(WindowHandle(_Symbol,_Period),WM_COMMAND,33050,0);
   deinit();

   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Server()
  {
   string expertID="";
   if(Connection_ID>0)
      expertID="(ID = "+IntegerToString(Connection_ID)+") ";
   datetime tickTime=(datetime) MarketInfo(_Symbol,MODE_TIME);
   datetime barTime = Time[0];
   string message=expertID+TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
                     " Forex Strategy Builder is disconnected.";
   Comment(message);

   int marketDigits=(int) MarketInfo(_Symbol,MODE_DIGITS);
   if(marketDigits == 2|| marketDigits == 3)
      PipsValue=0.01;
   else if(marketDigits==4 || marketDigits==5)
      PipsValue=0.0001;
   else
      PipsValue=marketDigits;

   if(marketDigits==3 || marketDigits==5)
      PipsPoint=10;
   else
      PipsPoint=1;

   StopLevel=(int) MarketInfo(_Symbol,MODE_STOPLEVEL)+PipsPoint;
   if(StopLevel<3*PipsPoint)
      StopLevel=3*PipsPoint;

   if(Protection_Max_StopLoss>0 && Protection_Max_StopLoss<StopLevel)
      Protection_Max_StopLoss=StopLevel;

   if(TrailingStop_Moving_Step<PipsPoint)
      TrailingStop_Moving_Step=PipsPoint;

   while(!IsStopped())
     {
      LastError=0;
      RefreshRates();

      // Checks if FSB is connected.
      if(FSB_Connected && (TimeLocal()-TimeLastPing>60))
        {
         FSB_Connected=false;
         message=expertID+TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
                  " Forex Strategy Builder is disconnected.";
         Comment(message);
        }

      bool     isSucceed=false;
      string   symbol=_Symbol;
      int      iargs[5];
      double   dargs[5];
      string   parameters="We have to arrange some space for the string!";
      datetime time=(datetime) MarketInfo(_Symbol,MODE_TIME);

      // Check for a new tick.
      if(time>tickTime)
        {
         tickTime=time;

         // Checks if minimum account was reached.
         if(Protection_Min_Account>0 && AccountEquity()<Protection_Min_Account)
            ClosePositionStopExpert();

         // Checks and sets Max SL protection.
         if(Protection_Max_StopLoss>0)
            SetMaxStopLoss();

         // Checks if position was closed. Refreshes AggregatePosition
         DetectSLTPActivation();

         if(BreakEven>0)
            SetBreakEvenStop();

         bool isNewBar=(barTime!=Time[0]);
         barTime=Time[0];

         if(TrailingStop>0)
            SetTrailingStop(isNewBar);

         if(isNewBar && Write_Log_File)
            WriteNewLogLine(AggregatePositionToString());

         int tickResponse=SendTick();
         CommentTickResponse(expertID,tickResponse);

         TimeLastPing=TimeLocal();
        }

      // Check for a request from Forex Strategy Builder.
      int request=FSB_Request(Connection_ID,symbol,iargs,5,dargs,5,parameters);

      if(request<0)
        {
         Comment("FSB-MT4 Bridge Server Error: ",request);
        }
      else if(request>0)
        {
         if(Write_Log_File)
           {   // Logs debug info
            string newRequest=symbol+
               " iargs[0]="+IntegerToString(iargs[0])+
               " iargs[1]="+IntegerToString(iargs[1])+
               " iargs[2]="+IntegerToString(iargs[2])+
               " iargs[3]="+IntegerToString(iargs[3])+
               " iargs[4]="+IntegerToString(iargs[4])+
               " dargs[0]="+DoubleToString(dargs[0],5)+
               " dargs[1]="+DoubleToString(dargs[1],5)+
               " dargs[2]="+DoubleToString(dargs[2],5)+
               " dargs[3]="+DoubleToString(dargs[3],5)+
               " dargs[4]="+DoubleToString(dargs[4],5)+
               " "+parameters;
            if(Request!=newRequest)
               Request=newRequest;
           }

         switch(request)
           {
            case FSB_REQ_PING:
               // Forex Strategy Builder sends a ping.
               GetPing();
               FSB_Connected = true;
               TimeLastPing  = TimeLocal();

               message=expertID+TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
                        " Forex Strategy Builder is connected.";
               Comment(message);
               break;

            case FSB_REQ_MARKET_INFO_ALL:
               // Forex Strategy Builder requests full market info.
               GetMarketInfoAll(symbol);
               break;

            case FSB_REQ_ACCOUNT_INFO:
               // Forex Strategy Builder requests full account info.
               FSB_AccountInfo(Connection_ID,AccountName(),AccountNumber(),
                   AccountCompany(),AccountServer(),AccountCurrency(),
                   AccountLeverage(),AccountBalance(),AccountEquity(),
                   AccountProfit(),AccountCredit(),AccountMargin(),
                   AccountFreeMarginMode(),AccountFreeMargin(),
                   AccountStopoutMode(),AccountStopoutLevel(),IsDemo() ? 1 : 0);
            break;

            case FSB_REQ_TERMINAL_INFO:
               // Forex Strategy Builder requests terminal info.
               FSB_TerminalInfo(Connection_ID,TerminalName(),TerminalCompany(),
                                TerminalPath(),EXPERT_VERSION);
               break;

            case FSB_REQ_BARS:
               // Forex Strategy Builder requests historical bars.
               GetBars(symbol,iargs[0],iargs[1]);
               break;

            case FSB_REQ_ORDER_SEND:
              {
               // Forex Strategy Builder sends an order.
               ParseOrderParameters(parameters);

               int orderResponse=ManageOrderSend(iargs[0],dargs[0],dargs[1],
                     iargs[1],dargs[2],dargs[3],"",Expert_Magic,iargs[3]);

               if(orderResponse<0)
                 {
                  int lastErrorOrdSend=GetLastError();
                  lastErrorOrdSend=lastErrorOrdSend>0 ? lastErrorOrdSend : LastError;
                  string requestOrderSendMessage="Error in FSB Request OrderSend: "+
                     GetErrorDescription(lastErrorOrdSend);
                  Print(requestOrderSendMessage);
                  if(Write_Log_File)
                     WriteLogLine(requestOrderSendMessage);

                  FSB_Response(Connection_ID,false,lastErrorOrdSend);
                 }
               else
                 {
                  FSB_Response(Connection_ID,true,orderResponse);
                 }
              }
            break;

            case FSB_REQ_ORDER_CLOSE:
              {
               // Forex Strategy Builder wants to close the current position.
               if(Write_Log_File)
                  WriteLogRequest("FSB Request: Close the current position.",Request);

               isSucceed=CloseCurrentPosition(iargs[1])==0;

               int lastErrorOrdClose=GetLastError();
               lastErrorOrdClose=(lastErrorOrdClose>0) ? lastErrorOrdClose : LastError;
               if(!isSucceed)
                 {
                  string requestOrderCloseMessage="Error in OrderClose: "+
                     GetErrorDescription(lastErrorOrdClose);
                  Print(requestOrderCloseMessage);
                  if(Write_Log_File)
                     WriteLogLine(requestOrderCloseMessage);
                 }

               FSB_Response(Connection_ID,isSucceed,lastErrorOrdClose);
              }
            break;

            case FSB_REQ_ORDER_MODIFY:
              {
               // Forex Strategy Builder wants to modify the current position.
               if(Write_Log_File)
                  WriteLogRequest("FSB Request: Modify the current position.",Request);
               ParseOrderParameters(parameters);
               isSucceed=ModifyPosition(dargs[1],dargs[2]);

               int lastErrorOrdModify=GetLastError();
               lastErrorOrdModify=lastErrorOrdModify>0 ? lastErrorOrdModify : LastError;
               if(!isSucceed)
                 {
                  string requestOrderModifyMessage="Error in OrderModify: "+
                     GetErrorDescription(lastErrorOrdModify);
                  Print(requestOrderModifyMessage);
                  if(Write_Log_File)
                     WriteLogLine(requestOrderModifyMessage);
                 }
               FSB_Response(Connection_ID,isSucceed,lastErrorOrdModify);
              }
            break;

            case FSB_REQ_SET_LTF_META:
               // Forex Strategy Builder wants to set required LTF (Longer Time Period) meta data.
               if(Write_Log_File)
                  WriteLogRequest("FSB Request: Set LTF meta data.",Request);

               SetLtfMetaData(parameters);

               FSB_Response(Connection_ID,true,0);
               break;

            default:
               // Forex Strategy Builder doesn't know what to do.
               FSB_Response(Connection_ID,false,FSB_ERR_INVALID_REQUEST);

               message=TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
                        " Error - Forex Strategy Builder sent a wrong request.";
               if(Write_Log_File)
                  WriteLogRequest("### FSB Request: WrongRequest.",message);
               Comment(message);
               Print(message);
               break;
           }
        }

      if(Write_Log_File)
        {
         if(logLines>=MaxLogLinesInFile)
           {
            CloseLogFile();
            CreateLogFile(GetLogFileName());
           }
         FlushLogFile();
        }

      Sleep(100);
     }

   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SetAggregatePosition()
  {
   PositionTicket     = 0;
   PositionType       = OP_FLAT;
   PositionTime       = D'2050.01.01 00:00';
   PositionLots       = 0;
   PositionOpenPrice  = 0;
   PositionStopLoss   = 0;
   PositionTakeProfit = 0;
   PositionProfit     = 0;
   PositionCommission = 0;
   PositionComment    = "";

   int positions=0;

   for(int i=0; i<OrdersTotal(); i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         Print("Error with OrderSelect: ",GetErrorDescription(GetLastError()));
         Comment("Cannot check current position!");
         continue;
        }

      if(OrderMagicNumber()!=Expert_Magic || OrderSymbol()!=_Symbol)
         continue; // An order not sent by Forex Strategy Builder.

      if(OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT ||
         OrderType()==OP_BUYSTOP || OrderType()==OP_SELLSTOP)
         continue; // A pending order.

      if(PositionType>=0 && PositionType!=OrderType())
        {
         string message="There are open positions in different directions!";
         Comment(message);
         Print(message);
         return (-1);
        }

      PositionTicket      = OrderTicket();
      PositionType        = OrderType();
      PositionTime        = OrderOpenTime() < PositionTime ? OrderOpenTime() : PositionTime;
      PositionOpenPrice   = (PositionLots*PositionOpenPrice+OrderLots()*OrderOpenPrice())/
                               (PositionLots+OrderLots());
      PositionLots       += OrderLots();
      PositionProfit     += OrderProfit() + OrderCommission();
      PositionCommission += OrderCommission();
      PositionStopLoss    = OrderStopLoss();
      PositionTakeProfit  = OrderTakeProfit();
      PositionComment     = OrderComment();

      positions+=1;
     }

   if(PositionOpenPrice>0)
      PositionOpenPrice=NormalizeDouble(PositionOpenPrice,_Digits);

   if(PositionLots==0)
      PositionTime=D'2050.01.01 00:00';

   return (positions);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AggregatePositionToString()
  {
   if(PositionType==OP_FLAT)
      return ("AggregatePosition Flat");

   string type=PositionType==OP_BUY ? "Long" : "Short";

   string text="AggregatePosition "+
               "Ticket="       +IntegerToString(PositionTicket)+
               ", Time="       +TimeToString(PositionTime,TIME_SECONDS)+
               ", Type="       +type+
               ", Lots="       +DoubleToString(PositionLots,2)+
               ", Price="      +DoubleToString(PositionOpenPrice,5)+
               ", StopLoss="   +DoubleToString(PositionStopLoss,5)+
               ", TakeProfit=" +DoubleToString(PositionTakeProfit,5)+
               ", Commission=" +DoubleToString(PositionCommission,2)+
               ", Profit="     +DoubleToString(PositionProfit,2);

   if(PositionComment!="")
      text=text+", \""+PositionComment+"\"";

   return (text);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ManageOrderSend(int type,double lots,double price,int slippage,double stoploss,
                    double takeprofit,string comment="",int magic=0,int expire=0)
  {
   int orderResponse=-1;
   int positions=SetAggregatePosition();

   if(positions<0)
      return(-1); // Error in SetAggregatePosition.

   if(positions==0)
     {   // Open a new position.
      if(Write_Log_File)
         WriteLogRequest("FSB Request: Open a new position.",Request);

      orderResponse=OpenNewPosition(type,lots,price,slippage,stoploss,takeprofit,magic);
     }
   else if(positions>0)
     {   // There is a position.
      if((PositionType==OP_BUY && type==OP_BUY) ||
         (PositionType==OP_SELL && type==OP_SELL))
        {   // Add to the current position.
         if(Write_Log_File)
            WriteLogRequest("FSB Request: Add to the current position.",Request);

         orderResponse=AddToCurrentPosition(type,lots,price,slippage,stoploss,takeprofit,magic);
        }
      else if((PositionType==OP_BUY && type==OP_SELL) ||
              (PositionType==OP_SELL && type==OP_BUY))
        {
         if(MathAbs(PositionLots-lots)<MarketInfo(_Symbol,MODE_LOTSTEP)/2)
           {
            if(Write_Log_File)
               WriteLogRequest("FSB Request: Close the current position.",Request);

            orderResponse=CloseCurrentPosition(slippage);
           }
         else if(PositionLots>lots)
           {
            if(Write_Log_File)
               WriteLogRequest("FSB Request: Reduce the current position.",Request);

            orderResponse=ReduceCurrentPosition(lots,price,slippage,stoploss,takeprofit,magic);
           }
         else if(PositionLots<lots)
           {
            if(Write_Log_File)
               WriteLogRequest("FSB Request: Reverse the current position.",Request);

            orderResponse=ReverseCurrentPosition(type,lots,price,slippage,stoploss,takeprofit,magic);
           }
        }
     }

   return (orderResponse);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OpenNewPosition(int type,double lots,double price,int slippage,
                    double stoploss,double takeprofit,int magic)
  {
   int orderResponse=-1;

   if(type!=OP_BUY && type!=OP_SELL)
     {   // Error. Wrong order type!
      Print("Wrong 'Open new position' request - Wrong order type!");
      return (FSB_ERR_WRONG_ORD_TYPE);
     }

   double orderLots=NormalizeEntrySize(lots);

   string comment="";
   if(Connection_ID>0)
      comment="ID="+IntegerToString(Connection_ID)+", ";
   comment=comment+"Magic="+IntegerToString(Expert_Magic);

   if(AccountFreeMarginCheck(_Symbol,type,orderLots)>0)
     {
      if(Separate_SL_TP)
        {
         if(Write_Log_File)
            WriteLogLine("OpenNewPosition calls SendOrder");

         orderResponse=SendOrder(type,lots,price,slippage,0,0,comment,magic);

         if(orderResponse>0)
           {
            if(Write_Log_File)
               WriteLogLine("OpenNewPosition calls ModifyPositionByTicket");
            double stopLossPrice   = GetStopLossPrice(type,orderLots,stoploss);
            double takeProfitPrice = GetTakeProfitPrice(type,takeprofit);

            orderResponse=ModifyPositionByTicket(orderResponse,stopLossPrice,takeProfitPrice);
           }
        }
      else
        {
         orderResponse=SendOrder(type,lots,price,slippage,stoploss,takeprofit,comment,magic);

         if(Write_Log_File)
            WriteLogLine("OpenNewPosition SendOrder Response = "+IntegerToString(orderResponse));

         if(orderResponse<0 && LastError==130)
           {   // Invalid Stops. We'll check for forbiden direct set of SL and TP
            if(Write_Log_File)
               WriteLogLine("OpenNewPosition calls SendOrder");

            orderResponse=SendOrder(type,lots,price,slippage,0,0,comment,magic);

            if(orderResponse>0)
              {
               if(Write_Log_File)
                  WriteLogLine("OpenNewPosition calls ModifyPositionByTicket");
               double stopLossPrice   = GetStopLossPrice(type,orderLots,stoploss);
               double takeProfitPrice = GetTakeProfitPrice(type,takeprofit);

               orderResponse=ModifyPositionByTicket(orderResponse,stopLossPrice,takeProfitPrice);

               if(orderResponse>0)
                 {
                  Separate_SL_TP=true;
                  Print(AccountCompany()," marked for late stops sending.");
                 }
              }
           }
        }
     }

   SetAggregatePosition();
   if(Write_Log_File)
      WriteLogLine(AggregatePositionToString());

   return (orderResponse);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int AddToCurrentPosition(int type,double lots,double price,int slippage,
                         double stoploss,double takeprofit,int magic)
  {
// Checks if we have enough money.
   if(AccountFreeMarginCheck(_Symbol,type,lots)<=0)
      return (-1);

   if(Write_Log_File)
      WriteLogLine("AddToCurrentPosition calls OpenNewPosition");

   int orderResponse=OpenNewPosition(type,lots,price,slippage,stoploss,takeprofit,magic);

   if(orderResponse<0)
      return (orderResponse);

   double stopLossPrice   = GetStopLossPrice(type,PositionLots,stoploss);
   double takeProfitPrice = GetTakeProfitPrice(type,takeprofit);

   orderResponse=SetStopLossAndTakeProfit(stopLossPrice,takeProfitPrice);

   SetAggregatePosition();

   return (orderResponse);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ReduceCurrentPosition(double lots,double price,int slippage,
                          double stoploss,double takeprofit,int magic)
  {
   double newlots=PositionLots-lots;

   int orderstotal=OrdersTotal();
   int orders=0;
   datetime openPos[][2];

   for(int i=0; i<orderstotal; i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         LastError=GetLastError();
         Print("Error in OrderSelect: ",GetErrorDescription(LastError));
         continue;
        }

      if(OrderMagicNumber()!=magic || OrderSymbol()!=_Symbol)
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      orders++;
      ArrayResize(openPos,orders);
      openPos[orders - 1][0] = OrderOpenTime();
      openPos[orders - 1][1] = OrderTicket();
     }

   if(FIFO_order)
      ArraySort(openPos,WHOLE_ARRAY,0,MODE_ASCEND);
   else
      ArraySort(openPos,WHOLE_ARRAY,0,MODE_DESCEND);

   for(int i=0; i<orders; i++)
     {
      if(!OrderSelect((int)openPos[i][1],SELECT_BY_TICKET))
        {
         LastError=GetLastError();
         Print("Error in OrderSelect: ",GetErrorDescription(LastError));
         continue;
        }

      double orderLots=(lots>=OrderLots()) ? OrderLots() : lots;
      ClosePositionByTicket(OrderTicket(),orderLots,slippage);
      lots-=orderLots;

      if(lots<=0)
         break;
     }

   double stopLossPrice   = GetStopLossPrice(PositionType,newlots,stoploss);
   double takeProfitPrice = GetTakeProfitPrice(PositionType,takeprofit);

   int orderResponse=SetStopLossAndTakeProfit(stopLossPrice,takeProfitPrice);

   SetAggregatePosition();
   ConsecutiveLosses=0;

   return (orderResponse);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CloseCurrentPosition(int slippage)
  {
   int orderResponse = -1;
   int orderstotal   = OrdersTotal();
   int orders        = 0;
   datetime openPos[][2];

   for(int i=0; i<orderstotal; i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         LastError=GetLastError();
         Print("Error in OrderSelect: ",GetErrorDescription(LastError));
         continue;
        }

      if(OrderMagicNumber()!=Expert_Magic || OrderSymbol()!=_Symbol)
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      orders++;
      ArrayResize(openPos,orders);
      openPos[orders - 1][0] = OrderOpenTime();
      openPos[orders - 1][1] = OrderTicket();
     }

   if(FIFO_order)
      ArraySort(openPos,WHOLE_ARRAY,0,MODE_ASCEND);
   else
      ArraySort(openPos,WHOLE_ARRAY,0,MODE_DESCEND);

   for(int i=0; i<orders; i++)
     {
      if(!OrderSelect((int)openPos[i][1],SELECT_BY_TICKET))
        {
         LastError=GetLastError();
         Print("Error in OrderSelect: ",GetErrorDescription(LastError));
         continue;
        }
      orderResponse=ClosePositionByTicket(OrderTicket(),OrderLots(),slippage);
     }

   ConsecutiveLosses=(PositionProfit<0) ? ConsecutiveLosses+1 : 0;
   SetAggregatePosition();
   Print("ConsecutiveLosses = ",ConsecutiveLosses);

   return (orderResponse);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ReverseCurrentPosition(int type,double lots,double price,int slippage,
                           double stoploss,double takeprofit,int magic)
  {
   lots=lots-PositionLots;
   CloseCurrentPosition(slippage);

   int orderResponse=OpenNewPosition(type,lots,price,slippage,stoploss,takeprofit,magic);

   SetAggregatePosition();
   ConsecutiveLosses=0;

   return (orderResponse);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(double stoploss,double takeprofit)
  {
   if(SetAggregatePosition()<=0)
      return (false);

   double stopLossPrice   = GetStopLossPrice(PositionType,PositionLots,stoploss);
   double takeProfitPrice = GetTakeProfitPrice(PositionType,takeprofit);

   int response=SetStopLossAndTakeProfit(stopLossPrice,takeProfitPrice);

   return (response >= 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SendOrder(int type,double lots,double price,int slippage,double stoploss,
              double takeprofit,string comment="",int magic=0)
  {
   int orderResponse=-1;

   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(!GetTradeContext())
         return (-1);

      double orderLots       = NormalizeEntrySize(lots);
      double orderPrice      = GetMarketPrice(type, price);
      double stopLossPrice   = GetStopLossPrice(type,orderLots,stoploss);
      double takeProfitPrice = GetTakeProfitPrice(type,takeprofit);
      color  colorDeal       = (type == OP_BUY) ? Lime : Red;

      orderResponse=OrderSend(_Symbol,type,orderLots,orderPrice,slippage,stopLossPrice,
                              takeProfitPrice,comment,magic,0,colorDeal);
      LastError=GetLastError();

      ReleaseTradeContext();

      if(Write_Log_File)
         WriteLogLine("SendOrder OrderSend("+_Symbol+", "+IntegerToString(type)+
                      ", Lots="       +DoubleToString(orderLots,2)+
                      ", Price="      +DoubleToString(orderPrice,5)+
                      ", Slippage="   +IntegerToString(slippage)+
                      ", StopLoss="   +DoubleToString(stopLossPrice,5)+
                      ", TakeProfit=" +DoubleToString(takeProfitPrice,5)+
                      ", \""+comment  +"\""+")"+
                      ", Response="   +IntegerToString(orderResponse)+
                      ", LastError="  +IntegerToString(LastError));

      if(orderResponse>0)
         break;

      if(LastError!=135 && LastError!=136 && LastError!=137 && LastError!=138)
         break;

      Print("Error with SendOrder: ",GetErrorDescription(LastError));

      Sleep(TRADE_RETRY_WAIT);
     }

   return (orderResponse);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ClosePositionByTicket(int orderTicket,double orderLots,int slippage)
  {
   if(!OrderSelect(orderTicket,SELECT_BY_TICKET))
     {
      LastError=GetLastError();
      Print("Error with OrderSelect: ",GetErrorDescription(LastError));
      return (-1);
     }

   int orderType=OrderType();

   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(!GetTradeContext())
         return (-1);

      double orderPrice=(orderType==OP_BUY)
         ? MarketInfo(_Symbol,MODE_BID)
         : MarketInfo(_Symbol,MODE_ASK);
      orderPrice=NormalizeDouble(orderPrice,Digits);

      bool response=OrderClose(orderTicket,orderLots,orderPrice,slippage,Gold);

      LastError=GetLastError();
      ReleaseTradeContext();

      if(Write_Log_File)
         WriteLogLine("ClosePositionByTicket OrderClose("+
                      "Ticket="      +IntegerToString(orderTicket)+
                      ", Lots="      +DoubleToString(orderLots,2)+
                      ", Price="     +DoubleToString(orderPrice,_Digits)+
                      ", Slippage="  +IntegerToString(slippage)+")"+
                      ", Response="  +IntegerToString(response)+
                      ", LastError=" +IntegerToString(LastError));

      if(response)
         return (0);

      Print("Error with ClosePositionByTicket: ",GetErrorDescription(LastError),
               ". Attempt No: ",(attempt+1));
      Sleep(TRADE_RETRY_WAIT);
     }

   return (-1);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SetStopLossAndTakeProfit(double stopLossPrice,double takeProfitPrice)
  {
   int response=1;

   for(int i=0; i<OrdersTotal(); i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         LastError=GetLastError();
         Print("Error with OrderSelect: ",GetErrorDescription(LastError));
         continue;
        }

      if(OrderMagicNumber()!=Expert_Magic || OrderSymbol()!=_Symbol)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      response=ModifyPositionByTicket(OrderTicket(),stopLossPrice,takeProfitPrice);
     }

   return (response);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ModifyPositionByTicket(int orderTicket,double stopLossPrice,double takeProfitPrice)
  {
   if(!OrderSelectByTicket(orderTicket))
      return (-1);

   stopLossPrice=NormalizeEntryPrice(stopLossPrice);
   takeProfitPrice=NormalizeEntryPrice(takeProfitPrice);

   double oldStopLoss=NormalizeEntryPrice(OrderStopLoss());
   double oldTakeProfit=NormalizeEntryPrice(OrderTakeProfit());

   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(attempt>0)
        {   // Prevents Invalid Stops due to price change during the cycle.
         stopLossPrice=CorrectStopLossPrice(OrderType(),stopLossPrice);
         takeProfitPrice=CorrectTakeProfitPrice(OrderType(),takeProfitPrice);
        }

      if(MathAbs(stopLossPrice-oldStopLoss)<PipsValue &&
         MathAbs(takeProfitPrice-oldTakeProfit)<PipsValue)
         return(1); // There isn't anything to change.

      if(!GetTradeContext())
         return (-1);

      double orderOpenPrice=NormalizeDouble(OrderOpenPrice(),_Digits);

      bool rc=OrderModify(orderTicket,orderOpenPrice,stopLossPrice,takeProfitPrice,0);

      LastError=GetLastError();
      ReleaseTradeContext();
      string log="";
      if(Write_Log_File)
         log="ModifyPositionByTicket OrderModify("+_Symbol+
             ", Ticket="     +IntegerToString(orderTicket)+
             ", Price="      +DoubleToString(orderOpenPrice,5)+
             ", StopLoss="   +DoubleToString(stopLossPrice,5)+
             ", TakeProfit=" +DoubleToString(takeProfitPrice,5)+")"+
             " Response="    +IntegerToString(rc)+
             " LastError="   +IntegerToString(LastError);

      if(rc)
        {   // Modification was successful.
         if(Write_Log_File)
            WriteLogLine(log);
         return (1);
        }
      else if(LastError==1)
        {
         if(!OrderSelectByTicket(orderTicket))
            return (-1);

         if(MathAbs(stopLossPrice-OrderStopLoss())<PipsValue &&
            MathAbs(takeProfitPrice-OrderTakeProfit())<PipsValue)
           {
            if(Write_Log_File) WriteLogLine(log+", Checked OK");
            LastError=0;
            return(1); // We assume that there is no error.
           }
        }

      Print("Error with OrderModify(",orderTicket,", ",orderOpenPrice,", ",
            stopLossPrice,", ",takeProfitPrice,") ",GetErrorDescription(LastError),".");
      Sleep(TRADE_RETRY_WAIT);
      RefreshRates();

      if(LastError==4108)
         return (-1); // Invalid eticket error
     }

   return (-1);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool OrderSelectByTicket(int orderTicket)
  {
   bool response=OrderSelect(orderTicket,SELECT_BY_TICKET);

   if(!response)
     {
      LastError=GetLastError();
      string message="### Error with OrderSelect("+IntegerToString(orderTicket)+")"+
                     ", LastError="+IntegerToString(LastError)+
                     ", "+GetErrorDescription(LastError);
      Print(message);
      if(Write_Log_File)
         WriteLogLine(message);
     }

   return (response);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMarketPrice(int type,double price)
  {
   double orderPrice=(type==OP_BUY)
      ? MarketInfo(_Symbol,MODE_ASK)
      : MarketInfo(_Symbol,MODE_BID);

   return (NormalizeEntryPrice(orderPrice));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeEntryPrice(double price)
{
   double tickSize=MarketInfo(_Symbol,MODE_TICKSIZE);
   if(tickSize!=0)
      return (NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits));
   return (NormalizeDouble(price,_Digits));
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(int type,double takeprofit)
  {
   if(takeprofit<Epsilon)
      return (0);

   if(takeprofit<StopLevel)
      takeprofit=StopLevel;

   double takeProfitPrice=(type==OP_BUY)
      ? MarketInfo(_Symbol,MODE_BID)+takeprofit*_Point
      : MarketInfo(_Symbol,MODE_ASK)-takeprofit*_Point;

   return (NormalizeEntryPrice(takeProfitPrice));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(int type,double lots,double stoploss)
  {
   if(stoploss<Epsilon)
      return (0);

   if(stoploss<StopLevel)
      stoploss=StopLevel;

   double stopLossPrice=(type==OP_BUY)
      ? MarketInfo(_Symbol,MODE_BID)-stoploss*_Point
      : MarketInfo(_Symbol,MODE_ASK)+stoploss*_Point;

   return (NormalizeEntryPrice(stopLossPrice));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CorrectTakeProfitPrice(int type,double takeProfitPrice)
  {
   if(takeProfitPrice<Epsilon)
      return (0);

   double bid=MarketInfo(_Symbol,MODE_BID);
   double ask=MarketInfo(_Symbol,MODE_ASK);

   if(type==OP_BUY)
     {
      double minTPPrice=bid+StopLevel*_Point;
      if(takeProfitPrice<minTPPrice)
         takeProfitPrice=minTPPrice;
     }
   else // if(type==OP_SELL)
     {
      double maxTPPrice=ask-StopLevel*_Point;
      if(takeProfitPrice>maxTPPrice)
         takeProfitPrice=maxTPPrice;
     }

   return (NormalizeEntryPrice(takeProfitPrice));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CorrectStopLossPrice(int type,double stopLossPrice)
  {
   if(stopLossPrice==Epsilon)
      return (0);

   double bid=MarketInfo(_Symbol,MODE_BID);
   double ask=MarketInfo(_Symbol,MODE_ASK);

   if(type==OP_BUY)
     {
      double minSLPrice=bid-StopLevel*_Point;
      if(stopLossPrice>minSLPrice)
         stopLossPrice=minSLPrice;
     }
   else // if(type==OP_SELL)
     {
      double maxSLPrice=ask+StopLevel*_Point;
      if(stopLossPrice<maxSLPrice)
         stopLossPrice=maxSLPrice;
     }

   return (NormalizeEntryPrice(stopLossPrice));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeEntrySize(double size)
  {
   double minlot  = MarketInfo(_Symbol, MODE_MINLOT);
   double maxlot  = MarketInfo(_Symbol, MODE_MAXLOT);
   double lotstep = MarketInfo(_Symbol, MODE_LOTSTEP);

   if(size<minlot-Epsilon)
      return (0);

   if(MathAbs(size-minlot)<Epsilon)
      return (minlot);

   int steps=(int) MathRound((size-minlot)/lotstep);
   size=minlot+steps*lotstep;

   if(size>=maxlot)
      size=maxlot;

   return (size);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetMaxStopLoss()
  {
   double bid=MarketInfo(_Symbol, MODE_BID);
   double ask=MarketInfo(_Symbol, MODE_ASK);
   double spread=(ask-bid)/_Point;

   for(int i=0; i<OrdersTotal(); i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         LastError=GetLastError();
         Print("Error with OrderSelect: ",GetErrorDescription(LastError));
         continue;
        }

      if(OrderMagicNumber()!=Expert_Magic || OrderSymbol()!=_Symbol)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      int    orderTicket     = OrderTicket();
      double posOpenPrice    = OrderOpenPrice();
      double stopLossPrice   = OrderStopLoss();
      double takeProfitPrice = OrderTakeProfit();
      int    stopLossPoints  = (int)MathRound(MathAbs(posOpenPrice - stopLossPrice)/_Point);

      if(stopLossPrice<Epsilon || stopLossPoints>Protection_Max_StopLoss+spread)
        {
         stopLossPrice=type==OP_BUY
            ? posOpenPrice-_Point*(Protection_Max_StopLoss+spread)
            : posOpenPrice+_Point*(Protection_Max_StopLoss+spread);
         stopLossPrice=CorrectStopLossPrice(type,stopLossPrice);

         if(Write_Log_File)
            WriteLogRequest("SetMaxStopLoss",
               "StopLossPrice="+DoubleToString(stopLossPrice,_Digits));

         int result=ModifyPositionByTicket(orderTicket,stopLossPrice,takeProfitPrice);

         if(result>0)
            Print("MaxStopLoss(",Protection_Max_StopLoss,") set StopLoss to ",
               DoubleToString(stopLossPrice,_Digits));
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetBreakEvenStop()
  {
   if(SetAggregatePosition()<=0)
      return;

   double breakeven=StopLevel;
   if(breakeven<BreakEven)
      breakeven=BreakEven;

   double breakprice = 0; // Break Even price including commission.
   double commission = 0; // Commission in points.
   if(PositionCommission!=0)
      commission=MathAbs(PositionCommission)/MarketInfo(_Symbol,MODE_TICKVALUE);

   double bid=MarketInfo(_Symbol,MODE_BID);
   double ask=MarketInfo(_Symbol,MODE_ASK);

   if(PositionType==OP_BUY)
     {
      breakprice=NormalizeEntryPrice(PositionOpenPrice+_Point*commission/PositionLots);
      if(bid-breakprice>=_Point*breakeven)
        {
         if(PositionStopLoss<breakprice)
           {
            if(Write_Log_File)
               WriteLogRequest("SetBreakEvenStop",
                  "BreakPrice="+DoubleToString(breakprice,_Digits));

            SetStopLossAndTakeProfit(breakprice,PositionTakeProfit);

            Print("SetBreakEvenStop(",BreakEven,") set StopLoss to ",
               DoubleToString(breakprice,_Digits),
               ", Bid=",DoubleToString(bid,_Digits));
           }
        }
     }
   else if(PositionType==OP_SELL)
     {
      breakprice=NormalizeEntryPrice(PositionOpenPrice-_Point*commission/PositionLots);
      if(breakprice-ask>=_Point*breakeven)
        {
          if(PositionStopLoss==0||PositionStopLoss>breakprice)
           {
            if(Write_Log_File)
               WriteLogRequest("SetBreakEvenStop",
                  "BreakPrice="+DoubleToString(breakprice,_Digits));

            SetStopLossAndTakeProfit(breakprice,PositionTakeProfit);

            Print("SetBreakEvenStop(",BreakEven,") set StopLoss to ",
               DoubleToString(breakprice,_Digits),
                  ", Ask=",DoubleToString(ask,_Digits));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetTrailingStop(bool isNewBar)
  {
   bool isCheckTS=true;

   if(isNewBar)
     {
      if(PositionType==OP_BUY && PositionTime>barHighTime)
         isCheckTS=false;

      if(PositionType==OP_SELL && PositionTime>barLowTime)
         isCheckTS=false;

      barHighTime    = Time[0];
      barLowTime     = Time[0];
      currentBarHigh = High[0];
      currentBarLow  = Low[0];
     }
   else
     {
      if(High[0]>currentBarHigh)
        {
         currentBarHigh = High[0];
         barHighTime    = Time[0];
        }
      if(Low[0]<currentBarLow)
        {
         currentBarLow = Low[0];
         barLowTime    = Time[0];
        }
     }

   if(SetAggregatePosition()<=0)
      return;

   if(TrailingMode=="tick")
      SetTrailingStopTickMode();
   else if(TrailingMode=="bar" && isNewBar && isCheckTS)
      SetTrailingStopBarMode();

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetTrailingStopBarMode()
  {
   double bid=MarketInfo(_Symbol,MODE_BID);
   double ask=MarketInfo(_Symbol,MODE_ASK);

   if(PositionType==OP_BUY)
     {   // Long position
      double stopLossPrice=High[1]-_Point*TrailingStop;
      if(PositionStopLoss<stopLossPrice-PipsValue)
        {
         if(stopLossPrice<bid)
           {
            if(stopLossPrice>bid-_Point*StopLevel)
               stopLossPrice=bid-_Point*StopLevel;

            if(Write_Log_File)
               WriteLogRequest("SetTrailingStopBarMode",
                  "StopLoss="+DoubleToString(stopLossPrice,_Digits));

            SetStopLossAndTakeProfit(stopLossPrice,PositionTakeProfit);

            Print("Trailing Stop (",TrailingStop,") moved to: ",
               DoubleToString(stopLossPrice,_Digits),", Bid=",DoubleToString(bid,_Digits));
           }
         else
           {
            if(Write_Log_File)
               WriteLogRequest("SetTrailingStopBarMode",
                  "StopLoss="+DoubleToString(stopLossPrice,_Digits));

            bool isSucceed=CloseCurrentPosition(StopLevel)==0;

            int lastErrorOrdClose=GetLastError();
            lastErrorOrdClose=(lastErrorOrdClose>0) ? lastErrorOrdClose : LastError;
            if(!isSucceed)
               Print("Error in OrderClose: ",GetErrorDescription(lastErrorOrdClose));
           }
        }
     }
   else if(PositionType==OP_SELL)
     {   // Short position
      double stoploss=Low[1]+_Point*TrailingStop;
      if(PositionStopLoss>stoploss+PipsValue)
        {
         if(stoploss>ask)
           {
            if(stoploss<ask+_Point*StopLevel)
               stoploss=ask+_Point*StopLevel;

            if(Write_Log_File)
               WriteLogRequest("SetTrailingStopBarMode",
                  "StopLoss="+DoubleToString(stoploss,_Digits));

            SetStopLossAndTakeProfit(stoploss,PositionTakeProfit);

            Print("Trailing Stop (",TrailingStop,") moved to: ",
               DoubleToString(stoploss,_Digits),", Ask = ",DoubleToString(ask,_Digits));
           }
         else
           {
            if(Write_Log_File)
               WriteLogRequest("SetTrailingStopBarMode",
                  "StopLoss="+DoubleToString(stoploss,_Digits));

            bool isSucceed=CloseCurrentPosition(StopLevel)==0;

            int lastErrorOrdClose=GetLastError();
            lastErrorOrdClose=(lastErrorOrdClose>0) ? lastErrorOrdClose : LastError;
            if(!isSucceed)
               Print("Error in OrderClose: ",GetErrorDescription(lastErrorOrdClose));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetTrailingStopTickMode()
  {
   if(PositionType==OP_BUY)
     {   // Long position
      double bid=MarketInfo(_Symbol,MODE_BID);
      if(bid>=PositionOpenPrice+_Point*TrailingStop)
        {
         if(PositionStopLoss<bid-_Point*(TrailingStop+TrailingStop_Moving_Step))
           {
            double stopLossPrice=bid-_Point*TrailingStop;
            if(Write_Log_File)
               WriteLogRequest("SetTrailingStopTickMode",
                  "StopLoss="+DoubleToString(stopLossPrice,_Digits));

            SetStopLossAndTakeProfit(stopLossPrice,PositionTakeProfit);

            Print("Trailing Stop (",TrailingStop,") moved to: ",
               DoubleToString(stopLossPrice,_Digits),", Bid=",DoubleToString(bid,_Digits));
           }
        }
     }
   else if(PositionType==OP_SELL)
     {   // Short position
      double ask=MarketInfo(_Symbol,MODE_ASK);
      if(PositionOpenPrice-ask>=_Point*TrailingStop)
         {
          if(PositionStopLoss>ask+_Point*(TrailingStop+TrailingStop_Moving_Step))
           {
            double stopLossPrice=ask+_Point*TrailingStop;
            if(Write_Log_File)
                WriteLogRequest("SetTrailingStopTickMode",
                  "StopLoss="+DoubleToString(stopLossPrice,_Digits));

            SetStopLossAndTakeProfit(stopLossPrice,PositionTakeProfit);

            Print("Trailing Stop (",TrailingStop,") moved to: ",
               DoubleToString(stopLossPrice,_Digits),", Ask=",DoubleToString(ask,_Digits));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePositionStopExpert()
  {
   CloseCurrentPosition(100);

   string account = DoubleToString(AccountEquity(), 2);
   string message = "\n" + "The account equity (" + account +
                    ") dropped below the minimum allowed (" +
                    IntegerToString(Protection_Min_Account) + ").";
   Comment(message);
   Print(message);

   if(Write_Log_File)
      WriteLogLine(message);

   Sleep(20*1000);
   CloseExpert();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DetectSLTPActivation()
  {
// Save position values from previous tick.
   double oldStopLoss   = PositionStopLoss;
   double oldTakeProfit = PositionTakeProfit;
   double oldProfit     = PositionProfit;
   int    oldType       = PositionType;
   double oldLots       = PositionLots;

   ActivatedStopLoss   = 0;
   ActivatedTakeProfit = 0;
   ClosedSLTPLots      = 0;

   SetAggregatePosition();

   if(oldType!=OP_FLAT && PositionType==OP_FLAT)
     {   // Position was closed this tick. It must be due to SL or TP.
      double closePrice=(oldType==OP_BUY)
         ? MarketInfo(_Symbol,MODE_BID)
         : MarketInfo(_Symbol,MODE_ASK);

      string stopMessage  = "Position was closed";
      ActivatedStopLoss   = closePrice; // At Stop Loss
      ActivatedTakeProfit = closePrice; // or at Take Profit ?

      if(MathAbs(oldStopLoss-closePrice)<2*PipsValue)
        {   // Activated Stop Loss
         ActivatedTakeProfit=0;
         stopMessage="Activated StopLoss="+DoubleToString(ActivatedStopLoss,_Digits);
        }
      else if(MathAbs(oldTakeProfit-closePrice)<2*PipsValue)
        {   // Activated Take Profit
         ActivatedStopLoss=0;
         stopMessage="Activated TakeProfit="+DoubleToString(ActivatedTakeProfit,_Digits);
        }

      ClosedSLTPLots=oldLots;

      // For Martingale (if used)
      ConsecutiveLosses=(oldProfit<0) ? ConsecutiveLosses+1 : 0;

      string message=stopMessage+
                     ", ClosePrice="        +DoubleToString(closePrice,_Digits)+
                     ", ClosedLots= "       +DoubleToString(ClosedSLTPLots,2)+
                     ", Profit="            +DoubleToString(oldProfit,2)+
                     ", ConsecutiveLosses=" +IntegerToString(ConsecutiveLosses);

      if(Write_Log_File)
         WriteNewLogLine(message);
      Print(message);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ParseOrderParameters(string parameters)
  {
   string param[];

   SplitString(parameters,";",param,2);
   if(StringSubstr(param[0],0,3)=="TS0")
     {
      TrailingStop=StrToInteger(StringSubstr(param[0],4));
      if(TrailingStop>0 && TrailingStop<StopLevel)
         TrailingStop=StopLevel;

      TrailingMode="bar";
     }
   if(StringSubstr(param[0],0,3)=="TS1")
     {
      TrailingStop=StrToInteger(StringSubstr(param[0],4));
      if(TrailingStop>0 && TrailingStop<StopLevel)
         TrailingStop=StopLevel;

      TrailingMode="tick";
     }
   if(StringSubstr(param[1],0,3)=="BRE")
      BreakEven=StrToInteger(StringSubstr(param[1],4));

   if(BreakEven>0 && BreakEven<StopLevel)
      BreakEven=StopLevel;

   Print("Trailing Stop = ",TrailingStop,", Mode - ",TrailingMode,", Break Even = ",BreakEven);

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GenerateParameters()
  {
   string parametrs="cl="+IntegerToString(ConsecutiveLosses)+";"+
                    "aSL="+DoubleToString(ActivatedStopLoss,5)+";"+
                    "aTP="+DoubleToString(ActivatedTakeProfit,5)+";"+
                    "al="+DoubleToString(ClosedSLTPLots,2);

   string ltfBarsString=GetLtfBarsString();
   if(ltfLength>0)
      parametrs=parametrs+";"+
                "LTF="+ltfBarsString;

   return (parametrs);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CommentTickResponse(string expertID,int tickresponse)
  {
   string message;
   if(tickresponse==1)
     {
      FSB_Connected = true;
      TimeLastPing  = TimeLocal();
      message=expertID+TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
        " Forex Strategy Builder is connected.";
     }
   else if(tickresponse==0)
     {
      FSB_Connected=false;
      message=expertID+TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
        " Forex Strategy Builder is disconnected.";
     }
   else if(tickresponse==-1)
     {
      message=expertID+TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
        " Error with sending a tick";
     }
   Comment(message);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetPing()
  {
   double rates[][6];
   if(ArrayCopyRates(rates)!=Bars)
      return;

   SetAggregatePosition();

   double bid     = MarketInfo(_Symbol,MODE_BID);
   double ask     = MarketInfo(_Symbol,MODE_ASK);
   int    spread  = (int) MathRound(MarketInfo(_Symbol,MODE_SPREAD));
   double tickval = MarketInfo(_Symbol,MODE_TICKVALUE);
   string params  = GenerateParameters();

   FSB_Ping(Connection_ID,_Symbol,Period(),(int) TimeCurrent(),bid,ask,spread,tickval,rates,Bars,
            AccountBalance(),AccountEquity(),AccountProfit(),AccountFreeMargin(),
            PositionTicket,PositionType,PositionLots,PositionOpenPrice,(int) PositionTime,
            PositionStopLoss,PositionTakeProfit,PositionProfit,PositionComment,params);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SendTick()
  {
   double rates[][6];
   if(ArrayCopyRates(rates)!=Bars)
      return (false);

   SetAggregatePosition();

   double bid     = MarketInfo(_Symbol,MODE_BID);
   double ask     = MarketInfo(_Symbol,MODE_ASK);
   int    spread  = (int) MathRound(MarketInfo(_Symbol,MODE_SPREAD));
   double tickval = MarketInfo(_Symbol,MODE_TICKVALUE);
   string params  = GenerateParameters();

   int response=FSB_Tick(Connection_ID,_Symbol,_Period,(int) TimeCurrent(),
      bid,ask,spread,tickval,rates,Bars,
      AccountBalance(),AccountEquity(),AccountProfit(),AccountFreeMargin(),
      PositionTicket,PositionType,PositionLots,PositionOpenPrice,(int) PositionTime,
      PositionStopLoss,PositionTakeProfit,PositionProfit,PositionComment,params);

   return (response);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetBars(string symbol,int period,int barsNecessary)
  {
   CheckChartBarsCount(symbol,period,barsNecessary);

   RefreshRates();
   double rates[][6];
   int bars=ArrayCopyRates(rates,symbol,period);
   FSB_Bars(Connection_ID,symbol,period,rates,bars);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckChartBarsCount(string symbol,int period,int barsNecessary)
  {
   int    bars=0;
   double rates[][6];

   for(int attempt=0; attempt<10; attempt++)
     {
      RefreshRates();
      bars=ArrayCopyRates(rates,symbol,period);
      if(bars<barsNecessary && GetLastError()==4066)
        {
         Comment("Loading...");
         Sleep(500);
        }
      else
         break;

      if(IsStopped())
         break;
     }

   if(bars<barsNecessary)
     {
      int hwnd=WindowHandle(symbol,period);
      int maxbars=0;
      int nullattempts=0;
      int Key_HOME=36;

      for(int attempt=0; attempt<200; attempt++)
        {
         PostMessageA(hwnd,WM_KEYDOWN,Key_HOME,0);
         PostMessageA(hwnd,WM_KEYUP,Key_HOME,0);
         Sleep(100);

         RefreshRates();
         bars=ArrayCopyRates(rates,symbol,period);

         if(bars>barsNecessary)
           {
            Comment("Loaded ",symbol," ",period," bars: ",bars);
            break;
           }

         if(nullattempts>40)
            break;

         if(IsStopped())
            break;

         nullattempts++;
         if(maxbars<bars)
           {
            nullattempts=0;
            maxbars=bars;
            Comment("Loading... ",symbol," ",period," bars: ",bars," of ",barsNecessary);
           }
        }
     }

   if(bars<barsNecessary)
     {
      string message="There isn\'t enough bars. FSB needs minimum "+
                     IntegerToString(barsNecessary)+
                     " bars for "+symbol+" "+IntegerToString(period)+
                     ". Currently "+IntegerToString(bars)+" bars are loaded.";
      Comment(message);
      Print(message);
     }

   return (bars >= barsNecessary);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetMarketInfoAll(string symbol)
  {
   FSB_MarketInfoAll(Connection_ID,
      MarketInfo(symbol,MODE_POINT),
      MarketInfo(symbol,MODE_DIGITS),
      MarketInfo(symbol,MODE_SPREAD),
      MarketInfo(symbol,MODE_STOPLEVEL),
      MarketInfo(symbol,MODE_LOTSIZE),
      MarketInfo(symbol,MODE_TICKVALUE),
      MarketInfo(symbol,MODE_TICKSIZE),
      MarketInfo(symbol,MODE_SWAPLONG),
      MarketInfo(symbol,MODE_SWAPSHORT),
      MarketInfo(symbol,MODE_STARTING),
      MarketInfo(symbol,MODE_EXPIRATION),
      MarketInfo(symbol,MODE_TRADEALLOWED),
      MarketInfo(symbol,MODE_MINLOT),
      MarketInfo(symbol,MODE_LOTSTEP),
      MarketInfo(symbol,MODE_MAXLOT),
      MarketInfo(symbol,MODE_SWAPTYPE),
      MarketInfo(symbol,MODE_PROFITCALCMODE),
      MarketInfo(symbol,MODE_MARGINCALCMODE),
      MarketInfo(symbol,MODE_MARGININIT),
      MarketInfo(symbol,MODE_MARGINMAINTENANCE),
      MarketInfo(symbol,MODE_MARGINHEDGED),
      MarketInfo(symbol,MODE_MARGINREQUIRED),
      MarketInfo(symbol,MODE_FREEZELEVEL));

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetLtfMetaData(string metaData)
  {
   string meta[];
   SplitString(metaData,";",meta);
   ltfLength=ArraySize(meta)/2;
   ArrayResize(ltfSymbols,ltfLength);
   ArrayResize(ltfPeriods,ltfLength);

   int j=0;
   for(int i=0; i<ltfLength; i++)
     {
      ltfSymbols[i]=meta[j];
      j=j+1;
      ltfPeriods[i]=StrToInteger(meta[j]);
      j=j+1;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetLtfBarsString()
  {
   string bars;
   for(int i=0; i<ltfLength; i++)
     {
      string symbol=ltfSymbols[i];
      int    period=ltfPeriods[i];

      bars=bars+symbol+"|"+IntegerToString(period);
      for(int j=1;j>=0;j--)
        {
         int    digits = (int) MarketInfo(symbol,MODE_DIGITS);
         string time   = TimeToStr(iTime(symbol,period,j),TIME_DATE)+"|"+
                         TimeToStr(iTime(symbol,period,j),TIME_SECONDS);
         string open   = DoubleToString(iOpen(symbol,period,j),digits);
         string high   = DoubleToString(iHigh(symbol,period,j),digits);
         string low    = DoubleToString(iLow(symbol,period,j),digits);
         string close  = DoubleToString(iClose(symbol,period,j),digits);
         string volume = DoubleToString(iVolume(symbol,period,j),0);

         bars=bars+"|"+time+"|"+open+"|"+high+"|"+low+"|"+close+"|"+volume;
        }

      if(i<ltfLength-1)
         bars=bars+"#";
     }

   return (bars);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetServerSema()
  {
   if(GlobalVariableCheck(SERVER_SEMA_NAME+IntegerToString(Connection_ID)))
     {   // Global variable exists.
      double value=GlobalVariableGet(SERVER_SEMA_NAME+IntegerToString(Connection_ID));
      if(value==0)
        {   // Error in GlobalVariableGet.
         Print("Error in GlobalVariableGet: ",GetLastError());
         return (SaveServerSema());
        }
      else if(value<TimeLocal()-GetTickCount()/1000)
        {   // Global variable has been set before Windows was started.
         return (SaveServerSema());
        }
      else
        {   // Server is working on another chart.
         return (false);
        }
     }

// Global variable doesn't exist.
   return (SaveServerSema());
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ReleaseServerSema()
  {
   if(IsServer)
      GlobalVariableDel(SERVER_SEMA_NAME+IntegerToString(Connection_ID));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SaveServerSema()
  {
   if(GlobalVariableSet(SERVER_SEMA_NAME+IntegerToString(Connection_ID),TimeLocal())!=0)
     {   // Global variable successfully set.
      return (true);
     }
   else
     {
      Print("Error in GlobalVariableSet: ",GetErrorDescription(GetLastError()));
      return (false);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetTradeContext()
  {
   int start=(int) GetTickCount();
   GetLastError();

   while(!GlobalVariableSetOnCondition(TRADE_SEMA_NAME,1,0))
     {
      int gle = GetLastError();
      if(gle != 0)
         Print("GTC: Error in GlobalVariableSetOnCondition: ",GetErrorDescription(gle));

      if(IsStopped())
        {
         Print("GTC: Bridge was stopped!");
         return (false);
        }

      if(GetTickCount()-start>TRADE_SEMA_TIMEOUT)
        {
         Print("GTC: Timeout!");
         return (false);
        }

      Sleep(TRADE_SEMA_WAIT);
     }

   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ReleaseTradeContext()
  {
   while(!GlobalVariableSet(TRADE_SEMA_NAME,0))
     {
      int gle = GetLastError();
      if(gle != 0)
         Print("RTC: Error in GlobalVariableSet: ",GetErrorDescription(gle));

      if(IsStopped())
         return;

      Sleep(TRADE_SEMA_WAIT);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetErrorDescription(int lastError)
  {
   string errorDescription;

   switch(lastError)
     {
      case 0:
      case 1:    errorDescription = "No error";                                                 break;
      case 2:    errorDescription = "Common error";                                             break;
      case 3:    errorDescription = "Invalid trade parameters";                                 break;
      case 4:    errorDescription = "Trade server is busy";                                     break;
      case 5:    errorDescription = "Old version of the client terminal";                       break;
      case 6:    errorDescription = "No connection with trade server";                          break;
      case 7:    errorDescription = "Not enough rights";                                        break;
      case 8:    errorDescription = "Too frequent requests";                                    break;
      case 9:    errorDescription = "Malfunctional trade operation (never returned error)";     break;
      case 64:   errorDescription = "Account disabled";                                         break;
      case 65:   errorDescription = "Invalid account";                                          break;
      case 128:  errorDescription = "Trade timeout";                                            break;
      case 129:  errorDescription = "Invalid price";                                            break;
      case 130:  errorDescription = "Invalid stops";                                            break;
      case 131:  errorDescription = "Invalid trade volume";                                     break;
      case 132:  errorDescription = "Market is closed";                                         break;
      case 133:  errorDescription = "Trade is disabled";                                        break;
      case 134:  errorDescription = "Not enough money";                                         break;
      case 135:  errorDescription = "Price changed";                                            break;
      case 136:  errorDescription = "Off quotes";                                               break;
      case 137:  errorDescription = "Broker is busy (never returned error)";                    break;
      case 138:  errorDescription = "Requote";                                                  break;
      case 139:  errorDescription = "Order is locked";                                          break;
      case 140:  errorDescription = "Long positions only allowed";                              break;
      case 141:  errorDescription = "Too many requests";                                        break;
      case 145:  errorDescription = "Modification denied because order too close to market";    break;
      case 146:  errorDescription = "Trade context is busy";                                    break;
      case 147:  errorDescription = "Expirations are denied by broker";                         break;
      case 148:  errorDescription = "Amount of open and pending orders has reached the limit";  break;
      case 149:  errorDescription = "Opening of an opposite position (hedging) is disabled";    break;
      case 150:  errorDescription = "An attempt to close a position contravening the FIFO rule";break;
      case 4000: errorDescription = "No error (never generated code)";                          break;
      case 4001: errorDescription = "Wrong function pointer";                                   break;
      case 4002: errorDescription = "Array index is out of range";                              break;
      case 4003: errorDescription = "No memory for function call stack";                        break;
      case 4004: errorDescription = "Recursive stack overflow";                                 break;
      case 4005: errorDescription = "Not enough stack for parameter";                           break;
      case 4006: errorDescription = "No memory for parameter string";                           break;
      case 4007: errorDescription = "No memory for temp string";                                break;
      case 4008: errorDescription = "Not initialized string";                                   break;
      case 4009: errorDescription = "Not initialized string in array";                          break;
      case 4010: errorDescription = "No memory for array string";                               break;
      case 4011: errorDescription = "Too long string";                                          break;
      case 4012: errorDescription = "Remainder from zero divide";                               break;
      case 4013: errorDescription = "Zero divide";                                              break;
      case 4014: errorDescription = "Unknown command";                                          break;
      case 4015: errorDescription = "Wrong jump (never generated error)";                       break;
      case 4016: errorDescription = "Not initialized array";                                    break;
      case 4017: errorDescription = "Dll calls are not allowed";                                break;
      case 4018: errorDescription = "Cannot load library";                                      break;
      case 4019: errorDescription = "Cannot call function";                                     break;
      case 4020: errorDescription = "Expert function calls are not allowed";                    break;
      case 4021: errorDescription = "Not enough memory for temp string returned from function"; break;
      case 4022: errorDescription = "System is busy (never generated error)";                   break;
      case 4050: errorDescription = "Invalid function parameters count";                        break;
      case 4051: errorDescription = "Invalid function parameter value";                         break;
      case 4052: errorDescription = "String function internal error";                           break;
      case 4053: errorDescription = "Some array error";                                         break;
      case 4054: errorDescription = "Incorrect series array using";                             break;
      case 4055: errorDescription = "Custom indicator error";                                   break;
      case 4056: errorDescription = "Arrays are incompatible";                                  break;
      case 4057: errorDescription = "Global variables processing error";                        break;
      case 4058: errorDescription = "Global variable not found";                                break;
      case 4059: errorDescription = "Function is not allowed in testing mode";                  break;
      case 4060: errorDescription = "Function is not confirmed";                                break;
      case 4061: errorDescription = "Send mail error";                                          break;
      case 4062: errorDescription = "String parameter expected";                                break;
      case 4063: errorDescription = "Integer parameter expected";                               break;
      case 4064: errorDescription = "Double parameter expected";                                break;
      case 4065: errorDescription = "Array as parameter expected";                              break;
      case 4066: errorDescription = "Requested history data in update state";                   break;
      case 4099: errorDescription = "End of file";                                              break;
      case 4100: errorDescription = "Some file error";                                          break;
      case 4101: errorDescription = "Wrong file name";                                          break;
      case 4102: errorDescription = "Too many opened files";                                    break;
      case 4103: errorDescription = "Cannot open file";                                         break;
      case 4104: errorDescription = "Incompatible access to a file";                            break;
      case 4105: errorDescription = "No order selected";                                        break;
      case 4106: errorDescription = "Unknown symbol";                                           break;
      case 4107: errorDescription = "Invalid price parameter for trade function";               break;
      case 4108: errorDescription = "Invalid ticket";                                           break;
      case 4109: errorDescription = "Trade is not allowed in the expert properties";            break;
      case 4110: errorDescription = "Longs are not allowed in the expert properties";           break;
      case 4111: errorDescription = "Shorts are not allowed in the expert properties";          break;
      case 4200: errorDescription = "Object is already exist";                                  break;
      case 4201: errorDescription = "Unknown object property";                                  break;
      case 4202: errorDescription = "Object is not exist";                                      break;
      case 4203: errorDescription = "Unknown object type";                                      break;
      case 4204: errorDescription = "No object name";                                           break;
      case 4205: errorDescription = "Object coordinates error";                                 break;
      case 4206: errorDescription = "No specified subwindow";                                   break;
      default:   errorDescription = "Unknown error";
     }

   return (errorDescription);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SplitString(string stringValue,string separatorSymbol,string &results[],int expectedResultCount=0)
  {
   if(StringFind(stringValue,separatorSymbol)<0)
     {   // No separators found, the entire string is the result.
      ArrayResize(results,1);
      results[0]=stringValue;
     }
   else
     {
      int separatorPos    = 0;
      int newSeparatorPos = 0;
      int size=0;

      while(newSeparatorPos>-1)
        {
         size=size+1;
         newSeparatorPos=StringFind(stringValue,separatorSymbol,separatorPos);

         ArrayResize(results,size);
         if(newSeparatorPos>-1)
           {
            if(newSeparatorPos-separatorPos>0)
              {
               results[size-1]=StringSubstr(stringValue,separatorPos,newSeparatorPos-separatorPos);
              }
           }
         else
           {   // Reached final element.
            results[size-1]=StringSubstr(stringValue,separatorPos,0);
           }

         //Alert(results[size-1]);
         separatorPos=newSeparatorPos+1;
        }
     }

   if(expectedResultCount==0 || expectedResultCount==ArraySize(results))
     {  // Results OK.
      return (true);
     }
   else
     {  // Results are WRONG.
      Print("ERROR - size of parsed string not expected.",true);
      return (false);
     }
  }

int _fileHandle=-1;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetLogFileName()
  {
   string time=_StringReplace(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS),":","");
   time=_StringReplace(time," ","_");
   string fileName=Symbol()+"_"+IntegerToString(Period())+
                   "_ID"+IntegerToString(Connection_ID)+"_"+
                   IntegerToString(Expert_Magic)+"_"+time+".log";

   return (fileName);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CreateLogFile(string fileName)
  {
   logLines=0;
   int handle=FileOpen(fileName,FILE_CSV|FILE_WRITE,",");
   if(handle>0)
      _fileHandle=handle;
   else
      Print("CreateFile: Error while creating log file!");
   return (handle);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void WriteLogLine(string text)
  {
   if(_fileHandle <= 0) return;
   FileWrite(_fileHandle,TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS),text);
   logLines++;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void WriteNewLogLine(string text)
  {
   if(_fileHandle <= 0) return;
   FileWrite(_fileHandle,"");
   FileWrite(_fileHandle,TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS),text);
   logLines+=2;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void WriteLogRequest(string text,string request)
  {
   if(_fileHandle <= 0) return;
   FileWrite(_fileHandle,"\n"+text);
   FileWrite(_fileHandle,TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS),request);
   logLines+=3;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FlushLogFile()
  {
   if(_fileHandle <= 0) return;
   FileFlush(_fileHandle);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseLogFile()
  {
   if(_fileHandle <= 0) return;
   WriteNewLogLine("FSB-MT4 Bridge version "+EXPERT_VERSION+" Closed.");
   FileClose(_fileHandle);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string _StringReplace(string haystack,string needle,string replace)
  {
   string left,right;
   int start=0;
   int rlen = StringLen(replace);
   int nlen = StringLen(needle);
   while(start>-1)
     {
      start=StringFind(haystack,needle,start);
      if(start>-1)
        {
         if(start>0)
           {
            left=StringSubstr(haystack,0,start);
              }else{
            left="";
           }
         right=StringSubstr(haystack,start+nlen);
         haystack=left+replace+right;
         start=start+rlen;
        }
     }
   return (haystack);
  }
//+------------------------------------------------------------------+
