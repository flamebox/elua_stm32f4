
function sleep(n)
   tmr.delay( 0, n*1000000 )
end

function print_date()
	date_t = stm32f4.rtc.getdate()
	return string.format("%02d/%02d/%02d %02d:%02d:%02d",date_t.year,date_t.month,date_t.day,date_t.hour,date_t.min,date_t.sec)
end

now_level = 0
last_level = 0
level_changed = 1
inventer_dev_id = 0
day_of_age = 0


level_para = {valid_time_s=0,valid_time_e=2400,iv_on=0,iv_dev=nil,iv_method=0,iv_val=nil,iv_period=nil,curtain_id=nil,curtain_val=nil,open_dev={}}
timer_para = {start_time = 0,end_time= 0,open_dev={}}
w_curtain_para = {temp=0,start_time=0,end_time=0,open_dev=nil,hum_limit=100}

sprayer_para = {temp=nil,start_time=nil,end_time=nil,open_sec=0,period=nil,open_dev=nil,
					open_func = function(id) turn_on_device(id) end, close_func = function(id) turn_off_device(id) end}

room_name = "ROOM1"
target_temp = 15
ven_dev = {16,7,8,9,10}
level_diff_set = {0}
level_cnt = #level_diff_set
validTime_s = 0000
validTime_e = 2400


lv_set = {
{iv_on=1,iv_dev=16,iv_val=50,iv_period=10,open_dev={7,8}}
}


timer_set = {
{start_time=900,end_time=920,open_dev={11,12}},
{start_time=1000,end_time=1020,open_dev={11,12}},
{start_time=1100,end_time=1120,open_dev={11,12}},
}


--[[w_curtain_set = {
{temp=32.0,start_time=700,end_time=1750,open_dev=13},
}--]]


--[[sprayer_set = {
{temp=20.0,start_time=1408,end_time=1730,open_sec=5,period=6000,open_dev=15},
{start_time=1408,open_sec=15,open_dev=15},
{start_time=1409,open_sec=15,open_dev=15},
{start_time=1410,open_sec=15,open_dev=15},
{start_time=1411,open_sec=15,open_dev=15},
{start_time=1412,open_sec=15,open_dev=15},
}--]]


function find_now_level(now_temp)
	local diff = now_temp - target_temp
	if(diff < 0) then
			return 0
	end

	for k,v in ipairs(level_diff_set) do
		if(diff < v) then
			return(k-1)
		end
	end
	return #level_diff_set
end


function clone(tab)
  local ins = {}
  for key, var in ipairs(tab) do
    ins[key] = var
  end
  return ins
end


function which_turn_off(tab)
	local turn_off_table = clone(ven_dev)
	for _,v in ipairs(tab) do
		for i,t in ipairs(turn_off_table) do
			if(v == t) then
				table.remove(turn_off_table,i)
			end
		end
	end

	return turn_off_table
end


function iv_open(id)
	turn_on_device(inventer_dev_id)
end
function iv_close(id)
	turn_off_device(inventer_dev_id)
end



function level_para:opfunc(n_time)
	local open_time
	local open_table={}
	local close_dev_table={}

	if(validTime_s) then
		self.valid_time_s = validTime_s
	end
	if(validTime_e)	then
		self.valid_time_e = validTime_e
	end

	if(not(n_time>=self.valid_time_s and n_time<self.valid_time_e))	then
		remove_timer("timer_iv_time_control")
		debug_output("del iv_timer")
		for _,v in ipairs(ven_dev) do
			turn_off_device(v)
			debug_output("Beyond the time limit")
		end
		return
	end

	if (self.iv_period) then  open_time= self.iv_val/100.0*self.iv_period end

	if(self.iv_on==1)	then
		table.insert(open_table,self.iv_dev)
		if(self.iv_method == 0)	then
			if(level_changed == 1)	then
				inventer_dev_id = self.iv_dev
				timer_iv_time_control=Class_General_Timer:new("2000-00-00 00:00:01","2020-00-00 00:00:01",self.iv_period,
					"timer_iv_time_control",iv_open,nil,open_time,iv_close,nil,"on")
			end
		else
			remove_timer("timer_iv_time_control")
			ivfan_open(self.iv_dev,self.iv_val)
		end
	else
		remove_timer("timer_iv_time_control")
	end

	if(self.curtain_id)	then
		--open_curtain(self.curtain_id,self.curtain_val)
	end

	for _,v in ipairs(self.open_dev) do
		table.insert(open_table,v)
		turn_on_device(v)
	end

	close_dev_table = which_turn_off(open_table)
	for k,v in ipairs(close_dev_table) do
		turn_off_device(v)
	end
