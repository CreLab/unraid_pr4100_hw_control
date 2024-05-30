#!/bin/bash
#
# Main Control script for Unraid on Western Digital PR4100 (not tested on PR2100)
# Based on wdhws v1.0 by TFL (stefaang)
# Based on wdpreinit V1.1.1 by Coltonton
#
# ported to Unraid by CreLab
#    - removed all not important features
#    - create an install script
#    - replaced all not functional commands for Unraid support
#    - make the code more readable
#
# BSD 3 LICENSE (inherited from TFL)
# Thanks unix stackexchange question 231975 & github user @stefaang

####    COMMAND LIST    ####
# THING          COMMAND       USE
# FAN            FAN=64        Enter Hex value 01-64 (1-100%) Use at your own risk, only you can prevent forest fires
# USB/Power LED  LED=13        (See LED Guide)
# PowerLED-Pulse PLS=01        00-off 01-on (cant change color? is always blue?)
# PowerLED-Blink BLK=01        (See LED Guide)
# LCDBacklight   BKL=64        Enter Hex value 00-64 (0-100%)
#

####     LED GUIDE      ####
#XX-usb/pwr
#00-off/off 01-off/blue 02-off/red 03-off/purple 04-off/green 05-off/teal 06-off/yellow 07-off/White
#08-red/off 09-red/blue 0A-red/red 0B-red/purple 0C-red/green 0D-red/teal 0E-red/yellow 0F-red/White
#10-blue/off 11-blue/blue 12-blue/red 13-blue/purple 14-blue/green 15-blue/teal 16-blue/yellow 17-blue/White
#18-purple/off 19-purple/blue 1A-purple/red 1B-purple/purple 1C-purple/green 1D-purple/teal 1E-purple/yellow 1F-purple/White

####    DO NOT TOUCH    ####
fanSpeedMinimum=20       # Minimum allowed fan speed in percent
cpuOptimalTemp=35        # Optimal (desired) temp for CPU (commie C degrees not freedom F :()
cpuMaxTemp=80            # Maximum CPU temp before going full beans
mbMaxTemp=40             # Maximum MB temp before going full beans
diskMaxTemp=40           # Maximum DISK temp before going full beans
pmcMaxTemp=64            # Maximum PMC temp before going full beans
ramMaxTemp=40            # Maximum RAM temp before going full beans
updateRate=25            # How often in seconds to update temps

####        VARS        ####
hwSystem=Linux                # Used to init kernal variable, gets changed based on kernal in get_sys_info()
hwTTY=/dev/ttyS2              # Used to init tty variable, gets changed based on kernal in get_sys_info()
hwHDDArray=()
hwCPUCoreCount=0
hwOverTempAlarm=0
hwOverTempArray=()
hwVerbose=0
hwI2cSupport=0
hwMenu=0

####       FUNCS        ####

vprint(){
    if [ $hwVerbose -eq 1 ]; then
        echo $1
    fi
}

logprint(){
    echo $1
}

check_for_dependencies(){   # Simple just-to-be-safe check that SMART Mon exists
    depenflag=0
    # S.M.A.R.T Drive Utilities
    smartctl -v >/dev/null
    if [[ $? != 1 ]]; then
        logprint " WARNING: SMART not installed please run - sudo apt install smartmontools"
        (( depenflag += 1 ))
    fi

    # lm-Sensors (For temp sensor data )
    sensors -v >/dev/null
    if [[ $? != 0 ]]; then
        logprint " WARNING: lm-sensors not installed please run - sudo apt install smartmontools "
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
        logprint "## PROGRAM TERMINATED ##"
        exit 1
    fi
}

get_sys_info(){         # Get system info based off kernal, as BSD/LINUX has not the same commands
    case "$( uname -s )" in        # Get Linux Kernal (Linux Scale/Core)
        Linux*)  hwSystem=Linux;;
        *)       hwSystem="Other"
    esac

    if [[ ! $hwSystem =~ Linux ]]; then  # If system is not Linux or *BSD Show unsupported message
        logprint "Sorry, This software version for the WD PR4100 Hardware does not support $hwSystem platform."
        logprint "Please create an issue on Github to see about gettin support added"
        exit 1
    fi

    if [ $hwSystem == Linux ]; then      # If Linux Unraid
        logprint "# INFO: Detected Linux Kernel #"  # Show what kernal was identified
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
    logprint "# INFO: Detected internal bay drives: ${hwHDDArray[@]} #"
}

