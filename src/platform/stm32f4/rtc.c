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
* Function Name  : RTC_Set_Time   RTC_Set_Date
* Description    :
* Input    : None
* Output   : None
* Return   : None
*******************************************************************************/
ErrorStatus RTC_Set_Time(u8 hour,u8 min,u8 sec,u8 ampm)  
{
	ErrorStatus err = ERROR;
    	RTC_TimeTypeDef RTC_TimeTypeInitStructure;  
      
    	RTC_TimeTypeInitStructure.RTC_Hours=hour;
    	RTC_TimeTypeInitStructure.RTC_Minutes=min;
    	RTC_TimeTypeInitStructure.RTC_Seconds=sec;
    	RTC_TimeTypeInitStructure.RTC_H12=ampm;
	
	PWR_BackupAccessCmd(ENABLE);
    	err =  RTC_SetTime(RTC_Format_BIN,&RTC_TimeTypeInitStructure);  
	/*if(ERROR ==  err)
		printf("Set time failed!\r\n");
	else
		printf("Set time ok!\r\n");*/
	PWR_BackupAccessCmd(DISABLE);
	return err;
} 

ErrorStatus RTC_Set_Date(u8 year,u8 month,u8 date,u8 week)  
{  
	ErrorStatus err = ERROR;
	RTC_DateTypeDef RTC_DateTypeInitStructure;  
	      
	RTC_DateTypeInitStructure.RTC_Date=date;
	RTC_DateTypeInitStructure.RTC_Month=month;
	RTC_DateTypeInitStructure.RTC_WeekDay=week;
	RTC_DateTypeInitStructure.RTC_Year=year;

	PWR_BackupAccessCmd(ENABLE);
	err = RTC_SetDate(RTC_Format_BIN,&RTC_DateTypeInitStructure);
	/*if(ERROR ==  err)
		printf("Set date failed!\r\n");
	else
		printf("Set date ok!\r\n");*/
	PWR_BackupAccessCmd(DISABLE);
	return err;
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
	t_tm = Time_ConvUnixToCalendar(time+28800);

	status = RTC_Set_Date((t_tm.tm_year-2000),t_tm.tm_mon,t_tm.tm_mday,1); 
	if(ERROR ==  status)
		return status;
	status = RTC_Set_Time(t_tm.tm_hour,t_tm.tm_min,t_tm.tm_sec,RTC_H12_AM); 
	if(ERROR ==  status)
		return status;

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

	RCC_APB1PeriphClockCmd(RCC_APB1Periph_PWR,ENABLE);
	PWR_BackupAccessCmd(ENABLE);
	
	if(RTC_ReadBackupRegister(RTC_BKP_DR0) != 0x9527)
	{
		RCC_LSEConfig(RCC_LSE_ON);
		while (RCC_GetFlagStatus(RCC_FLAG_LSERDY) == RESET);
		RCC_RTCCLKConfig(RCC_RTCCLKSource_LSE);	
		RCC_RTCCLKCmd(ENABLE);
	
		RTC_InitStructure.RTC_AsynchPrediv = 0x7F;
		RTC_InitStructure.RTC_SynchPrediv  = 0xFF;
		RTC_InitStructure.RTC_HourFormat   = RTC_HourFormat_24;
		RTC_Init(&RTC_InitStructure);

		RTC_Set_Time(19,0,0,RTC_H12_AM);
		RTC_Set_Date(16,8,21,7);     
		RTC_WriteBackupRegister(RTC_BKP_DR0,0X9527);
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
