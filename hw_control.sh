#!/bin/bash
#
# Main Control script for Free/TrueNAS CORE & SCALE on Western Digital PR2100?/PR4100 
# Based off wdhws v1.0 by TFL (stefaang)
#
# wdpreinit V1.1.1 by Coltonton
#    - Fixed Some Typos/Cleaned up while I was here
#    - Added Support For TrueNAS Scale as well as TrueNAS CORE
#    - More Comments = More Better
#  
# BSD 3 LICENSE (inherited from TFL)
# Thanks unix stackexchange question 231975 & github user @stefaang

############### COMMAND LIST ###############
# THING          COMMAND       USE
# FAN            FAN=64        Enter Hex value 01-64 (1-100%) Use at your own risk, only you can prevent forest fires
# USB/Power LED  LED=13        (See LED Guide)
# PowerLED-Pulse PLS=01        00-off 01-on (cant change color? is always blue?)
# PowerLED-Blink BLK=01        (See LED Guide)
# LCDBacklight   BKL=64        Enter Hex value 00-64 (0-100%)
#                
# 
# To complete?

################ LED GUIDE #################
#XX-usb/pwr
#00-off/off 01-off/blue 02-off/red 03-off/purple 04-off/green 05-off/teal 06-off/yellow 07-off/White
#08-red/off 09-red/blue 0A-red/red 0B-red/purple 0C-red/green 0D-red/teal 0E-red/yellow 0F-red/White
#10-blue/off 11-blue/blue 12-blue/red 13-blue/purple 14-blue/green 15-blue/teal 16-blue/yellow 17-blue/White
#18-purple/off 19-purple/blue 1A-purple/red 1B-purple/purple 1C-purple/green 1D-purple/teal 1E-purple/yellow 1F-purple/White

###########################################################################
#########################   DO NOT TOUCH   ################################
###########################################################################
fanSpeedMinimum=20 # Minimum allowed fan speed in percent
cpuOptimalTemp=35  # Optimal (desired) temp for CPU (commie C degrees not freedom F :()
cpuMaxTemp=80      # Maximum CPU temp before going full beans
mbMaxTemp=40       # Maximum MB temp before going full beans
diskMaxTemp=40     # Maximum DISK temp before going full beans
pmcMaxTemp=64      # Maximum PMC temp before going full beans
ramMaxTemp=40      # Maximum RAM temp before going full beans
updateRate=25      # How often in seconds to update temps

###########################################################################
#############################   VARS   ####################################
###########################################################################
hwSystem=Linux                # Used to init kernal variable, gets changed based on kernal in get_sys_info()
hwTTY=/dev/ttyS2              # Used to init tty variable, gets changed based on kernal in get_sys_info()
hwHDDArray=()
hwCPUCoreCount=0
hwOverTempAlarm=0
hwOverTempArray=()
hwVerbose=0
hwI2cSupport=0

###########################################################################
#############################   FUNCS   ###################################
###########################################################################

vprint(){
    if [ $hwVerbose -eq 1 ]; then
        echo $1
    fi
}

check_for_dependencies(){   # Simple just-to-be-safe check that SMART Mon exists
    depenflag=0
    # S.M.A.R.T Drive Utilities
    smartctl -v >/dev/null
    if [[ $? != 1 ]]; then
        echo " WARNING: SMART not installed please run - sudo apt install smartmontools"
        (( depenflag += 1 ))
    fi

    # lm-Sensors (For temp sensor data )
    sensors -v >/dev/null
    if [[ $? != 0 ]]; then
        echo " WARNING: lm-sensors not installed please run - sudo apt install smartmontools "
        (( depenflag+=2 ))
    fi
    
    if [ $depenflag -gt 0 ]; then
        #printf "Would you like me to install? y/n:"
        #read resp
        #if [[ $resp == "y"] && [ $depenflag -gt 0 ]; then
        #    if [ $depenflag -eq 1 ]; then
        #        sudo apt install smartmontools
        #    elif [ $depenflag -eq 2 ]; then
        #        sudo apt install lm-sensors
        #    elif [ $depenflag -eq 3 ]; then
        #        sudo apt install smartmontools && sudo apt install lm-sensors
        #    fi
        #fi
        echo "## PROGRAM TERMINATED ##"
        exit
    fi
}