end


function level_para:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end


function init_level(cnt)
	local tab={}
	for i=1, cnt+1 do
		tab[i] = level_para:new(lv_set[i])
	end

	return tab
end

function timer_para:opfunc(n_time)
	if((n_time>=self.start_time) and (n_time<=time_sub(self.end_time,5)))	then
		for _,v in ipairs(self.open_dev)	do
			turn_on_device(v)
		end
	end

	if((n_time>time_sub(self.end_time,5)) and (n_time<self.end_time))	then
		for _,v in ipairs(self.open_dev)	do
			turn_off_device(v)
		end
	end
end


function timer_para:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end


function init_timer()
	local tab={}
	for i=1, #timer_set do
		tab[i] = timer_para:new(timer_set[i])
	end

	return tab
end


function w_curtain_para:opfunc(n_time,n_hum,n_temp)
	if(n_hum > self.hum_limit)	then
		turn_off_device(self.open_dev)
		return
	end

	if((n_time>=self.start_time) and (n_time<=self.end_time))	then
		if(n_temp >= self.temp)	then
			turn_on_device(self.open_dev)
		else
			turn_off_device(self.open_dev)
		end
	end

	if((n_time>self.end_time) and (n_time<=time_add(self.end_time,20)))	then
		turn_off_device(self.open_dev)
	end
end


function w_curtain_para:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end


function init_w_curtain()
	local tab={}
	for i=1, #w_curtain_set do
		tab[i] = w_curtain_para:new(w_curtain_set[i])
	end

	return tab
end

function find_sprayer_dev(set)
	local dev_table={}
	local repeat_flag = 0

	if(not set)	then return nil end

	for k,v in ipairs(set) do
		if(v.open_dev)	then
			if(k~=1)	then
				for n,m in pairs(dev_table) do
					if(v.open_dev == m) then
						repeat_flag = 1
					end
				end
				if(repeat_flag == 0)	then
					table.insert(dev_table,v.open_dev)
				end
				repeat_flag = 0
			else
				table.insert(dev_table,v.open_dev)
			end
		end
	end
	return dev_table
end

function sprayer_para:opfunc(name,n_temp,n_time)
	local name = "sprayer_timer"..name
	local start_date,hours,minute
	local time_flag

	if(self.temp)	then
		if(self.start_time and self.end_time)	then
			if(self.start_time<n_time and n_time<self.end_time)	then
				time_flag = 1
			else
				time_flag = 0
			end
		else
			time_flag = 1
		end

		if(n_temp>=self.temp and time_flag==1)	then
			if(not self.period)	then print("Period is nil,Please check it out!") return nil end

			if(0==find_timer_exist("sprayer_temp_control"))	then
				Class_General_Timer:new("2000-00-00 00:00:02","2020-00-00 00:00:01",self.period,"sprayer_temp_control",
					self.open_func,self.open_dev,self.open_sec,self.close_func,self.open_dev,"on")
			end
		else
			if(1==find_timer_exist("sprayer_temp_control"))	then
				turn_off_device(self.open_dev)
			end
			remove_timer("sprayer_temp_control")
		end
		return
	end

	if(0==find_timer_exist(name))	then
		hours = math.modf(self.start_time/100)
		minute	= self.start_time%100
		start_date = "2000-00-00 "..hours..":"..minute..":".."04"
		Class_General_Timer:new(start_date,"2020-00-00 00:00:01",60*60*24,name,self.open_func,self.open_dev,self.open_sec,self.close_func,self.open_dev,"on")
	end
end

function sprayer_para:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end


function init_sprayer()
	local tab={}
	for i=1, #sprayer_set do
		tab[i] = sprayer_para:new(sprayer_set[i])
	end

	return tab
end



function debug_output(...)
	debug_output_result=""
	for i,v in ipairs{...} do
		debug_output_result = debug_output_result .. tostring(v) .. "\t"
	end
	print(debug_output_result)
end




