#!/bin/bash

####         Includes        ####

source ./debug.sh
source ./serial.sh

####      Global Defines     ####

cpuOptimalTemp=40        # Optimal (desired) temp for CPU (commie C degrees not freedom F :()
cpuMaxTemp=70            # Maximum CPU temp before going full beans
mbMaxTemp=70             # Maximum MB temp before going full beans
diskMaxTemp=60           # Maximum DISK temp before going full beans
pmcMaxTemp=70            # Maximum PMC temp before going full beans

fanSpeedMinimum=20       # Minimum allowed fan speed in percent

hwHDDArray=()
hwOverTempAlarm=0
hwSystem=Linux           # Used to init kernal variable, gets changed based on kernal in get_sys_info()

####        Driver Function        ####

init_linux_drivers()
{
    init_serial

    for file in /dev/disk/by-id/ata*
    do
        if [[ $file != *"-part"* ]]; then
            tmparr+=( $( ls -l "/dev/disk/by-id/ata-${file:20:100}" | awk '{print $11}' | cut -b 7-10 )  )
            readarray -t hwHDDArray < <(for a in "${tmparr[@]}"; do echo "/dev/$a"; done | sort)
        fi
    done
    verbose "# INFO: Detected internal bay drives: ${hwHDDArray[@]} #"
}

####        Function         ####

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
    read_serial "RPM" rpm
	verbose "| RPM is $rpm"
    if [ "$rpm" != "ERR" ] && [ "$rpm" != "ACK" ]; then
        rpmdec=$((0x$rpm))
        if [ "$rpmdec" -lt 400 ]; then
            verbose " WARNING: FAN speed low - current RPM $rpmdec - check fan or clean dust!"
            set_pwr_led FLASH RED
        fi
    else
        verbose " WARNING: PMC RPM return value is $rpm"
    fi

    read_serial "TMP" tmp
	verbose "| TMP is $tmp"
    if [ "$tmp" != "ERR" ]; then
        tmpdec=$((0x$tmp))
        if [ "$tmpdec" -gt $pmcMaxTemp ]; then
            verbose " WARNING: PMC surpassed maximum ($pmcMaxTemp°C), full throttle activated!"
            hwOverTempAlarm=1
        fi
    else
        verbose " WARNING: PMC TMP return value is $tmp"
    fi

    verbose "|------ DISK TEMPS ------"
    for i in "${hwHDDArray[@]}" ; do
        tmp=$(get_disktemp $i)
        waserror=$(echo $?)
        if [ $waserror -ne "0" ]; then
            if [ $waserror == 2 ]; then
                ret=standby
            else
                ret=Error
            fi
            verbose "| Drive ${i:5:5} is in $ret status"
        else
            verbose "| Drive ${i:5:15} is $tmp °C"
            if [ ! -z $tmp ] && [ $tmp -gt $diskMaxTemp ]; then
                verbose " WARNING: Disk$i surpassed maximum ($diskMaxTemp°C), full throttle activated!"
                hwOverTempAlarm=1
            fi
        fi
    done

    highestcpucoretemp=0
    verbose "|---- CPU CORE TEMPS ----"
	
	core1=$(get_cpucoretemp $((1-1)))
    core2=$(get_cpucoretemp $((2-1)))
    core3=$(get_cpucoretemp $((3-1)))
    core4=$(get_cpucoretemp $((4-1)))

    core_sum=$(($core1 + $core2 + $core3 + $core4))
    tmp=$(($core_sum / 4))
	verbose "| CPU is $tmp °C"
	if [ $tmp -gt $cpuMaxTemp ]; then
		verbose " WARNING: CPU surpassed maximum ($cpuMaxTemp°C), full throttle activated!"
		hwOverTempAlarm=1
	fi
	if [ $tmp -gt $highestcpucoretemp ]; then
		highestcpucoretemp=$tmp
	fi

    verbose "| Highest CPU core temp is $highestcpucoretemp °C"

    newtmp=$(("$highestcpucoretemp"-"$cpuOptimalTemp"))
    setspeed=$(("$newtmp"*2+"$fanSpeedMinimum"-5))

    verbose "|---- MAINBOARD TEMP ----"
    tmp=$(get_mainboardtemp)
    verbose "| Mainbaord is $tmp °C"
    if [ $tmp -gt $mbMaxTemp ]; then
        verbose " WARNING: MB temp surpassed maximum ($mbMaxTemp°C), full throttle activated!"
        hwOverTempAlarm=1
    fi

    verbose "|------------------------"

    if [ $hwOverTempAlarm == 1 ]; then
        verbose " WARNING: SYSTEM OVER LIMIT TEMPERATURE(s) FAN SET TO 100% "
        hwOverTempAlarm=0
        hwLastOverTemp=$(date)
        send_cmd FAN=64 res
        set_pwr_led FLASH RED
    else
        if [ $setspeed -lt $fanSpeedMinimum ]; then
            verbose "Calculated fan speed below minimum allowed, bumping to $fanSpeedMinimum%..."
            setspeed=$fanSpeedMinimum
        fi
		
		verbose "Setting fan speed to: $setspeed%"
		send_cmd FAN=$setspeed res
    fi
}