setup_tty() {           # Start UART
    exec 4<$hwTTY 5>$hwTTY
}

setup_i2c() {           # load kernel modules required for the temperature sensor on the RAM modules
    depenflag=0
    tmp=$(ls /usr/lib64/ | grep libi2c.so.0)
    if [[ "$tmp" == "" ]]; then
        depenflag=1
    fi

    if [ $depenflag -gt 0 ]; then
    #   echo "Install missing I2C driver!"
    #   wget https://packages.slackonly.com/pub/packages/14.2-x86_64/system/i2c-tools/i2c-tools-4.1-x86_64-1_slonly.txz
    #   tar -xf i2c-tools-4.1-x86_64-1_slonly.txz
    #   rm i2c-tools-4.1-x86_64-1_slonly.txz
    #   rm -rf ./install
    #   cp ./usr/lib64/libi2c.so.0.1.1 ./usr/lib64/libi2c.so.0
    #   rm ./usr/lib64/libi2c.so.0.1.1
    #   cp -rf ./usr/* /usr/
    #   rm -rf ./usr
    #   modprobe i2c-dev
    #   modprobe i2c-i801
    #   echo "I2C support successfully installed"
    #   hwI2cSupport=1
        logprint "# INFO: I2C not supported - No RAM temparature read out implemented #"
    fi
}

send_cmd() {
    declare -n result="$2"

    setup_tty
    send "$1" 0 res
    send_empty
    exec 4<&- 5>&-      # deconstruct tty file pointers, otherwise this script breaks on sleep

    result="$res"
}

send() {                # Requires input - UART send function to send commands to front panel
    declare -n result="$3"

    start=$EPOCHSECONDS
    ans="ALERT"

    while [ "$ans" = "ALERT" ]
    do
        sleep 0.050

        # send a command to the PMC module and echo the answer
        echo -ne "$1\r" >&5
        read ans <&4

        if (($EPOCHSECONDS - start > 5)); then
            logprint "CMD $1 gives ALERT"
            logprint "Terminate script"
            exit 2
        fi
    done

    # keep this for debugging failing commands
    if [ "$ans" = "ERR" ] || [ "$ans" = "RR" ] || [ "$ans" = "R" ] || [ -z "$ans" ]; then
        # logprint "CMD $1 gives $ans at $2"
        send_empty
        send "$1" $(($2 + 1)) ans
    fi

    # only echo the result for retries ($2 not empty)
    #if [ $2 -gt 0 ]; then
    #    logprint "CMD $1 gives $ans at $2"
    #fi

    result="$ans"
}

send_empty() {          # UART send blank to clear front panel input
    # send a empty command to clear the output
    echo -ne "\r" >&5
    read ignore <&4
}

get_pmc() {             # Requires input - Get a value from the PMC ex. inputing RPM gets fan0's rpm
    declare -n result="$2"

    send_cmd $1 res

    result=$(echo $res | cut -d'=' -f2)
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
        return 0
    fi
}

