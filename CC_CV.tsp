-- This script does CC/CV charging or discharging and charge counting in mAh
-- 2022 mjsc. Run on a Keithley 2450 SMU

--Reset the instrument
reset()

local result
local promptID
local target_voltage
local target_voltage_range
local current_limit
local stop_current 
local stop_charge
local promptless = 5

-- flush display events
promptID, result = display.waitevent(1) 

-- input voltage
if (cccv_target_voltage and cccv_target_voltage != nil) then
	target_voltage = cccv_target_voltage
	promptless = promptless - 1
else
	target_voltage = display.input.number("Set Target Voltage [V]", display.NFORMAT_PREFIX, 0, 0, 100)
	if target_voltage == nil then  
		exit()
		end
end

-- input voltage range
if (cccv_target_voltage_range and cccv_target_voltage_range != nil) then
	target_voltage_range = cccv_target_voltage_range
	promptless = promptless - 1
else
	result = display.input.option("Select source voltage range", "200mV", "2V", "20V", "200V")
	if result == display.BUTTON_OPTION1 then  
		target_voltage_range = 0.2
	elseif result == display.BUTTON_OPTION2 then
		target_voltage_range = 2
	elseif result == display.BUTTON_OPTION3 then
		target_voltage_range = 20
	elseif result == display.BUTTON_OPTION4 then
		target_voltage_range = 200
	end
end


-- input current
if (cccv_current_limit and cccv_current_limit != nil) then
	current_limit = cccv_current_limit
	promptless = promptless - 1
else
current_limit = display.input.number("Set Current Limit [A]", display.NFORMAT_PREFIX, 0, 0, 1)
if current_limit == nil then  
	exit()
	end
current_limit = math.abs(current_limit)	
end


-- input stop current
if (cccv_stop_current and cccv_stop_current != nil) then
	stop_current = cccv_stop_current
	promptless = promptless - 1
else
	stop_current = display.input.number("Set Stop Current [A]", display.NFORMAT_PREFIX, 0, 0, 1)
	if stop_current == nil then  
		exit()
		end
end

-- input stop charge
if (cccv_stop_charge and cccv_stop_charge != nil) then
	stop_charge = cccv_stop_charge
	promptless = promptless - 1
else
	stop_charge = 0
	display.prompt(display.BUTTONS_YESNO, "Do you want to set a charge limit (in mAh)?")
	promptID, result = display.waitevent()
	if result == display.BUTTON_YES then
		stop_charge = display.input.number("Set Charge Limit [mAh]", display.NFORMAT_DECIMAL, 0, 0)
	end
end

local prompt_string = "Press OK to run this configuration:\n" .. "Target: " .. tostring(target_voltage) .. " V\n" .. "Source Range: " .. tostring(target_voltage_range) .. " V\n"
prompt_string = prompt_string .. "Limit: "  .. tostring(current_limit) .. " A\n".."Stop current: " .. tostring(stop_current) .. " A\n"

if stop_charge != 0 then
	prompt_string = prompt_string .. "Stop Charge: " .. tostring(stop_charge)  .. " mAh\n"
end

-- no prompt if all values are set globally
if promptless > 0 then
	display.prompt(display.BUTTONS_OKCANCEL, prompt_string)
	promptID, result = display.waitevent()
	if result != display.BUTTON_OK then
		exit()
	end 
end

--set up source function
smu.source.autorange = smu.OFF
smu.source.range = target_voltage_range
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = current_limit
smu.source.level = target_voltage
smu.source.readback = smu.ON

--set up measure function
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.terminals = smu.TERMINALS_FRONT
smu.measure.autorange = smu.ON
smu.measure.nplc = 2
smu.source.highc = smu.OFF
smu.measure.sense = smu.SENSE_2WIRE

defbuffer1.clear()

--turn on output and initiate readings
smu.source.output = smu.ON

-- make all vars local
local secs_old
local frac_old
local secs
local frac
local current_rdg
local delta_hour
local charge_accumulator_mAh = 0.0
local break_sign = 0

-- first reading for times
current_rdg, secs, frac = smu.measure.readwithtime(defbuffer1)

local timestart = secs + frac

-- should be enough for > 20h of data
defbuffer1.capacity = 2000000
defbuffer1.clear()

display.changescreen(display.SCREEN_USER_SWIPE)

while smu.source.output == smu.ON do
    secs_old = secs
    frac_old = frac
    current_rdg, secs, frac = smu.measure.readwithtime(defbuffer1)
	
	-- charge accumulation
	delta_hour = ((secs + frac) - (secs_old + frac_old)) / 3600
    charge_accumulator_mAh = charge_accumulator_mAh + (current_rdg * delta_hour * 1000)
    
    display.settext(display.TEXT1, "Total: "..string.format("%.3f", charge_accumulator_mAh).."mAh")
    display.settext(display.TEXT2, "Time: "..string.format("%d",math.abs(timestart - (secs + frac))).."s     " .. "Cell: "..string.format("%.2f",(defbuffer1.sourcevalues[defbuffer1.endindex])).."V\t" )
    
    -- break if current falls below threshold
    if (math.abs(current_rdg) <= stop_current)then
    	 break_sign = 1
   		end
   	
   	 -- break if stop charge is used and reached
    if (stop_charge != 0 and math.abs(charge_accumulator_mAh) >= stop_charge)then
    	 break_sign = 1
   		end
   	
   	if (break_sign == 1)then
    	 smu.source.output = smu.OFF    	 
   		end
   
    end

-- display the results
display.settext(display.TEXT2, "Time: "..string.format("%d",math.abs(timestart - (secs + frac))).."s     ".. "Done!" )

-- assert the opc bit in status.standard.event register
opc()