get_sys_info(){         # Get system info based off kernal, as BSD/LINUX has not the same commands
    case "$( uname -s )" in        # Get Linux Kernal (Linux Scale/Core)
        Linux*)  hwSystem=Linux;;
        *)       hwSystem="Other"
    esac
    
    if [[ ! $hwSystem =~ Linux ]]; then  # If system is not Linux or *BSD Show unsupported message
        echo "Sorry, This software version for the WD PR4100 Hardware does not support $hwSystem platform."
        echo "Please create an issue on Github to see about gettin support added"
        exit 1
    fi     
    
    if [ $hwSystem == Linux ]; then      # If Linux Unraid
        vprint "# GETINFO: Detected Linux Kernel #"  # Show what kernal was identified
        hwTTY=/dev/ttyS2                           # Linux uses much cooler (telatype) /dev/hwTTYS2 for i2C comms to PR4100 front hardware
        get_int_drives                             # Get location of ONLY internal bay drives
        hwCPUCoreCount=$(nproc)                    # Get how many CPU cores
    fi
}

get_int_drives(){       # Gets the location of the internal bay HDD's
    for file in /dev/disk/by-id/ata*       # With each HDD decice thats ata (Internal Sata)
    do
        if [[ $file != *"-part"* ]]; then  # Filter out '-part$' devices as they are the same
            tmparr+=( $( ls -l "/dev/disk/by-id/ata-${file:20:100}" | awk '{print $11}' | cut -b 7-10 )  ) # Get the /dev location
            readarray -t hwHDDArray < <(for a in "${tmparr[@]}"; do echo "/dev/$a"; done | sort) # Sort
        fi
    done
    vprint "# GETINFO: Detected internal bay drives: ${hwHDDArray[@]} #"
}

setup_tty() {           # Start UART
    exec 4<$hwTTY 5>$hwTTY
}

setup_i2c() {           # load kernel modules required for the temperature sensor on the RAM modules
    depenflag=0
    tmp=$(ls /usr/lib64/ | grep libi2c.so.0)
    if [[ "$tmp" == "" ]]; then
        (( depenflag += 1 ))
    fi
    
    #if [ $depenflag -gt 0 ]; then
    #    echo "Install missing I2C driver!"
    #    wget https://packages.slackonly.com/pub/packages/14.2-x86_64/system/i2c-tools/i2c-tools-4.1-x86_64-1_slonly.txz
    #    tar -xf i2c-tools-4.1-x86_64-1_slonly.txz
    #    rm i2c-tools-4.1-x86_64-1_slonly.txz
    #    rm -rf ./install
    #    cp ./usr/lib64/libi2c.so.0.1.1 ./usr/lib64/libi2c.so.0
    #    rm ./usr/lib64/libi2c.so.0.1.1
    #    cp -rf ./usr/* /usr/             
    #    rm -rf ./usr        
    #    modprobe i2c-dev
    #    modprobe i2c-i801
    #    echo "I2C support successfully installed"
    #    depenflag=0
    #fi
    
    if [ $depenflag -gt 0 ]; then    
        echo "## I2C NOT SUPPORTED ##"
    else
        hwI2cSupport=1
    fi
}