monitor() {             # TODO / Comment
    # check RPM (fan may get stuck) and convert to dec
    get_pmc RPM rpm
    if [ "$rpm" != "ERR" ] && [ "$rpm" != "ACK" ]; then
        rpmdec=$((0x$rpm))
        if [ "$rpmdec" -lt 400 ]; then
            logprint " WARNING: FAN speed low - current RPM $rpmdec - check fan or clean dust!"
            set_pwr_led FLASH RED
        fi
    else
        logprint " WARNING: PMC RPM return value is $rpm"
    fi

    # Check the Temperature of the PMC and convert to dec
    get_pmc TMP tmp
    if [ "$tmp" != "ERR" ]; then
        tmpdec=$((0x$tmp))
        if [ "$tmpdec" -gt $pmcMaxTemp ]; then
            logprint " WARNING: PMC surpassed maximum ($pmcMaxTemp°C), full throttle activated!"
            hwOverTempAlarm=1
        fi
    else
        logprint " WARNING: PMC TMP return value is $tmp"
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
                logprint " WARNING: Disk$i surpassed maximum ($diskMaxTemp°C), full throttle activated!"
                hwOverTempAlarm=1
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
            logprint " WARNING: CPU Core$i surpassed maximum ($cpuMaxTemp°C), full throttle activated!"
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
        logprint " WARNING: MB temp surpassed maximum ($mbMaxTemp°C), full throttle activated!"
        hwOverTempAlarm=1
    fi

    # Check the installed RAM Temperature
    if [ $hwI2cSupport == 1 ]; then
        vprint "|------ RAM TEMPS -------"
        for i in 0 1; do
            tmp=$(get_ramtemp $i)
            vprint "| RAM$i is $tmp °C"
            if [ "$tmp" -gt $ramMaxTemp ]; then
                logprint " WARNING: RAM$i surpassed maximum ($ramMaxTemp°C), full throttle activated!"
                hwOverTempAlarm=1
            fi
        done
    fi
    vprint "|------------------------"

    if [ ${#hwOverTempArray[@]} -gt 0 ] || [ $hwOverTempAlarm == 1 ]; then
        logprint " WARNING: SYSTEM OVER LIMIT TEMPERATURE(s) FAN SET TO 100% "
        hwOverTempAlarm=1               # Flag System Over Temp-ed
        hwLastOverTemp=$(date)          # Save the time when the system over temped
        send_cmd FAN=64 res                # Full Beans Fan 100%
        set_pwr_led FLASH RED           # Flash Power LED RED to warn
    else
        if [ $setspeed -lt $fanSpeedMinimum ]; then
            vprint "Calculated fan speed below minimum allowed, bumping to $fanSpeedMinimum%..."
            setspeed=$fanSpeedMinimum  # Set the fan to the min allowed
        else
            vprint "Setting fan speed to: $setspeed%"
            send_cmd FAN=$setspeed res        # Set fan to mathed speed if not overtemped
        fi
    fi
}

show_name() {
    # set name message
    # maximum  "xxx xxx xxx xxx "
    send_cmd   "LN1=NAME:           " res

    name=$(hostname)
    send_cmd   "LN2=$name" res
}

show_fan_speed() {
    # set fan speed message
    # maximum  "xxx xxx xxx xxx "
    send_cmd   "LN1=Fan Speed:      " res

    get_pmc RPM rpm
    if [ "$rpm" != ERR ]; then
        rpmdec=$((0x$rpm))"rpm"
    else
        rpmdec=""
    fi

    send_cmd   "LN2=$rpmdec" res
}

show_sys_temp() {
    # set sys temperature message
    # maximum  "xxx xxx xxx xxx "
    version=$(cat /var/log/syslog | grep "System Management Utility version" | awk '{printf $11}')
    send_cmd   "LN1=Ver.: $version" res

    core1=$(get_cpucoretemp $((1-1)))
    core2=$(get_cpucoretemp $((2-1)))
    core3=$(get_cpucoretemp $((3-1)))
    core4=$(get_cpucoretemp $((4-1)))

    core_sum=$(($core1 + $core2 + $core3 + $core4))
    cpu_temp=$(($core_sum / 4))"C"

    mb_temp=$(get_mainboardtemp)"C"

    send_cmd   "LN2=Temp: $cpu_temp $mb_temp" res
}

show_ip() {
    # set ip message
    # maximum  "xxx xxx xxx xxx "
    send_cmd   "LN1=IP Address $1:" res
    ip=$(ifconfig $1 | grep inet | awk '{printf $2}')

    if [ "$ip" == "" ]; then
        send_cmd   "LN2=Disabled        " res
    else
        send_cmd   "LN2=$ip" res
    fi
}

show_drive_status() {
    # set drive status message
    # maximum  "xxx xxx xxx xxx "
    send_cmd   "LN1=Drive Status:   " res

    state_disk1=$(smartctl -a /dev/sdb | grep "SMART overall-health" | awk '{printf $6}')
    state_disk2=$(smartctl -a /dev/sdc | grep "SMART overall-health" | awk '{printf $6}')
    state_disk3=$(smartctl -a /dev/sdd | grep "SMART overall-health" | awk '{printf $6}')
    state_disk4=$(smartctl -a /dev/sde | grep "SMART overall-health" | awk '{printf $6}')

    if [ "$state_disk1" == "PASSED" ] && [ "$state_disk2" == "PASSED" ] && [ "$state_disk3" == "PASSED" ] && [ "$state_disk4" == "PASSED" ]; then
        send_cmd   "LN2=Healthy         " res
    else
        send_cmd   "LN2=Unhealthy       " res
    fi
}

show_capacity() {
    # set capacity message
    # maximum  "xxx xxx xxx xxx "
    send_cmd   "LN1=Capacity:       " res
    fsState=$(cat /var/local/emhttp/var.ini | grep fsState | sed 's/"/ /g' | awk '{printf $2}')

    if [ "$fsState" == "Stopped" ]; then
        send_cmd   "LN2=Array Stopped   " res
    else
        cap=$(df -H | grep "/mnt/user0" | awk '{printf $4}')"B"
        send_cmd   "LN2=$cap free       " res
    fi
}

check_btn_pressed() {
    get_pmc ISR btn
    mod=8

    case $btn in
    40*)
        vprint "Button down pressed!"
        hwMenu=$(( ($hwMenu + 1) % mod ))
        ;;
    20*)
        vprint "Button up pressed!"
        hwMenu=$(( ($hwMenu + (mod - 1)) % mod ))
        ;;
    *)
        return
    esac

    case "$hwMenu" in
    0)
        show_name
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
        show_sys_temp
        ;;
    5)
        show_fan_speed
        ;;
    6)
        show_drive_status
        ;;
    7)
        show_capacity
        ;;
    *)
        vprint "Unknown Menu id $hwMenu!"
        ;;
    esac
}

