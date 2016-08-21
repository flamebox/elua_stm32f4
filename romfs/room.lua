function sleep(n)
   tmr.delay( 0, n*1000000 )
end

function print_date()
	date_t = stm32f4.rtc.getdate()
	return string.format("%02d/%02d/%02d %02d:%02d:%02d",date_t.year,date_t.month,date_t.day,date_t.hour,date_t.min,date_t.sec)
end


function get_level()
	local filename,str
	filename = "/wo/level.txt"
	local wfile = io.open(filename,"r")
	str = wfile:read("*a")
	wfile:close()
	return tonumber(str)
end
function write_level(lv)
	local wrlv = tostring(lv)
	local filename = "/wo/level.txt"
	local f = io.open(filename,"wb")
	f:write(wrlv)
	f:close()
end
function remove_by_day(set)
	local newT = {}
	for i ,v in ipairs(set) do
		if v.day == 0 then
			break
		end
		table.insert(newT , v)
	end
	return newT
end

function remove_by_diff(set)
	local newT = {}
	local maxlv =0
	for i ,v in ipairs(set) do
		if (i == 1) or (i == 2)	then
			table.insert(newT , v)
		else
			if v.temp_diff == 0 then
				break
			end
			table.insert(newT , v)
			maxlv = v.lv
		end
	end
	return newT
end
function remove_by_isvalid(set)
	local newT = {}
	local maxlv
	for i ,v in ipairs(set) do
		if v.is_valid == 0 then
			break
		end
		table.insert(newT , v)
		maxlv = v.lv

	end
	return newT,maxlv
end
function remove_by_lv(set)
	local newT = {}
	for i ,v in ipairs(set) do
		if i == 1	then
			table.insert(newT , v)
		else
			if v.lv == 0 then
				break
			end
			table.insert(newT , v)
		end
	end
	return newT
end
function get_curtain_lv_table(set)
	local newT = {}
	for i, v in ipairs(set) do
		table.insert(newT,v.lv)
	end
	return newT
end
--------------------------------------------------------------
global_set = dofile(  "/wo/table.lua" )


parameter_set = global_set.parameter_set
day_set = remove_by_day(global_set.day_set)
mini_max_level = remove_by_day(global_set.mini_max_level)

ven_dev = global_set.ven_dev
iv_dev =	global_set.iv_dev
sprayer_dev = global_set.sprayer_dev
water_dev = global_set.water_dev
curtain_dev = global_set.curtain_dev

lv_set ,lv_maxlv = remove_by_isvalid(global_set.lv_set)
curtain_set = remove_by_lv(global_set.curtain_set)
curtain_lv_table = get_curtain_lv_table(curtain_set)

simplefan_set,simple_maxlv = remove_by_diff(global_set.simple_set)
ivfan_set = global_set.ivfan_set
wcurtain_set = remove_by_day(global_set.wcurtain_set)
timer_set = global_set.timer_set
sprayer_set = global_set.sprayer_set

room_name = "ROOM1"
day_of_age = 1
spell_index = 1
CoolTemp = 0
TunnelMode = 0
NowLevel = 0
MiniLevel  = 0
MaxLevel   = 0
NowOpenTime = 0



fan_para = {open_time = 0, open_dev={}, gap_dev={}, spell_dev={}}
simplefan_para = {open_time = 0,open_dev={}, gap_dev={}}
water_para = {start_time = 0, end_time = 2400, hum_limit = 100, open_time = 0, open_dev={}, temp_diff = 0}
timer_para = {start_time = 0,end_time= 0,open_dev={}}
sprayer_para = {temp=nil,start_time=nil,end_time=nil,open_sec=0,period=nil,open_dev=nil,
					open_func = function(id)
									for _,v in ipairs(id)	do
										turn_on_device(v)
									end
								end,
					close_func = function(id)
									for _,v in ipairs(id)	do
										turn_off_device(v)
									end
								end
				}
------------------------------------------------------------------------------------------------------------------------
TargetTemp = parameter_set.TargetTemp
TunnelTemp = parameter_set.CoolTemp
HappyTemp = TargetTemp + parameter_set.HappyInterval
TargetTempMode = parameter_set.TargetTempMode

SimpleFanStart = parameter_set.SimpleFanStart
PrecisionVenStart = parameter_set.PrecisionVenStart
CurtainStart = parameter_set.CurtainStart
IvFanStart = parameter_set.IvFanStart
MixFanStart = parameter_set.MixFanStart
WcurtainStart = parameter_set.WcurtainStart
TimerStart = parameter_set.TimerStart
SprayerStart = parameter_set.SprayerStart