send() {                # Requires input - UART send function to send commands to front panel
    setup_tty
    # send a command to the PMC module and echo the answer
    echo -ne "$1\r" >&5
    read ans <&4
    if [ "$ans" = "ALERT" ]; then
        echo -ne ALERT >&2
        exit 2 
    else
        # keep this for debugging failing commands
        if [ "$ans" = "ERR" ] || [ -z "$ans" ]; then
            echo "CMD $1 gives ERR at $2" >&2
            send_empty
            ans=$(send "$1" $(($2 + 1)))
            #exit 1
        fi
    fi
    # only echo the result for retries ($2 not empty)
    if [ ! -z $2 ]; then 
        echo "CMD $1 gives '$ans' at $2" >&2 
    fi 
    
    send_empty
    # deconstruct tty file pointers, otherwise this script breaks on sleep 
    exec 4<&- 5>&-

}

send_empty() {          # i2c send blank to clear front panel input
    # send a empty command to clear the output
    echo -ne "\r" >&5
    read ignore <&4
}

get_pmc() {             # Requires input - Get a value from the PMC ex. inputing RPM gets fan0's rpm
    send $1 | cut -d'=' -f2
}

get_disktemp() {        # Requires input - Get the disks temperature only if it is active, else return status
    drivesel=$1 #$1  # For some reason i need this and cant put it in later? Makes i2c break somehow...
    smartctl -n standby -A $drivesel > /dev/null # Run command to get disk status
    getstatus=$(echo $?)                                 # Get drive exit status
    if [ "$getstatus" == "0" ]; then  # If the status of the drive is active, get its temperature
        smartctl -n standby -A $drivesel | grep Temperature_Celsius | awk '{print $10}'
    else  # If the status of the drive is not active, return the exit status of the drive. Maybe its asleep/standby                
        return $getstatus
    fi
}

get_cpucoretemp() {
    # get the CPU temperature and strip of the Celsius
    if [ $hwSystem == Linux ]; then
        temp=$(sensors | grep "Core $1")
        
        if [ "$temp" == "" ]; then
            sensors | grep "CPU Temp" | awk '{print $3}' | cut -d'.' -f1 | cut -b 2-3
        else
            sensors | grep "Core $1" | awk '{print $3}' | cut -d'.' -f1 | cut -b 2-3
        fi
    fi
}

get_mainboardtemp() {
    # get the mainbaord temperature and strip of the Celsius
    if [ $hwSystem == Linux ]; then
        temp=$(sensors | grep "temp1")
        
        if [ "$temp" == "" ]; then
            sensors | grep "MB Temp" | awk '{print $3}' | cut -d'.' -f1 | cut -b 2-3
        else
            sensors | grep "temp1" | awk '{print $2}' | cut -d'.' -f1 | cut -b 2-3
        fi
    fi
}

get_ramtemp() {
    # get the memory temperature from the I2C sensor
    if [ $hwI2cSupport == 1 ]; then
        # smbmsg -s 0x98 -c 0x0$1 -i 1 -F %d
	#else
        echo "0"
    fi
}