set_pwr_led(){
    #vprint "PowerMode:$1 - PowerColor:$2 - UsbMode:$3 - UsbColor$4"
    if [ "$1" == SOLID ]; then
        send_cmd BLK=00 res
        send_cmd PLS=00 res
        if [ "$2" == BLU ]; then
            send_cmd LED=01 res
        elif [ "$2" == RED ]; then
            send_cmd LED=02 res
        elif [ "$2" == PUR ]; then
            send_cmd LED=03 res
        elif [ "$2" == GRE ]; then
            send_cmd LED=04 res
        elif [ "$2" == TEA ]; then
            send_cmd LED=05 res
        elif [ "$2" == YLW ]; then
            send_cmd LED=06 res
        elif [ "$2" == WHT ]; then
            send_cmd LED=07 res
        fi
    fi

    if [ "$1" == FLASH ]; then
        send_cmd LED=00 res
        send_cmd PLS=00 res
        if [ "$2" == BLU ]; then
            send_cmd BLK=01 res
        elif [ "$2" == RED ]; then
            send_cmd BLK=02 res
        elif [ "$2" == PUR ]; then
            send_cmd BLK=03 res
        elif [ "$2" == GRE ]; then
            send_cmd BLK=04 res
        elif [ "$2" == TEA ]; then
            send_cmd BLK=05 res
        elif [ "$2" == YLW ]; then
            send_cmd BLK=06 res
        elif [ "$2" == WHT ]; then
            send_cmd BLK=07 res
        fi
    fi

    if [ "$1" == PULSE ]; then
        send_cmd PLS=01 res
        send_cmd LED=00 res
        send_cmd BLK=00 res
    fi
}

init() {
    check_for_dependencies
    get_sys_info
    setup_tty
    setup_i2c

    logprint "# INFO: Getting system status and firmware version! #"
    send_cmd "VER" res
    logprint "$res"
    send_cmd "CFG" res
    logprint "$res"
    send_cmd "STA" res
    logprint "$res"

    show_name
    set_pwr_led SOLID BLU
    logprint "# INIT DONE #"
}

####        MAIN        ####

if [ "$1" = "-v" ]; then
    hwVerbose=1
fi

init

while true; do
    monitor
    vprint "Next temp update in $updateRate seconds"

    # check for button presses
    for i in $(seq $updateRate); do
        sleep 0.5
        check_btn_pressed
    done
done