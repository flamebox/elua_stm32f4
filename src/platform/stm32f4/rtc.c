// eLua module for stm32 Real Time Clock hardware
#include <time.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "platform.h"
#include "lrotable.h"
#include "platform_conf.h"
#include "auxmods.h"
#include "elua_int.h"

// Platform specific includes
#include "rtc.h"

struct tm Time_ConvUnixToCalendar(time_t t)
{
 struct tm *t_tm;
 t_tm = localtime(&t);
 t_tm->tm_year += 1900; 
 t_tm->tm_mon +=1;
 return *t_tm;
}

/*******************************************************************************
* Function Name  : Time_ConvCalendarToUnix(struct tm t)
* Description    :
* Input    : struct tm t
* Output   : None
* Return   : time_t
*******************************************************************************/
time_t Time_ConvCalendarToUnix(struct tm *t)
{
 t->tm_year -= 1900;
 return mktime(t);
}

/*******************************************************************************
* Function Name  : Time_GetUnixTime()
* Description    :
* Input    : None
* Output   : None
* Return   : time_t t
*******************************************************************************/
time_t Time_GetUnixTime(void)
{
 	RTC_TimeTypeDef timedef;
	RTC_DateTypeDef datedef;
	RTC_GetTime(RTC_Format_BIN, &timedef);
	RTC_GetDate(RTC_Format_BIN, &datedef);
	struct tm t;
	
	t.tm_year = 2000+datedef.RTC_Year;
	t.tm_mon = datedef.RTC_Month-1;  //month:0-11
	t.tm_mday = datedef.RTC_Date;
	t.tm_hour = timedef.RTC_Hours;
	t.tm_min = timedef.RTC_Minutes;
	t.tm_sec = timedef.RTC_Seconds;

	return Time_ConvCalendarToUnix(&t)-28800; //UTC to CST
}

/*******************************************************************************
* Function Name  : Time_GetCalendarTime()
* Description    :
* Input    : None
* Output   : None
* Return   : time_t t
*******************************************************************************/
struct tm Time_GetCalendarTime(time_t t_t)
{
 struct tm t_tm;
	
 t_tm = Time_ConvUnixToCalendar(t_t+28800);
 return t_tm;
}

/*******************************************************************************
* Function Name  : Time_SetRtcTime(time_t time)
* Description    : 
* Input    : time_t time  
* Output   : None
* Return   : None
*******************************************************************************/
ErrorStatus Time_SetRtcTime(time_t time)
{
	ErrorStatus status = ERROR;
	struct tm t_tm;
	RTC_TimeTypeDef timedef;
	RTC_DateTypeDef datedef;
	
	t_tm = Time_ConvUnixToCalendar(time+28800);
	datedef.RTC_Year = t_tm.tm_year-2000;
	datedef.RTC_Month = t_tm.tm_mon;
	datedef.RTC_Date = t_tm.tm_mday;
	timedef.RTC_Hours = t_tm.tm_hour;
	timedef.RTC_Minutes = t_tm.tm_min;
	timedef.RTC_Seconds = t_tm.tm_sec;
	timedef.RTC_H12 = RTC_H12_AM;
	
	PWR_BackupAccessCmd(ENABLE);
	RTC_WaitForSynchro();
	status = RTC_SetTime(RTC_Format_BIN, &timedef);
	if(ERROR == status) {
		PWR_BackupAccessCmd(DISABLE);
		return status;
	}
	else
		PWR_BackupAccessCmd(DISABLE);
		
	PWR_BackupAccessCmd(ENABLE);	
  	RTC_WaitForSynchro();
	status = RTC_SetDate(RTC_Format_BIN, &datedef);
	if(ERROR == status) {
		PWR_BackupAccessCmd(DISABLE);
		return status;
	}
	else
    		PWR_BackupAccessCmd(DISABLE);
	return status;
}