monitor() {             # TODO / Comment
    # check RPM (fan may get stuck) and convert hex to dec
    #readfanpercent=$(get_pmc FAN)
    rpm=$((0x$(get_pmc RPM)))
    vprint "FAN Speed: $rpm"
	if [ "$rpm" -lt 400 ]; then
		echo " WARNING: FAN speed low - current RPM $rpm - check fan or clean dust!"
		set_pwr_led FLASH RED
	fi
    
    # Check the Temperature of the PMC and convert to hex 
	tmp=$((0x$(get_pmc TMP)))
    if [ "$tmp" -gt $pmcMaxTemp ]; then
        echo " WARNING: PMC surpassed maximum ($pmcMaxTemp°C), full throttle activated!"
        hwOverTempAlarm=1 
        #hwOverTempArray+=("PMC $tmp°C/$pmcMaxTemp°C")"
    fi

    # Check the Hard Drive Temperature [adjust this for PR2100!!] (<- IDK what that means)
    vprint "|------ DISK TEMPS ------"
    for i in "${hwHDDArray[@]}" ; do
        tmp=$(get_disktemp $i)
        waserror=$(echo $?)
        if [ $waserror -ne "0" ]; then
            if [ $waserror == 2 ]; then
                ret=standby
            else
                ret=Error
            fi
            vprint "| Drive ${i:5:5} is in $ret status"
        else
            vprint "| Drive ${i:5:15} is $tmp °C"
            if [ ! -z $tmp ] && [ $tmp -gt $diskMaxTemp ]; then
                echo " WARNING: Disk$i surpassed maximum ($diskMaxTemp°C), full throttle activated!" 
                hwOverTempAlarm=1
                #hwOverTempArray+=("HDD$i $tmp°C/$hddMaxTemp°C")
            fi
        fi
    done

    # Check the Temperature of the CPU
    highestcpucoretemp=0
    vprint "|---- CPU CORE TEMPS ----"
    for i in $(seq $hwCPUCoreCount); do
        tmp=$(get_cpucoretemp $((i-1)))
        vprint "| CPU Core$i is $tmp °C"
        if [ $tmp -gt $cpuMaxTemp ]; then
            echo " WARNING: CPU Core$i surpassed maximum ($cpuMaxTemp°C), full throttle activated!"
            #hwOverTempArray+=("CPU$i $tmp°C/$cpuMaxTemp°C")
            hwOverTempAlarm=1
        fi
        if [ $tmp -gt $highestcpucoretemp ]; then
            highestcpucoretemp=$tmp
        fi
    done
    
    vprint "| Highest CPU core temp is $highestcpucoretemp °C"
    
    #                                                       max-opperating=a   fullfan-minfan=b    b/a= fan percent per degree
    #Max-80 Optimal-35 1.5% = for every degree above 30%      80-35=45         100-30=70             70/45=1.5
    newtmp=$(("$highestcpucoretemp"-"$cpuOptimalTemp"))  #MaxTemp 
    setspeed=$(("$newtmp"*2+"$fanSpeedMinimum"-5))
    
    # Check the Temperature of the mainbaord
    vprint "|---- MAINBOARD TEMP ----"
    tmp=$(get_mainboardtemp)
    vprint "| Mainbaord is $tmp °C"
    if [ $tmp -gt $mbMaxTemp ]; then
        echo " WARNING: MB temp surpassed maximum ($mbMaxTemp°C), full throttle activated!"
        #hwOverTempArray+=("MB temp $tmp°C/$mbMaxTemp°C")
        hwOverTempAlarm=1
    fi
 
    # Check the installed RAM Temperature
	if [ $hwI2cSupport == 1 ]; then
		vprint "|------ RAM TEMPS -------"
		for i in 0 1; do
			tmp=$(get_ramtemp $i)
			vprint "| RAM$i is $tmp °C"
			if [ "$tmp" -gt $ramMaxTemp ]; then
				echo " WARNING: RAM$i surpassed maximum ($ramMaxTemp°C), full throttle activated!"
				#hwOverTempArray+=("RAM $tmp°C/$ramMaxTemp°C")
				hwOverTempAlarm=1
			fi
		done
	fi
    vprint "|------------------------"

    if [ ${#hwOverTempArray[@]} -gt 0 ] || [ $hwOverTempAlarm == 1 ]; then
        echo " WARNING: SYSTEM OVER LIMIT TEMPERATURE(s) FAN SET TO 100% "
        hwOverTempAlarm=1               # Flag System Over Temp-ed
        hwLastOverTemp=$(date)          # Save the time when the system over temped
        send FAN=64                     # Full Beans Fan 100%
        set_pwr_led FLASH RED           # Flash Power LED RED to warn
    else
        if [ $setspeed -lt $fanSpeedMinimum ]; then
            vprint "Calculated fan speed below minimum allowed, bumping to $fanSpeedMinimum%..."
            setspeed=$fanSpeedMinimum  # Set the fan to the min allowed
        else
            vprint "Setting fan speed to: $setspeed%"
            send FAN=$setspeed         # Set fan to mathed speed if not overtemped
        fi
    fi
}

show_welcome() {
    # set welcome message
    # maximum  "xxx xxx xxx xxx "
    send "LN1=     UNRAID "
    send "LN2=WD PR4100 Server"
}

show_fan_speed() {
    # set fan speed message
    # maximum  "xxx xxx xxx xxx "
    send "LN1=Fan Speed:  "

    rpm=$((0x$(get_pmc RPM)))"rpm"

    send "LN2=$rpm"
}

show_sys_temp() {
    # set fan speed message
    # maximum  "xxx xxx xxx xxx "
    send "LN1=CPU:    MB:"

    core1=$(get_cpucoretemp $((1-1)))
    core2=$(get_cpucoretemp $((2-1)))
    core3=$(get_cpucoretemp $((3-1)))
    core4=$(get_cpucoretemp $((4-1)))
    
    cpu_temp=$(($core1 + $core2 + $core3 + $core4))"°C"
    mb_temp=$(get_mainboardtemp)"°C"

    send "LN2=$cpu_temp    $mb_temp"
}

show_ip() {
    send "LN1=Interface $1"
    ip=$(ifconfig $1 | grep inet | awk '{printf $2}')
    
    if [ "$ip" == "" ]; then
        send "LN2=Not connected"
    else
        send "LN2=$ip"
    fi
}

check_btn_pressed() {
    btn=$(get_pmc ISR) 
    
    case $btn in
    20*)
        vprint "Button up pressed!"
        menu=$(( ($menu + 1) % 6 ))
        ;;
    40*) 
        vprint "Button down pressed!"
        menu=$(( ($menu + 2) % 6 ))
        ;;
    *)
        return    
    esac
    
    case "$menu" in
    0)
        show_welcome
        ;;
    1)
        show_ip "br0"
        ;;
    2)
        show_ip "eth0"
        ;;
    3)
        show_ip "eth1"
        ;;
    4)
        show_fan_speed
        ;;
    5)
        show_sys_temp
        ;;
    # if you add menu items here, update mod 6 uses above    
    esac
}