function turn_on_device(id)
	debug_output("turn on dev--"..id)

	return 0
end


function turn_off_device(id)
	debug_output("turn off dev--"..id)

	return 0
end



function ivfan_open(id,value)

	return ret
end




function read_humi()
	return 85.1
end

function read_ammo()
	return 0
end

function read_temp()
	return 11.2
end

function read_brig(id)

	return 1000
end

function convert_ostime_to_hhmm()
    local hour,minute
	local date_t

	date_t = stm32f4.rtc.getdate()
	hour =  date_t.hour
	minute = date_t.min

	local now=hour*100+minute
    return now
end

function read_osti(id)
    local hour,minute
	local date_t

	date_t = stm32f4.rtc.getdate()
	hour =  date_t.hour
	minute = date_t.min

	local now=hour*100+minute
    return 1,now
end

function time_add(now,add)
	local hours = math.modf(now/100)
	local minute = now%100
	local sum = minute+add
	local val

	if sum>=60 then
		hours = hours+1
		minute = sum-60
	else
		minute = minute+add
	end

	val = hours*100+minute
	return val
end

function time_sub(now,sub)
	local hours = math.modf(now/100)
	local minute = now%100
	local diff = minute-sub
	local val

	if diff<0 then
		hours = hours-1
		minute = diff+60
	else
		minute = minute-sub
	end

	val = hours*100+minute
	return val
end

--get numbers from date string  "yyyy-mm-dd"
function get_date_parts(date_str)
  local _,_,y,m,d=string.find(date_str, "(%d+)-(%d+)-(%d+)")
  return tonumber(y),tonumber(m),tonumber(d)
end
--get numbers from time sting "hh:mm:ss"
function get_time_parts(time_str)
  local _,_,hh,min,sec=string.find(time_str,"(%d+):(%d+):(%d+)")
  return tonumber(hh),tonumber(min), tonumber(sec)
end


function split_datetime(str)
	local date_str,time_str
	_,_,date_str, time_str =string.find(str,"(%d+-%d+-%d+) (%d+:%d+:%d+)")
	return date_str,time_str
end


function convert_time_to_sec_num(date_str,time_str)
	local yy,mon,dd
	local hh,mm,ss
	local l_date_str,l_time_str

	if(nil == time_str) then
		l_date_str,l_time_str=split_datetime(date_str)
	else
		l_date_str=date_str
		l_time_str=time_str
	end

	yy,mon,dd =get_date_parts(l_date_str)
	hh,mm,ss=get_time_parts(l_time_str)
	time_arry={year=yy,month=mon,day=dd,hour=hh,min=mm,sec=ss}


	time_num=stm32f4.rtc.gettime_format(time_arry)

	return time_num

end


function find_diff_day(day)
	local day_tab1 = {}
	local day_tab2 = {}
	local date_t
	date_t = stm32f4.rtc.getdate()

	now_day = string.format("%02d%02d%02d",date_t.year,date_t.month,date_t.day)
	day_tab1.year,day_tab1.month,day_tab1.day = string.match(day,"(%d%d%d%d)(%d%d)(%d%d)")
	day_tab2.year,day_tab2.month,day_tab2.day = string.match(now_day,"(%d%d%d%d)(%d%d)(%d%d)")
	local num_day1 = stm32f4.rtc.gettime_format(day_tab1)
	local num_day2 = stm32f4.rtc.gettime_format(day_tab2)

	if(num_day1 > num_day2)	then
		print("Wrong date input!")
		return 0
	end

	return (num_day2-num_day1)/(3600*24)+1
end


timer_table={}

function find_timer_exist(timer_name)
	local timer,indx
	for indx,timer in pairs(timer_table) do
		if(timer.name == timer_name) then
			return 1
		end
	end
	return 0
end

function add_timer(timer)
	local tm,indx
	for indx,tm in pairs(timer_table) do
		if(timer.name == tm.name) then
			debug_output("There is an old timer,now it will be update",tm.name)
			remove_timer(tm.name)
			table.insert(timer_table,indx,timer)
			debug_output_timer_table()
			return
		end
	end

	local cnt=#timer_table+1
	table.insert(timer_table,cnt,timer)
	debug_output_timer_table()
end