------------------------------------------------------
FanPeriod = parameter_set.FanPeriod
FirstLevel = parameter_set.FirstLevel
QuitTemp   = parameter_set.QuitTemp
OutsideTemp  = parameter_set.OutsideTemp
QuickDelay   = parameter_set.QuickDelay
CheckPeriod  = parameter_set.CheckPeriod
UpPeriod = parameter_set.UpPeriod
DownPeriod = parameter_set.DownPeriod
------------------------------------------------------
SimpleFanPeriod = parameter_set.SimpleFanPeriod
SimpleDelayPeriod = parameter_set.SimpleDelayPeriod

-----------------------------------------------------
WcurtainPeriod = parameter_set.WcurtainPeriod
MinimalLevel   = parameter_set.MinimalLevel


CurtainLimit = parameter_set.CurtainLimit


AfterOpen = parameter_set.AfterOpen
OpenDelay = parameter_set.OpenDelay
OpenTime  = parameter_set.OpenTime
MixStartLevel = parameter_set.MixStartLevel
MixStartTime = parameter_set.MixStartTime
MixEndTime = parameter_set.MixEndTime
MixDev = parameter_set.MixDev
---------------------------------------------------
if(PrecisionVenStart == 1) then
	NowLevel = get_level()
	if(NowLevel >= FirstLevel) then
		TunnelMode = 1
	else
		TunnelMode = 0
	end
end
if(SimpleFanStart == 1) then
	TunnelMode = 2
end

function dev_init()
	local now_temp = read_temp()
	local level

	day_of_age  = find_diff_day(20160820)
	TargetTemp,	_ =find_temp_by_day(day_of_age)
	level_limit_check()

	debug_output("Lua is staring.......   Got the day_of_age ="..day_of_age..",TargetTemp ="..TargetTemp..",NowTemp ="..now_temp..",Level ="..NowLevel)

if((PrecisionVenStart == 0) and (SimpleFanStart == 0))	then
		for _,v in ipairs(ven_dev) do
			turn_off_device(v)
		end
	end

	if(IvFanStart == 0)	then
		for _,v in ipairs(iv_dev) do
			ivfan_open(v,0)
		end
	end
	if(MixFanStart == 0)	then
		for _,v in ipairs(MixDev) do
			turn_off_device(v)
		end
	end
	if(WcurtainStart == 0)	then
		for _,v in ipairs(water_dev) do
			turn_off_device(v)
		end
	end
	if(sprayer_dev)	then
		for _,v in ipairs(sprayer_dev) do
			turn_off_device(v)
		end
	end
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

function find_tunnel_happytemp(lv,set)
	lv = lv + 1
	for k,v in ipairs(set) do
		if(lv == v.lv) then
			return v.temp_diff
		end
	end
	return 0
end