set_pwr_led(){
    #vprint "PowerMode:$1 - PowerColor:$2 - UsbMode:$3 - UsbColor$4"
    if [ "$1" == SOLID ]; then
        send BLK=00
        send PLS=00
        if [ "$2" == BLU ]; then
            send LED=01
        elif [ "$2" == RED ]; then
            send LED=02
        elif [ "$2" == PUR ]; then
            send LED=03
        elif [ "$2" == GRE ]; then
            send LED=04
        elif [ "$2" == TEA ]; then
            send LED=05
        elif [ "$2" == YLW ]; then
            send LED=06
        elif [ "$2" == WHT ]; then
            send LED=07
        fi
    fi
    if [ "$1" == FLASH ]; then
        send LED=00
        send PLS=00
        if [ "$2" == BLU ]; then
            send BLK=01
        elif [ "$2" == RED ]; then
            send BLK=02
        elif [ "$2" == PUR ]; then
            send BLK=03
        elif [ "$2" == GRE ]; then
            send BLK=04
        elif [ "$2" == TEA ]; then
            send BLK=05
        elif [ "$2" == YLW ]; then
            send BLK=06
        elif [ "$2" == WHT ]; then
            send BLK=07
        fi
    fi

    if [ "$1" == PULSE ]; then
        send PLS=01
        send LED=00
        send BLK=00
    fi
}

init() {
    check_for_dependencies
    get_sys_info
    setup_tty
    setup_i2c

    echo "# GETINFO: Getting system status and firmware! #"
    send VER
    send CFG
    send STA
    
    show_welcome
    set_pwr_led SOLID BLU
    echo "# INIT DONE #"
}

######################
#        MAIN        #
######################

if [ "$1" = "-v" ]; then
    hwVerbose=1
fi

init

while true; do
    # adjust fan speed every 30 seconds
    monitor
    vprint "Next temp update in $updateRate seconds"

    # check for button presses
    for i in $(seq $updateRate); do 
        sleep 0.25
        check_btn_pressed
    done
done