function remove_timer(timer_name)
	local tb_indx, timer,indx
	for indx,timer in pairs(timer_table) do
		if(timer.name == timer_name) then
			tb_indx=indx

			debug_output("would remove timer named "..timer_name,tb_indx)
			return table.remove(timer_table,tb_indx)
		end
	end
end

function debug_output_timer_table()
	for k,t in pairs(timer_table) do
		debug_output("k:", k,"name:",t.name,"span:",t.span)
	end
end

function look_for_next_timeout()
	local next_time=nil
	local timeout_table={}

	if(#timer_table <1) then return nil,nil end
	for k,t in pairs(timer_table) do
		if(nil == next_time ) then
			next_time=t.next_time_n
			if(t.stop_sec) then

				if(next_time >t.stop_next_sec) then
					next_time =t.stop_next_sec
				end
			end
		else
			if(next_time > t.next_time_n) then
				next_time = t.next_time_n
			end
			if(t.stop_sec) then

				if(next_time > t.stop_next_sec) then
					next_time =t.stop_next_sec
				end
			end
		end
	end


	local run_cnt
	for k,t in pairs(timer_table) do
		if(next_time == t.next_time_n) then
			run_cnt=(#timeout_table) +1
			table.insert(timeout_table,run_cnt,t)
		end
		if(t.stop_sec) 	then
			if(next_time ==  t.stop_next_sec) then
				run_cnt=(#timeout_table) +1
				t.stop_timeout=1
				table.insert(timeout_table,run_cnt,t)
			end
		end
	end
	return next_time,timeout_table
end

function check_expired(now_num)
	local key, tm
	local expired_tm_tb={}
	local rm_cnt=0

	for key,tm in pairs(timer_table) do
		if(now_num >= tm.end_time_n) then
			debug_output(tm.name, "expired!")
			tm.is_expired = 1;
			rm_cnt=(#expired_tm_tb)+1
			table.insert(expired_tm_tb,rm_cnt,tm)
		end

	end
	if(rm_cnt>0) then
		for key,tm in pairs(expired_tm_tb) do
			remove_timer(tm.name)
		end
	end
	return rm_cnt
end

function find_next_time_from_now(now_num,start_t,span)
	local gap= now_num-start_t

	local times=math.modf(gap/span)
	local need_add_one=1
	if(times == (gap/span)) then need_add_one=0 end
	local next_time=start_t+span*(times+need_add_one)
	return next_time
end


Class_General_Timer = {name="Every_Time",next_time_n=0,end_time_n=0,span=0,is_expired=1,
							func=nil,arg_start=nil,stop_sec=nil,stop_func=nil,arg_stop=nil,stop_timeout=nil,stop_next_sec}

Class_General_Timer.__index =Class_General_Timer


function Class_General_Timer:new(start_time,end_time,span,name,func,arg_start,stop_sec,stop_func,arg_stop,switch)
	local self ={}
	local	now_num = stm32f4.rtc.gettime()

	if(switch == "off") then
		return nil
	end

	setmetatable(self,Class_General_Timer)
	self.name=name
	self.span=span
	self.next_time_n=convert_time_to_sec_num(start_time)
	self.end_time_n=convert_time_to_sec_num(end_time)
	if(now_num> self.next_time_n) then
		self.next_time_n =find_next_time_from_now(now_num,self.next_time_n,span)
 	end
	self.is_expired=0
	self.func=func
	self.arg_start=arg_start
	if(stop_sec) then
		if(not stop_func) then
			debug_output("Please specify the arg stop_func when stop_sec is not nil!!\n")			     return nil
		end
		self.stop_sec=stop_sec
		self.stop_func=stop_func
		self.arg_stop=arg_stop
		self.stop_timeout=nil
		self.stop_next_sec=self.next_time_n+stop_sec
	end
	add_timer(self)
	debug_output("========new timer",self.name,self.next_time_n,self.end_time_n, self.span,stop_sec,self.stop_next_sec)
	debug_output("From now",print_date(),"next time is",self.next_time_n,"for",start_time,"to",end_time,"span",span)
	return self
end

function timer_table_handler()
	local timeout_table
	local req_time
	local now_num
	local now_temp
	local which_one

	if room_name == "ROOM1" then which_one = 0
	elseif room_name == "ROOM2" then which_one = 1
	elseif room_name == "ROOM3" then which_one = 2
	elseif room_name == "ROOM4" then which_one = 3
	else   which_one = 0	end

	while (1) do
		now_num = stm32f4.rtc.gettime()
		now_temp = read_temp()
		day_of_age  = find_diff_day(20160812)

		now_level = find_now_level(now_temp)
		debug_output("*********in timer_table_handler,now time is:", now_num,"now_temp is:",now_temp,"now_level is:",now_level)

		req_time,timeout_table = look_for_next_timeout(now_num)
		if( req_time) then

			if(now_num >= req_time) then	--timeout for special timers
				for k,t in pairs(timeout_table) do
					--debug_output("runningtimer",t.name,t.stop_timeout)
					if(1==t.stop_timeout) then
					--stop timeout
						t.stop_timeout=nil
						t.stop_next_sec = t.next_time_n+t.stop_sec
						debug_output(print_date(),"now run stop func for",t.name,"next stop time is", t.stop_next_sec,"span is",t.span)
						t.stop_func(t.arg_stop)
					else
					--next turn
						t.next_time_n = now_num + t.span
						debug_output(print_date(),"now run start func for",t.name,"next time is", t.next_time_n,"span is",t.span)
						t.func(t.arg_start)
					end
				end
			else
				local gap = req_time - now_num
				if (gap>10) then gap=10 end
				sleep(gap)
			end
		else --all timer expired
			debug_output("******all timer expired!!################")
			break
		end
	end
end

function switch_judge()
	local ven_switch,timer_switch,w_curtain_switch,sprayer_switch
	if(lv_set)	then ven_switch = "on" else ven_switch = "off"	end
	if(timer_set)	then timer_switch = "on" else timer_switch = "off"	end
	if(w_curtain_set)	then w_curtain_switch = "on" else w_curtain_switch = "off"	end
	if(sprayer_set)	then sprayer_switch = "on" else sprayer_switch = "off"	end

	return ven_switch,timer_switch,w_curtain_switch,sprayer_switch
end
ven_switch,timer_switch,w_curtain_switch,sprayer_switch = switch_judge()

if ven_switch == "on" then
	venModule = init_level(level_cnt)
end
if timer_switch == "on" then
	timerModule = init_timer()
end
if w_curtain_switch == "on" then
	wCurtainModule = init_w_curtain()
end
if sprayer_switch == "on" then
	local sprayer_dev
	sprayer_dev = find_sprayer_dev(sprayer_set)

	if(sprayer_dev)	then
		for k,v in ipairs(sprayer_dev) do
			turn_off_device(v)
		end
	end

	sprayerModule = init_sprayer()
end



function ven_module_controller()
	if last_level~=now_level then
		level_changed = 1
	end

	local _,time_n = read_osti(-1)
	venModule[now_level+1]:opfunc(time_n)
	last_level = now_level
	level_changed = 0
end



function timer_module_controller()
	local _,time_n = read_osti(-1)
	for i=1, #timer_set do
		timerModule[i]:opfunc(time_n)
	end
end



function w_curtain_module_controller()
	local _,time_n = read_osti(-1)
	local hum_n = read_humi()
	local temp_n = read_temp()
	for i=1, #w_curtain_set do
		wCurtainModule[i]:opfunc(time_n,hum_n,temp_n)
	end
end



function sprayer_module_controller()
	local temp_n = read_temp()
	local _,time_n = read_osti(-1)
	for i=1, #sprayer_set do
		sprayerModule[i]:opfunc(i,temp_n,time_n)
	end
end


ven_module = Class_General_Timer:new("2000-00-00 00:00:00","2020-00-00 00:00:01",30,"ven_module",ven_module_controller,nil,nil,nil,nil,ven_switch)

timer_module = Class_General_Timer:new("2000-00-00 00:00:05","2020-00-00 00:00:01",30,"timer_module",timer_module_controller,nil,nil,nil,nil,timer_switch)

w_curtain_module = Class_General_Timer:new("2000-00-00 00:00:07","2020-00-00 00:00:01",2.5*60,"w_curtain_module",w_curtain_module_controller,nil,nil,nil,nil,w_curtain_switch)

sprayer_module = Class_General_Timer:new("2000-00-00 00:00:09","2020-00-00 00:00:01",2*60,"sprayer_module",sprayer_module_controller,nil,nil,nil,nil,sprayer_switch)

timer_table_handler()