function find_now_level(now_temp)
	local level_find
	local diff = now_temp - TargetTemp
	local lv2_diff_value = 0

	if(simplefan_set[3])	then
		lv2_diff_value = simplefan_set[3].temp_diff
	end

	if(diff <= 0) then
		level_find = 0
	elseif(diff < lv2_diff_value)	then
		level_find = 1
	else
		for k,v in ipairs(simplefan_set) do
			if(diff == v.temp_diff)	then
				level_find = v.lv
				break
			end
			if(diff < v.temp_diff) then
				level_find = v.lv - 1
				break
			end
		end
	end

	if(level_find == nil)	then
		level_find = simplefan_set[#simplefan_set].lv
	end

	if(level_find < MiniLevel)	then	level_find = MiniLevel	end
	if(level_find > MaxLevel)	then	level_find = MaxLevel	end
	return level_find
end


function find_set_table_by_lv(lv,set)
	local temp_table
	for k,v in ipairs(set) do
		if(lv == v.lv) then
			return v
		end
	end
	return set[1]
end


function find_set_table_by_day(set)
	for k,v in ipairs(set) do
		if(day_of_age  < v.day) then
			if(k == 1 )	then
				return set[1]
			end
			return set[k-1]
		end
	end
	if(day_of_age >= set[#set].day) then
		return set[#set]
	end
	return set[1]
end

function level_change(num)
	NowLevel = num
	remove_timer("gap_time_control")
	remove_timer("spell_time_control")
	spell_index = 1
	remove_timer("mixfan_control")
	for _,v in ipairs(MixDev) do
		turn_off_device(v)
	end
	write_level(NowLevel)
end

function simple_level_change(num)
	NowLevel = num
	remove_timer("gap_time_control")
	remove_timer("mixfan_control")
	for _,v in ipairs(MixDev) do
		turn_off_device(v)
	end
end

function mix_open(dev)
	for _,v in ipairs(dev) do
		turn_on_device(v)
	end
end
function mix_close(dev)
	for _,v in ipairs(dev) do
		turn_off_device(v)
	end
end

function gap_open(dev)
	for _,v in ipairs(dev) do
		turn_on_device(v)
	end
end
function gap_close(dev)
	local time_delay
	local _,now_time = read_osti(-1)

	for _,v in ipairs(dev) do
		turn_off_device(v)
	end

	if(MixFanStart == 1)	then
		remove_timer("mixfan_control")

		if(AfterOpen == 1)	then
			time_delay = OpenDelay
			if(time_delay > (FanPeriod - NowOpenTime))	then
				time_delay = FanPeriod - NowOpenTime
			end
		else
			time_delay = FanPeriod - NowOpenTime - OpenDelay
			if(time_delay < 0)	then time_delay = 0	end
		end

		if(OpenTime >= (FanPeriod - time_delay))	then OpenTime = FanPeriod - time_delay - 5	end

		if(now_time >= MixStartTime and now_time <= MixEndTime)	then
			if(MixStartLevel <= NowLevel and NowLevel < FirstLevel)	then
				if(0==find_timer_exist("mixfan_control"))	then
					Class_General_Timer:new(date_format(time_delay),"2100-00-00 00:00:01",FanPeriod,
						"mixfan_control", mix_open, MixDev, OpenTime, mix_close, MixDev,"on")
				end
			else
				for _,v in ipairs(MixDev) do
					turn_off_device(v)
				end
			end
		else
			for _,v in ipairs(MixDev) do
				turn_off_device(v)
			end
		end
	end
end


function spell_open(dev)
	turn_on_device(dev[spell_index])
end
function spell_close(dev)
	turn_off_device(dev[spell_index])

	spell_index = spell_index + 1
	if(spell_index > #dev)	then
		spell_index = 1
	end
end

----------------------------------------------------------------------------------------------

function fan_para:opfunc()
	local open_table={}
	local close_dev_table={}

	if(self.open_dev[1])	then
		for _,v in ipairs(self.open_dev) do
			table.insert(open_table,v)
			turn_on_device(v)
		end
	end

	if(self.gap_dev[1])	then
		if(0==find_timer_exist("gap_time_control"))	then
			Class_General_Timer:new(date_format(5),"2100-00-00 00:00:01",FanPeriod,
				"gap_time_control", gap_open, self.gap_dev, self.open_time, gap_close, self.gap_dev,"on")

			NowOpenTime = self.open_time
			debug_output("Fanperiod: ",FanPeriod,"  self.open_time: ",self.open_time)
		end
	end

	if(self.spell_dev[1])	then
		if(0==find_timer_exist("spell_time_control"))	then
			Class_General_Timer:new(date_format(5),"2100-00-00 00:00:01",FanPeriod,
				"spell_time_control", spell_open, self.spell_dev, self.open_time, spell_close, self.spell_dev,"on")

			debug_output("FanPeriod: ",FanPeriod,"self.open_time: ",self.open_time)
		end
	end

	for _,v in ipairs(self.open_dev) do
		table.insert(open_table,v)
	end
	for _,v in ipairs(self.gap_dev) do
		table.insert(open_table,v)
	end
	for _,v in ipairs(self.spell_dev) do
		table.insert(open_table,v)
	end
	close_dev_table = which_turn_off(open_table)
	for k,v in ipairs(close_dev_table) do
		turn_off_device(v)
	end
end


function fan_para:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end


function mini_level_check()
	local now_temp = read_temp()
	local fanModule
	remove_timer("wait_mini_level_change")
	if(now_temp >= HappyTemp) then
		Class_General_Timer:new(date_format(UpPeriod),"2100-00-00 00:00:00",60,"wait_level_up_change",level_up_change,nil,nil,nil,nil,"on")
	elseif(now_temp < TargetTemp) then
		Class_General_Timer:new(date_format(DownPeriod),"2100-00-00 00:00:00",60,"wait_level_down_change",level_down_change,nil,nil,nil,nil,"on")
	elseif((now_temp < HappyTemp)and(now_temp >=TargetTemp)) then
		local set = find_set_table_by_lv(NowLevel,lv_set)
		fanModule = fan_para:new(set)
		fanModule:opfunc()
		Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
	end
end

function tunnel_action()
	local now_temp = read_temp()
	local fanModule
	remove_timer("wait_tunnel_action")
	if(now_temp >= HappyTemp) then
		Class_General_Timer:new(date_format(UpPeriod),"2100-00-00 00:00:00",60,"wait_level_up_change",level_up_change,nil,nil,nil,nil,"on")
	elseif((now_temp < TargetTemp)and(NowLevel >= FirstLevel)) then
		Class_General_Timer:new(date_format(DownPeriod),"2100-00-00 00:00:00",60,"wait_level_down_change",level_down_change,nil,nil,nil,nil,"on")
	elseif((now_temp < TargetTemp)and(NowLevel == 0)) then
		local set = find_set_table_by_lv(NowLevel,lv_set)
		fanModule = fan_para:new(set)
		fanModule:opfunc()
		Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
	elseif((now_temp < HappyTemp)and(now_temp >=TargetTemp)) then
		local set = find_set_table_by_lv(NowLevel,lv_set)
		fanModule = fan_para:new(set)
		fanModule:opfunc()
		Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
	end
end

function level_up_change()
	local now_temp = read_temp()
	remove_timer("wait_level_up_change")
	if(now_temp > HappyTemp) then

		NowLevel = NowLevel + 1
		if(NowLevel > lv_maxlv) then NowLevel = lv_maxlv end
		if(NowLevel > MaxLevel)	then NowLevel = MaxLevel end

		if((NowLevel == FirstLevel) and (now_temp >= CoolTemp)) then
			TunnelMode = 1
		elseif((NowLevel == FirstLevel) and (now_temp < CoolTemp)) then
			TunnelMode = 0
			NowLevel = FirstLevel - 1
		end

		local set = find_set_table_by_lv(NowLevel,lv_set)
		level_change(NowLevel)
		fanModule = fan_para:new(set)
		fanModule:opfunc()

		Class_General_Timer:new(date_format(1),"2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
		debug_output("return to 30s")
	else
		local set = find_set_table_by_lv(NowLevel,lv_set)
		level_change(NowLevel)
		fanModule = fan_para:new(set)
		fanModule:opfunc()

		Class_General_Timer:new(date_format(1),"2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
		debug_output("return to 30s")
	end

end

function level_down_change()
	local now_temp = read_temp()
	remove_timer("wait_level_down_change")
	if(now_temp < TargetTemp) then
		NowLevel = NowLevel - 1
		if(NowLevel < MiniLevel) then NowLevel = MiniLevel	end
		if(TunnelMode == 1) then
			if(NowLevel < FirstLevel) then
				NowLevel = FirstLevel
			end
		end

		if NowLevel <= 0 then NowLevel = 0 end
		local set = find_set_table_by_lv(NowLevel,lv_set)

		level_change(NowLevel)
		fanModule = fan_para:new(set)
		fanModule:opfunc()
		Class_General_Timer:new(date_format(1),"2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
		debug_output("return to 30s")
	else
		local set = find_set_table_by_lv(NowLevel,lv_set)
		level_change(NowLevel)
		fanModule = fan_para:new(set)
		fanModule:opfunc()

		Class_General_Timer:new(date_format(1),"2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
		debug_output("return to 30s")
	end
end


function tunnel_quit_delay()
	local set = find_set_table_by_lv(NowLevel,lv_set)
	TunnelMode = 0
	TargetTemp = find_temp_by_day(day_of_age)
	HappyTemp = TargetTemp + parameter_set.HappyInterval

	NowLevel = FirstLevel - 1
	level_change(NowLevel)
	fanModule = fan_para:new(set)
	fanModule:opfunc()
	remove_timer("wait_tunnel_quit")
	Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
	debug_output("return to 30s")
end

function fan_module_controller()
	local now_temp = read_temp()
	local out_temp = read_out_temp()
	local set = find_set_table_by_lv(NowLevel,lv_set)
	local fanModule

	if(PrecisionVenStart == 0 or lv_maxlv == 0)	then	return	end

	if(TunnelMode  == 0)   then
		if(now_temp < HappyTemp and now_temp >= TargetTemp) then
			fanModule = fan_para:new(set)
			fanModule:opfunc()
		else
			if(now_temp < TargetTemp and NowLevel == 0) then
				fanModule = fan_para:new(lv_set[1])
				fanModule:opfunc()
			else
				remove_timer("fan_module")
				wait_mini_level_change = Class_General_Timer:new(date_format(1),"2100-00-00 00:00:00",60,"wait_mini_level_change",mini_level_check,nil,nil,nil,nil,"on")
			end
		end
	else
		if(now_temp < CoolTemp - QuitTemp and NowLevel == FirstLevel)	then
			if(out_temp > 0)	then
				if(out_temp < CoolTemp+OutsideTemp)	then
					remove_timer("fan_module")
					Class_General_Timer:new(date_format(QuickDelay),"2100-00-00 00:00:00",60,"wait_tunnel_quit",tunnel_quit_delay,nil,nil,nil,nil,"on")
				end
			else
				remove_timer("fan_module")
				Class_General_Timer:new(date_format(QuickDelay),"2100-00-00 00:00:00",60,"wait_tunnel_quit",tunnel_quit_delay,nil,nil,nil,nil,"on")
			end
		else

			if(NowLevel < lv_maxlv and NowLevel >= FirstLevel) then
				TargetTemp = (CoolTemp + find_tunnel_happytemp(NowLevel-1,lv_set))
				HappyTemp = (TargetTemp + find_tunnel_happytemp(NowLevel,lv_set))
				debug_output("NowLevel is  "..NowLevel.."  Happy Temp is  "..HappyTemp.."    HappyaArea is "..find_tunnel_happytemp(NowLevel,lv_set))
			elseif(NowLevel == lv_maxlv) then
				TargetTemp = (CoolTemp + find_tunnel_happytemp(NowLevel-1,lv_set))
				HappyTemp = 100
			end
			if(now_temp < HappyTemp and now_temp >= TargetTemp) then
				fanModule = fan_para:new(set)
				fanModule:opfunc()
			else
				remove_timer("fan_module")
				Class_General_Timer:new(date_format(1),"2100-00-00 00:00:00",60,"wait_tunnel_action",tunnel_action,nil,nil,nil,nil,"on")
				debug_output("create wait_tunnel_action")
			end

		end

	end

end

-------------------------------------------------------------------------------------

function simplefan_para:opfunc()
	local open_table={}
	local close_dev_table={}

	if(self.open_dev[1])	then
		for _,v in ipairs(self.open_dev) do
			table.insert(open_table,v)
			turn_on_device(v)
		end
	end

	if(self.gap_dev[1])	then
		if(0==find_timer_exist("simplegap_time_control"))	then
			Class_General_Timer:new(date_format(5),"2100-00-00 00:00:01",SimpleFanPeriod,
				"simplegap_time_control", gap_open, self.gap_dev, self.open_time, gap_close, self.gap_dev,"on")

			NowOpenTime = self.open_time
			debug_output("SimpleFanPeriod: ",SimpleFanPeriod,"self.open_time: ",self.open_time)
		end
	end

	------------------
	for _,v in ipairs(self.open_dev) do
		table.insert(open_table,v)
	end
	for _,v in ipairs(self.gap_dev) do
		table.insert(open_table,v)
	end
	close_dev_table = which_turn_off(open_table)
	for k,v in ipairs(close_dev_table) do
		turn_off_device(v)
	end
end


function simplefan_para:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function simple_level_check()
	local now_temp = read_temp()
	local level = find_now_level(now_temp)
	local set = find_set_table_by_lv(level,simplefan_set)
	local simplefanModule

	remove_timer("wait_simple_level_change")

	if(level ~= NowLevel) then

		simple_level_change(level)
		simplefanModule = simplefan_para:new(set)
		simplefanModule:opfunc()
	end

	Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",10,"simplefan_module",simplefan_module_controller,nil,nil,nil,nil,"on")
	debug_output("retrun to 30s")
end


function simplefan_module_controller()
	local now_temp = read_temp()
	local level = find_now_level(now_temp)
	local set = find_set_table_by_lv(level,simplefan_set)
	local simplefanModule

	if(SimpleFanStart == 0 or simple_maxlv == 0)	then	return	end

		if(level == 0)	then
			level_change(0)
			simplefanModule = simplefan_para:new(simplefan_set[1])
			simplefanModule:opfunc()
		else
			if(level == NowLevel)	then
				simplefanModule = simplefan_para:new(set)
				simplefanModule:opfunc()
			else
				remove_timer("simplefan_module")
				Class_General_Timer:new(date_format(SimpleDelayPeriod),"2100-00-00 00:00:00",60,"wait_simple_level_change",simple_level_check,nil,nil,nil,nil,"on")
				debug_output("create wait_simple_level_check")
			end
		end

end



function water_open(dev)
	for _,v in ipairs(dev) do
		turn_on_device(v)
	end
end
function water_close(dev)
	for _,v in ipairs(dev) do
		turn_off_device(v)
	end
end


function water_para:opfunc(n_time,n_hum,n_temp)
	if(self.open_time > WcurtainPeriod)	then  self.open_time = WcurtainPeriod	end

	if(n_hum > self.hum_limit)	then
		remove_timer("water_opreate")
		for _,v in ipairs(self.open_dev) do
			turn_off_device(v)
		end
		return
	end

	if(MinimalLevel > NowLevel)	then
		remove_timer("water_opreate")
		for _,v in ipairs(self.open_dev) do
			turn_off_device(v)
		end
		return
	end

	if((n_time>=self.start_time) and (n_time<=self.end_time))	then
		if(n_temp >= CoolTemp+self.temp_diff)	then
			if(self.open_time >= WcurtainPeriod)	then
				remove_timer("water_opreate")
				for _,v in ipairs(self.open_dev) do
					turn_on_device(v)
				end
				return
			end

			if(0==find_timer_exist("water_opreate"))	then
				Class_General_Timer:new("2000-00-00 00:00:03","2100-00-00 00:00:01",WcurtainPeriod,
					"water_opreate", water_open, self.open_dev, self.open_time, water_close, self.open_dev,"on")
			end
		else
			remove_timer("water_opreate")
			if(self.open_dev[1] == nil)	then
				for _,v in ipairs(water_dev) do
					turn_off_device(v)
				end
			else
				for _,v in ipairs(self.open_dev) do
					turn_off_device(v)
				end
			end
		end
	end

	if((n_time>self.end_time) and (n_time<=time_add(self.end_time,20)))	then
		remove_timer("water_opreate")
		for _,v in ipairs(self.open_dev) do
			turn_off_device(v)
		end
	end
end

function water_para:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end


function water_module_controller()
	if(WcurtainStart == 0)	then	return	end

	local now_temp = read_temp()
	local now_hum = read_humi()
	local _,now_time = read_osti(-1)
	local waterModule , water_set

	for k,v in ipairs(wcurtain_set) do
		if(day_of_age == 1) then
			water_set = wcurtain_set[1]
			break
		else
			if(day_of_age < v.day) then
				water_set = wcurtain_set[k-1]
				break
			end
		end
	end

	if(#wcurtain_set == 0)	then return end

	if(day_of_age >= wcurtain_set[#wcurtain_set].day) then
		water_set = wcurtain_set[#wcurtain_set]
	end

	waterModule = water_para:new(water_set)
	waterModule:opfunc(now_time,now_hum,now_temp)

end


CurtainCheckFlag = 0
function cutrain_check(curtain_dev)
	local value = 0
	local set
	local fanModule

	debug_output("Now the actual value of cutrain is = "..value)

	if((value>10000) and ((value - 10000) < CurtainLimit))	then
		if(0 == CurtainCheckFlag)	then
			remove_timer("fan_module")
			remove_timer("gap_time_control")
			remove_timer("spell_time_control")
			remove_timer("mixfan_control")
			remove_timer("wait_tunnel_action")
			remove_timer("wait_tunnel_quit")
			remove_timer("wait_mini_level_change")

			for _,v in ipairs(ven_dev) do
				turn_off_device(v)
			end

			fanModule = fan_para:new(lv_set[1])
			fanModule:opfunc()
			CurtainCheckFlag = 1
			debug_output("Forced to switch to the level 0!")
		end

	elseif((value>10000) and ((value - 10000) >= CurtainLimit))	then
		if(1== CurtainCheckFlag)	then
			set = find_set_table_by_lv(NowLevel,lv_set)
			fanModule = fan_para:new(set)
			fanModule:opfunc()
			Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",30,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
			CurtainCheckFlag = 2
			debug_output("Outside the limit,recovery ventilation level!")
		end
	else
		CurtainCheckFlag = 0
		remove_timer("cutrain_check")
		curtain_module = Class_General_Timer:new("2000-00-00 00:00:04","2100-00-00 00:00:01",120,"curtain_module",curtain_module_controller,nil,nil,nil,nil,"on")
		if(0==find_timer_exist("fan_module"))	then
			Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",30,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")
		end
		debug_output("Operation is completed,exit!")
	end
end

function check_exist()
	for _,v in ipairs(curtain_set) do
		if(NowLevel == v.lv) then
			debug_output("there is a level in set")
			return 1
		end
	end
	return 0
end

function curtain_module_controller()
	local set, pos, fix_lv, value
	local curtain_lv_table = {}

	if(0 == check_exist()) then
		for k,v in ipairs(curtain_set) do
			curtain_lv_table[k] = v.lv
		end

		if(NowLevel ~= 0) then
			table.insert(curtain_lv_table,1,NowLevel)
			table.sort(curtain_lv_table)
			for k,v in ipairs(curtain_lv_table) do
				if(NowLevel == v) then
					pos = k
				end
			end

			if (NowLevel ~= curtain_lv_table[1]) then
				fix_lv = curtain_lv_table[pos-1]
				debug_output("the fix_level".."-----"..fix_lv)
			end
		end
	end

	if(CurtainStart == 0 )	then   return	end

	for k,v in ipairs(curtain_set) do
		if(NowLevel == v.lv)	then
			set = v
			break
		elseif(fix_lv == v.lv)  then
			set = v
			break
		end
	end

	if(set)	then
		if(set.position == nil)	then set.position = 0 end

		if(set.curtain_set[1])	then
			value = 0
		else
			return
		end

		if(value > 10000)	then
			debug_output("cutrain is running, postition = "..(value-10000))
		else
			remove_timer("curtain_module")
			for k,v in ipairs(set.curtain_set) do
				open_curtain(v,set.position)
				sleep(1)
			end
			Class_General_Timer:new(date_format(1),"2100-00-00 00:00:00",5,"cutrain_check",cutrain_check,set.curtain_set[1],nil,nil,nil,"on")
		end
	end
end
---------------------------------------------------------------------------------

function ivfan_module_controller()
	local set

	if(IvFanStart == 0 )	then   return	end

	for k,v in ipairs(ivfan_set) do
		if(NowLevel == v.lv)	then
			set = v
			break
		end
	end

	if(set)	then
		if(set.ivfan_dev[1])	then
			for k,v in ipairs(set.ivfan_dev) do
				if(set.value == nil)	then set.value = 0 end
				ivfan_open(v,set.value)
			end
		else
			for k,v in ipairs(iv_dev) do
				ivfan_open(v,0)
			end
		end
	end
end

------------------------------------------------------------------------------------

function timer_para:opfunc(n_time)
	if(timer_is_start == 0) then return end

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
				Class_General_Timer:new("2000-00-00 00:00:05","2100-00-00 00:00:01",self.period,"sprayer_temp_control",
					self.open_func,self.open_dev,self.open_sec,self.close_func,self.open_dev,"on")
			end
		else
			if(1==find_timer_exist("sprayer_temp_control"))	then
				for _,v in ipairs(self.open_dev)	do
					turn_off_device(v)
				end
			end
			remove_timer("sprayer_temp_control")
		end
		return
	end

	if(0==find_timer_exist(name))	then
		hours = math.modf(self.start_time/100)
		minute	= self.start_time%100
		start_date = "2000-00-00 "..hours..":"..minute..":".."04"
		Class_General_Timer:new(start_date,"2100-00-00 00:00:01",60*60*24,name,self.open_func,self.open_dev,self.open_sec,self.close_func,self.open_dev,"on")
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

timerModule = init_timer()
sprayerModule = init_sprayer()

function debug_output(...)
	debug_output_result=""
	for i,v in ipairs{...} do
		debug_output_result = debug_output_result .. tostring(v) .. "\t"
	end
	print(debug_output_result)
end

function msleep(ms)
   tmr.delay( 0,ms*1000 )
end


function turn_on_device(id)
	debug_output("Open dev OK".."----"..id)
	msleep(500)
	return ret
end


function turn_off_device(id)
	debug_output("Close dev OK".."----"..id)
	return ret
end


function open_curtain(id,percent)
	debug_output("Curtain   "..id.."  move to "..percent.."  OK")
	return ret
end

function ivfan_open(id,value)
	debug_output("Open iv_fan OK to "..value.." ----"..id)
	return ret
end

function get_thisromm_data()

end


function read_humi()
	debug_output("Get the humi:"..(67).."%")
	return 67
end

function read_ammo()
	debug_output("Get the ammo:"..(0.34).."ppm")
	return 0.34
end

function read_temp()
	debug_output("Get the tempereture:"..(26.2).."℃")
	return 26.2
end

function read_out_temp()
	return 0
end

function read_brig(id)
	debug_output("Get the brightness:"..(1200).."Lx")
	return 1200
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


function get_date_parts(date_str)
  local _,_,y,m,d=string.find(date_str, "(%d+)-(%d+)-(%d+)")
  return tonumber(y),tonumber(m),tonumber(d)
end

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

function date_format(delay_time)
	local str,str1,str2,hour,minute,second
	local add,minute_t,second_t

	date_t = stm32f4.rtc.getdate()
	str = string.format("%02d-%02d-%02d %02d:%02d:%02d",date_t.year,date_t.month,date_t.day,date_t.hour,date_t.min,date_t.sec)

	hour,minute,second = string.match(str,"(%d+):(%d+):(%d+)")
	second_t = second
	minute_t = minute

	second = (second + delay_time)%60
	add,_ = math.modf((second_t + delay_time)/60)
	minute = (minute+add)%60
	add,_ = math.modf((minute_t+add)/60)
	hour = (hour+add)%24

	str1 = hour..":"..minute..":"..second
	str2 = string.gsub(str,"(%d+):(%d+):(%d+)",str1)
	return str2
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


function find_index(day)
	for k,v in ipairs(day_set) do
		if(day == 1)	then
			return 1
		end

		if(day < v.day ) then
			return k-1
		end
	end
	return #day_set
end
function find_temp_by_day(day)
	local target_temp, cool_temp, index

	if(TargetTempMode == 0)	then
		CoolTemp = TunnelTemp
		if(TunnelMode == 0) then
			TargetTemp = parameter_set.TargetTemp
		else
			TargetTemp = (CoolTemp + find_tunnel_happytemp(NowLevel-1,lv_set))
		end
		return TargetTemp,CoolTemp
	end

	index = find_index(day)

	if(index == 0)	then return 0,0 end

	if(index == #day_set) then return day_set[#day_set].target_temp,day_set[#day_set].cool_temp end

	local temp_diff = day_set[index+1].target_temp-day_set[index].target_temp
	local day_diff = day_set[index+1].day-day_set[index].day
	local diff_temp_per_day = temp_diff/day_diff
	local n_day = day-day_set[index].day
	target_temp = n_day*diff_temp_per_day+day_set[index].target_temp

	temp_diff = day_set[index+1].cool_temp-day_set[index].cool_temp
	diff_temp_per_day = temp_diff/day_diff
	cool_temp = n_day*diff_temp_per_day+day_set[index].cool_temp
  	if(TunnelMode == 0) then
		target_temp = target_temp
	else
		target_temp = (cool_temp + find_tunnel_happytemp(NowLevel-1,lv_set))
	end
	return target_temp,cool_temp
end


function level_limit_check()
	local set

	if(not mini_max_level)	then
		MaxLevel = 100	MiniLevel = 0
		return
	end

	for k,v in ipairs(mini_max_level) do
		if(day_of_age == 1) then
			set = mini_max_level[1]
			break
		else
			if(day_of_age < v.day) then
				set = mini_max_level[k-1]
				break
			end
		end
	end

	if(#mini_max_level == 0)	then	MaxLevel=0	MiniLevel=0		return		end

	if(day_of_age >= mini_max_level[#mini_max_level].day) then
		set = mini_max_level[#mini_max_level]
	end
	MaxLevel = set.max_level	MiniLevel = set.mini_level
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
			debug_output("XXXXXX||would remove timer named "..timer_name,tb_indx)
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
	local which_one
	local n_temp,out_temp

	dev_init()

	if room_name == "ROOM1" then which_one = 0
	elseif room_name == "ROOM2" then which_one = 1
	elseif room_name == "ROOM3" then which_one = 2
	elseif room_name == "ROOM4" then which_one = 3
	else   which_one = 0	end

	while (uart.getchar( uart.CDC, 0 ) == "") do
		now_num = stm32f4.rtc.gettime()
		n_temp = read_temp()
		out_temp = read_out_temp()
		day_of_age  = find_diff_day(20160812)
		TargetTemp, CoolTemp =find_temp_by_day(day_of_age)
		--if(TunnelMode == 1)		then	TargetTemp = CoolTemp	end
		level_limit_check()

		debug_output("*********in timer_table_handler,now time is:", now_num,"now_day is:",day_of_age,"now Level:",NowLevel,"TargetTemp: ",TargetTemp,"CoolTemp: ",CoolTemp,"TunnelMode: ",TunnelMode)


		req_time,timeout_table = look_for_next_timeout(now_num)
		if( req_time) then
			if(now_num >= req_time) then
				debug_output("----------NOW temp is:"..n_temp.."|NOW target_temp is:"..TargetTemp.."--NOW day is:"..day_of_age.."--now Level:"..NowLevel.." --NowMode is:"..TunnelMode.." --TunnelTemp is:"..CoolTemp.." --OutTemp is:"..out_temp)

				for k,t in pairs(timeout_table) do

					if(1==t.stop_timeout) then

						t.stop_timeout=nil
						t.stop_next_sec = t.next_time_n+t.stop_sec
						debug_output(print_date(),"now run stop func for",t.name,"next stop time is", t.stop_next_sec,"span is",t.span)
						t.stop_func(t.arg_stop)
					else

						t.next_time_n = now_num + t.span
						debug_output(print_date(),"now run start func for",t.name,"next time is", t.next_time_n,"span is",t.span)
						t.func(t.arg_start)
					end
				end
			else
				local gap = req_time - now_num
				if (gap>10) then gap=10 end
				--get_para(day_of_age.."|"..NowLevel.."|"..TunnelMode.."|"..string.format("%.1f", TargetTemp).."|"..string.format("%.1f", CoolTemp))
				sleep(gap)
			end
		else
			debug_output("******all timer expired!!################")
			break
		end
	end
end


function timer_module_controller()
	if(TimerStart == 0)	then	return	end
	local _,time_n = read_osti(-1)
	for i=1, #timer_set do
		timerModule[i]:opfunc(time_n)
	end
end

function sprayer_module_controller()
	if(SprayerStart == 0)	then	return	end
	local temp_n = read_temp()
	local _,time_n = read_osti(-1)
	for i=1, #sprayer_set do
		sprayerModule[i]:opfunc(i,temp_n,time_n)
	end
end


fan_module = Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",10,"fan_module",fan_module_controller,nil,nil,nil,nil,"on")

simplefan_module = Class_General_Timer:new("2000-00-00 00:00:00","2100-00-00 00:00:01",30,"simplefan_module",simplefan_module_controller,nil,nil,nil,nil,"on")

water_module = Class_General_Timer:new("2000-00-00 00:00:03","2100-00-00 00:00:01",120,"water_module",water_module_controller,nil,nil,nil,nil,"on")

curtain_module = Class_General_Timer:new("2000-00-00 00:00:04","2100-00-00 00:00:01",300,"curtain_module",curtain_module_controller,nil,nil,nil,nil,"on")

ivfan_module = Class_General_Timer:new("2000-00-00 00:00:05","2100-00-00 00:00:01",120,"ivfan_module",ivfan_module_controller,nil,nil,nil,nil,"on")

timer_module = Class_General_Timer:new("2000-00-00 00:00:08","2020-00-00 00:00:01",120,"timer_module",timer_module_controller,nil,nil,nil,nil,"on")

sprayer_module = Class_General_Timer:new("2000-00-00 00:00:07","2020-00-00 00:00:01",120,"sprayer_module",sprayer_module_controller,nil,nil,nil,nil,"on")

timer_table_handler()




