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

####    Tempreture Ranges    ####
cpuOptimalTemp=40        # Optimal (desired) temp for CPU (commie C degrees not freedom F :()
cpuMaxTemp=70            # Maximum CPU temp before going full beans
mbMaxTemp=70             # Maximum MB temp before going full beans
diskMaxTemp=60           # Maximum DISK temp before going full beans
pmcMaxTemp=70            # Maximum PMC temp before going full beans

####     Config Parameter    ####
fanSpeedMinimum=20       # Minimum allowed fan speed in percent
updateRate=25            # How often in seconds to update temps

hwSystem=Linux                # Used to init kernal variable, gets changed based on kernal in get_sys_info()
hwTTY=/dev/ttyS2              # Used to init tty variable, gets changed based on kernal in get_sys_info()
hwHDDArray=()
hwOverTempAlarm=0
hwVerbose=0
hwMenu=0

####       Functions        ####

vprint()
{
    if [ $hwVerbose -eq 1 ]; then
        echo $1
    fi
}

logprint()
{
    echo $1
}

check_for_dependencies()
{
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
}

get_sys_info()
{
    case "$( uname -s )" in
        Linux*)  hwSystem=Linux;;
        *)       hwSystem="Other"
    esac

    if [ $hwSystem == Linux ]; then
        logprint "# INFO: Detected Linux Kernel #"
        hwTTY=/dev/ttyS2
        get_int_drives
    else    
        logprint "Sorry, This software version for the WD PR4100 Hardware does not support $hwSystem platform."
        logprint "Please create an issue on Github to see about gettin support added"
        exit 1
    fi
}

get_int_drives()
{
    for file in /dev/disk/by-id/ata*
    do
        if [[ $file != *"-part"* ]]; then
            tmparr+=( $( ls -l "/dev/disk/by-id/ata-${file:20:100}" | awk '{print $11}' | cut -b 7-10 )  )
            readarray -t hwHDDArray < <(for a in "${tmparr[@]}"; do echo "/dev/$a"; done | sort)
        fi
    done
    logprint "# INFO: Detected internal bay drives: ${hwHDDArray[@]} #"
}

setup_tty()
{
    exec 4<$hwTTY 5>$hwTTY
}

send_cmd()
{
    declare -n result="$2"

    setup_tty
    send "$1" 0 res
    send_empty
    exec 4<&- 5>&-

    result="$res"
}

send()
{
    declare -n result="$3"

    start=$EPOCHSECONDS
    ans="ALERT"

    while [ "$ans" = "ALERT" ]
    do
        sleep 0.050

        # send a command to the PMC module and echo the answer
        setup_tty
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

    result="$ans"
}

send_empty()
{
    echo -ne "\r" >&5
    read ignore <&4
}

get_pmc()
{
    declare -n result="$2"
    send_cmd $1 res
    result=$(echo $res | cut -d'=' -f2)
}

get_disktemp()
{
    drivesel=$1
    smartctl -n standby -A $drivesel > /dev/null
    getstatus=$(echo $?)
    if [ "$getstatus" == "0" ]; then
        smartctl -n standby -A $drivesel | grep Temperature_Celsius | awk '{print $10}'
    else
        return $getstatus
    fi
}

get_cpucoretemp()
{
    if [ $hwSystem == Linux ]; then
        temp=$(sensors | grep "Core $1")

        if [ "$temp" == "" ]; then
            sensors | grep "CPU Temp" | awk '{print $3}' | cut -d'.' -f1 | cut -b 2-3
        else
            sensors | grep "Core $1" | awk '{print $3}' | cut -d'.' -f1 | cut -b 2-3
        fi
    fi
}

get_mainboardtemp()
{
    if [ $hwSystem == Linux ]; then
        temp=$(sensors | grep "temp1")

        if [ "$temp" == "" ]; then
            sensors | grep "MB Temp" | awk '{print $3}' | cut -d'.' -f1 | cut -b 2-3
        else
            sensors | grep "temp1" | awk '{print $2}' | cut -d'.' -f1 | cut -b 2-3
        fi
    fi
}

monitor()
{
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

    highestcpucoretemp=0
    vprint "|---- CPU CORE TEMPS ----"
	
	core1=$(get_cpucoretemp $((1-1)))
    core2=$(get_cpucoretemp $((2-1)))
    core3=$(get_cpucoretemp $((3-1)))
    core4=$(get_cpucoretemp $((4-1)))

    core_sum=$(($core1 + $core2 + $core3 + $core4))
    tmp=$(($core_sum / 4))
	vprint "| CPU is $tmp °C"
	if [ $tmp -gt $cpuMaxTemp ]; then
		logprint " WARNING: CPU surpassed maximum ($cpuMaxTemp°C), full throttle activated!"
		hwOverTempAlarm=1
	fi
	if [ $tmp -gt $highestcpucoretemp ]; then
		highestcpucoretemp=$tmp
	fi

    vprint "| Highest CPU core temp is $highestcpucoretemp °C"

    newtmp=$(("$highestcpucoretemp"-"$cpuOptimalTemp"))
    setspeed=$(("$newtmp"*2+"$fanSpeedMinimum"-5))

    vprint "|---- MAINBOARD TEMP ----"
    tmp=$(get_mainboardtemp)
    vprint "| Mainbaord is $tmp °C"
    if [ $tmp -gt $mbMaxTemp ]; then
        logprint " WARNING: MB temp surpassed maximum ($mbMaxTemp°C), full throttle activated!"
        hwOverTempAlarm=1
    fi

    vprint "|------------------------"

    if [ $hwOverTempAlarm == 1 ]; then
        logprint " WARNING: SYSTEM OVER LIMIT TEMPERATURE(s) FAN SET TO 100% "
        hwOverTempAlarm=1
        hwLastOverTemp=$(date)
        send_cmd FAN=64 res
        set_pwr_led FLASH RED
    else
        if [ $setspeed -lt $fanSpeedMinimum ]; then
            vprint "Calculated fan speed below minimum allowed, bumping to $fanSpeedMinimum%..."
            setspeed=$fanSpeedMinimum
        else
            vprint "Setting fan speed to: $setspeed%"
            send_cmd FAN=$setspeed res
        fi
    fi
}

show_name()
{
    send_cmd   "LN1=NAME:           " res

    name=$(hostname)
    send_cmd   "LN2=$name" res
}

show_fan_speed()
{
    send_cmd   "LN1=Fan Speed:      " res

    get_pmc RPM rpm
    if [ "$rpm" != ERR ]; then
        rpmdec=$((0x$rpm))"rpm"
    else
        rpmdec=""
    fi

    send_cmd   "LN2=$rpmdec" res
}

show_sys_temp()
{
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

show_ip()
{
    send_cmd   "LN1=IP Address $1:" res
    ip=$(ifconfig $1 | grep inet | awk '{printf $2}')

    if [ "$ip" == "" ]; then
        send_cmd   "LN2=Disabled        " res
    else
        send_cmd   "LN2=$ip" res
    fi
}

show_drive_status()
{
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

show_capacity()
{
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

    vprint "Button $btn"

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

####        Main Function        ####

if [ "$1" = "-v" ]; then
    hwVerbose=1
fi

check_for_dependencies
get_sys_info

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

while true; do
    monitor
    vprint "Next temp update in $updateRate seconds"

    for i in $(seq $updateRate); do
        sleep 0.5
        check_btn_pressed
    done
done
