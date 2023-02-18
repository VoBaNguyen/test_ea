//+------------------------------------------------------------------+
//|                                                      account.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+


MqlTick getCurrentData() {
   MqlTick lastTick;
   SymbolInfoTick(Symbol(),lastTick);
   return lastTick;
};


class AccountInfo {
   public:
      // Double
      double ACC_ASSETS;
      double BALANCE;
      double CREDIT;
      double PROFIT;
      double EQUITY;
      double MARGIN;
      double MARGIN_FREE;
      double MARGIN_LEVEL;
      double MARGIN_SO_CALL;
      double MARGIN_SO_SO;
      double MARGIN_INITIAL;
      double MAGIN_MAINTENANCE;
      double ASSETS;
      double LIABILITIES;
      double COMMISSION_BLOCKED;
      
      // String
      string NAME;
      string SERVER;
      string CURRENCY;
      string COMPANY;
      
      // Int
      long LOGIN;
      long TRADE_MODE;
      long LEVERAGE;
      long LIMIT_ORDERS;
      long MARGIN_SO_MODE;
      bool TRADE_ALLOWED;
      bool TRADE_EXPERT;
      long MARGIN_MODE;
      long CURRENCY_DIGITS;
      long FIFO_CLOSE;
      
      //+----------------------------------------+
      //| Default constructor                    |
      //+----------------------------------------+
      AccountInfo(void) {
			// Double
			ACC_ASSETS = AccountInfoDouble(ACCOUNT_ASSETS);
			BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
			CREDIT = AccountInfoDouble(ACCOUNT_CREDIT);
			PROFIT = AccountInfoDouble(ACCOUNT_PROFIT);
			EQUITY = AccountInfoDouble(ACCOUNT_EQUITY);
			MARGIN = AccountInfoDouble(ACCOUNT_MARGIN);
			MARGIN_FREE = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
			MARGIN_LEVEL = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
			MARGIN_SO_CALL = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
			MARGIN_SO_SO = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);

			// String
			NAME = AccountInfoString(ACCOUNT_NAME);
			SERVER = AccountInfoString(ACCOUNT_SERVER);
			CURRENCY = AccountInfoString(ACCOUNT_CURRENCY);
			COMPANY = AccountInfoString(ACCOUNT_COMPANY);

			// Int 
			LOGIN = AccountInfoInteger(ACCOUNT_LOGIN);
			TRADE_MODE = AccountInfoInteger(ACCOUNT_TRADE_MODE);
			LEVERAGE = AccountInfoInteger(ACCOUNT_LEVERAGE);
			LIMIT_ORDERS = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
			MARGIN_SO_MODE = AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
			TRADE_ALLOWED = AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
			TRADE_EXPERT = AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
      }
};


class MyAccount {   
   // Define methods
   public:
      // __init__
      string firstName;
      string lastName;
      long magicNumber;
      AccountInfo info;
      
      void showName() {
         PrintFormat("Name = %s %s", firstName, lastName);
      };
      
      void showBalance() {
         Alert("Balance: ", info.BALANCE);
      };
      
      /*
      1. The constructor, all parameters of which have default values, is not a default constructor.
      2. The  public, protected and private keywords are used to indicate the extent, to which 
      members of the base class will be available for the derived one. 
      The public keyword after a colon in the header of a derived class indicates that 
      the protected and public members of the base class CShape should be inherited as protected 
      and public members of the derived class CCircle.
      3. The private class members of the base class are not available for the derived class. 
      The public inheritance also means that derived classes (CCircle and CSquare) are CShapes. 
      That is, the Square (CSquare) is a shape (CShape), but the shape does not necessarily 
      have to be a square.
      */
      
      //+-----------------------------------------------------------------------+
      //| An explicit call of a parametric constructor with a default parameter |
      //+-----------------------------------------------------------------------+
      MyAccount(void) {
         AccountInfo info();
         firstName = "None";
         lastName = "None";
         magicNumber = 1111;
      }
   
      //+----------------------------------------+
      //| Parametric constructor                 |
      //+----------------------------------------+
      MyAccount(string _firstName, string _lastName, int _magicNumber) {
         AccountInfo info();
         firstName = _firstName;
         lastName = _lastName;
         magicNumber = _magicNumber;
      }
   
}