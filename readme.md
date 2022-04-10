# CC/CV Charging and *Discharging* for the Keithley 2450 Source Measure Unit (TSP Script)

* **Charging** and ***discharging*** in Constant Current / Constant Voltage mode

* Measures charge in **mAh** (Milli Ampere hours)

* Possible to charge / discharge only a defined amount

* remotely controllable

![](doc\application.png)

In the example above, the script is used to evaluate a fuel gauge in conjunction with a 1000mAh Li-Po cell.

## What is it good for?

This script is especially made for fast, but accurate discharging to get the usable battery capacity for your real-world application.

![](doc\disc_curves.png)

Take a look at above exemplary discharge curves for a Li-Ion battery. Let's say your application draws no more than 40mA and works down to 3.5V. You want to know how long your unknown battery lasts for this application. 

So you'll probably hook it up to your constant current load and set it to maybe 500mA with 3.5V discharge stop. Will you get the correct amount of usable battery capacity with this method? <u>No!</u> Because of the internal series resistance of the cell, you will measure the amount of capacity to the point where the cell voltage drops below 3.5V at *500mA* current, not at *40mA* ! From this point on, the cell will be good for some more runtime that keeps hidden from you with this method.

So maybe then, you would discharge with 40mA constant current, until the point marked with an arrow in the above picture is reached. If you got more than 6 hours time, that's no problem. But what if your application only needs 10mA? How patient will you be?

This script solves this problem by discharging with the same method as CC/CV charging. It will, at first, fast discharge with a maximum user settable current until the minimum user defined battery voltage is reached. Then it sinks with constant voltage until a defined minimum current is reached. After that you can read the total capacity that your application can use.

## Usage example

Let's say you got the following application with:

* A Li-Ion Cell with 1000mAh nominal capacity

* VCC with 3.3V out from a LDO with 200mV drop

* The application uses not more than 40mA

So, the parameters should be:

* Maximum discharge current: 1000mA (1C)

* UVLO (under voltage lock out) Voltage: 3.5V (VCC + LDO drop)

* End current 40mA

This is how you set up the script. First transfer the script to your SMU and start it with

Menu - Scripts - Run

![](doc\run_script.png)

Then enter the voltage where you will charge / discharge the cell to. In this case it is the UVLO threshold as calculated above.

![](doc\target_voltage.png)

You'll have to set the voltage range manually, since the script has no means to know the open circuit voltage (OCV) of your cell. For this application, since the OCV of a lithium cell is usually 4.2V, the range of 20V is chosen.

![](doc\range.png) 

Next, you'll be asked for a current limit. For the above case with a 1000mAh cell, a discharge current of 1C (1000mA) is a safe value.

![](doc\curr_limit.png)

After that you'll enter a stop current where charging or discharging ends. Four our example we use the application current of 40mA.

![](doc\stop_curr.png)

After that you'll get a question prompt if you want to set a specific amount of charge that should be charged or discharged. Since, for our example, we want to fully drain the battery, we choose No.

![](doc\disc_liimit.png)

After this, you'll be prompted to confirm.

![](doc\confirm.png)

With OK, the script starts discharging. 

![](doc\run_abort.png)

After completion it will display that it has finished with the total time and to total counted charge. You can always abort the script by turning the output OFF.

## Starting the script remotely

It is possible to start the script remotely, for instance from a python application. For this you may set some global variables:

* **cccv_target_voltage** - target voltage

* **cccv_target_voltage_range** - voltage measurement range (0.2, 2, 20 or 200)

* **cccv_current_limit** - maximum charge/discharge current

* **cccv_stop_current** - stop current

* **cccv_stop_charge** - if you want to charge/discharge a specific amount set this, or set to nil if you want no limit

If you start the script with **CC_CV()** and all the global values are set, the confirmation prompt will be skipped and the script starts immediately.

The script will assert the operation complete bit in the status register after completion, so you can poll for it.

Thank you, **Andrea C.** from the Keithley support forum for helping me to get this working!

```python
import pyvisa
import time
resource_mgr = pyvisa.ResourceManager()

smu = resource_mgr.open_resource("USB0::0x05E6::0x2450::04425317::0::INSTR")

# set up status reporting.
# see: https://forum.tek.com/viewtopic.php?f=263&t=142996#p290699
smu.write("status.clear()")
smu.write("status.standard.enable = 1")  # 1 = status.standard.OPC
smu.write("status.request_enable = status.ESB")  # event summary bit

smu.write("cccv_target_voltage = 0.5")
smu.write("cccv_target_voltage_range = 20")
smu.write("cccv_current_limit = 0.5")
smu.write("cccv_stop_current = 0.01")
smu.write("cccv_stop_charge = 3")
# set to nil if you want no charge limit
# smu.write("cccv_stop_charge = nil")

smu.write("CC_CV()") # start the script

while True:
    status_byte = int(smu.read_stb())
    if (status_byte and 64) == 64:  # check for opc bit
        break
    time.sleep(0.5)  # poll 0.5s interval

print("finished")
```