/*******************************************************************************
* Function Name  : RTC_Config(void)
* Description    : 
* Input    : None
* Output   : None
* Return   : None
*******************************************************************************/
void RTC_Config(void)
{
	RTC_InitTypeDef RTC_InitStructure;
	RTC_TimeTypeDef RTC_TimeStructure;
	RTC_DateTypeDef RTC_DateStructure;
	
  	RCC_APB1PeriphClockCmd(RCC_APB1Periph_PWR,ENABLE);
  	PWR_BackupAccessCmd(ENABLE);
  
  	RCC_LSICmd(ENABLE);
   	while(RCC_GetFlagStatus(RCC_FLAG_LSIRDY) == RESET);
    	RCC_RTCCLKConfig(RCC_RTCCLKSource_LSI);
    	RCC_RTCCLKCmd(ENABLE);
    	RTC_WaitForSynchro();
  
  	if(RTC_ReadBackupRegister(RTC_BKP_DR0) != 0x9527)
  	{
    
	    RTC_WriteProtectionCmd(DISABLE);
	  
	    RTC_EnterInitMode();
	    RTC_InitStructure.RTC_HourFormat = RTC_HourFormat_24;
	    RTC_InitStructure.RTC_AsynchPrediv = 0x7D-1;
	    RTC_InitStructure.RTC_SynchPrediv = 0xFF-1;
	    RTC_Init(&RTC_InitStructure);
	  
	    RTC_TimeStructure.RTC_Seconds = 0x00;
	    RTC_TimeStructure.RTC_Minutes = 0x00;
	    RTC_TimeStructure.RTC_Hours = 15;
	    RTC_TimeStructure.RTC_H12 = RTC_H12_AM;
	    RTC_SetTime(RTC_Format_BIN,&RTC_TimeStructure);
	  
	    RTC_DateStructure.RTC_Date = 16;
	    RTC_DateStructure.RTC_Month = 8;
	    //RTC_DateStructure.RTC_WeekDay= RTC_Weekday_Thursday;
	    RTC_DateStructure.RTC_Year = 16;
	    RTC_SetDate(RTC_Format_BIN,&RTC_DateStructure);
	  
	    RTC_ExitInitMode();
	    RTC_WriteBackupRegister(RTC_BKP_DR0,0X9527);
	    RTC_WriteProtectionCmd(ENABLE);
	    //RTC_WriteBackupRegister(RTC_BKP_DR0,0x9527);
  	}
  	PWR_BackupAccessCmd(DISABLE);
}


// Read the time from the RTC.
static int rtc_get_time( lua_State *L )
{
  lua_pushinteger( L, Time_GetUnixTime() );

  return 1;
}

// Read the date from the RTC.
static int rtc_get_date( lua_State *L )
{
  struct tm t;
  t = Time_GetCalendarTime(Time_GetUnixTime());
  // Construct the table to return the result
  lua_createtable( L, 0, 6 );

  lua_pushstring( L, "sec" );
  lua_pushinteger( L, t.tm_sec);
  lua_rawset( L, -3 );

  lua_pushstring( L, "min" );
  lua_pushinteger( L, t.tm_min);
  lua_rawset( L, -3 );

  lua_pushstring( L, "hour" );
  lua_pushinteger( L, t.tm_hour );
  lua_rawset( L, -3 );

  lua_pushstring( L, "day" );
  lua_pushinteger( L, t.tm_mday);
  lua_rawset( L, -3 );

  lua_pushstring( L, "month" );
  lua_pushinteger( L, t.tm_mon );
  lua_rawset( L, -3 );

  lua_pushstring( L, "year" );
  lua_pushinteger( L, t.tm_year);
  lua_rawset( L, -3 );

  return 1;
}

// Read the time from table foemat exp:{year=2016,month=08,day=01,hour=12,min=23,sec=48}
static int rtc_get_time_format( lua_State *L )
{
	struct tm t;
	time_t value;

	lua_pushstring(L, "year");    //将year字符串压入栈顶
	lua_gettable(L, 1);           //根据栈顶的key获取table中的value，将key移除，再将value压入栈顶        
	t.tm_year = lua_tointeger(L, -1); //取栈顶元素
	lua_pop(L, 1); //取完之后清理栈顶

	lua_pushstring(L, "month");
	lua_gettable(L, 1);
	t.tm_mon = lua_tointeger(L, -1) - 1;  //month:0-11;
	lua_pop(L, 1);

	lua_pushstring(L, "day");
	lua_gettable(L, 1);
	t.tm_mday = lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_pushstring(L, "hour");
	lua_gettable(L, 1);
	t.tm_hour = lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_pushstring(L, "min");
	lua_gettable(L, 1);
	t.tm_min = lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_pushstring(L, "sec");
	lua_gettable(L, 1);
	t.tm_sec = lua_tointeger(L, -1);
	lua_pop(L, 1);

	value =  Time_ConvCalendarToUnix(&t)-28800; //UTC to CST
	lua_pushinteger( L, value);
	return 1;
}


static int rtc_set( lua_State *L )
{
	time_t value;
    value = lua_tonumber( L, 1 );
	Time_SetRtcTime((time_t)value);
	lua_pop( L, 1 );
	return 1;
}

#define MIN_OPT_LEVEL 2
#include "lrodefs.h"

// stm32f4.rtc.*() module function map
const LUA_REG_TYPE rtc_map[] =
{
  { LSTRKEY( "gettime" ), LFUNCVAL( rtc_get_time ) },
  { LSTRKEY( "getdate" ), LFUNCVAL( rtc_get_date ) },
  { LSTRKEY( "gettime_format" ), LFUNCVAL( rtc_get_time_format ) },
  { LSTRKEY( "set" ), LFUNCVAL( rtc_set ) },
  { LNILKEY, LNILVAL }
};

/*LUALIB_API int luaopen_rtc( lua_State *L )
{
  LREGISTER( L, AUXLIB_RTC, rtc_map );
} */ 
