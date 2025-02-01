#!/bin/bash

####         Includes        ####

source ./scripts/debug.sh
source ./scripts/serial.sh

####      Global Defines     ####

####        Function         ####

show_name()
{
    name=$(hostname)

    write_serial   "LN1=NAME:           " res   
    write_serial   "LN2=$name" res
}

show_fan_speed()
{
    read_serial RPM rpm
    if [ "$rpm" != ERR ]; then
        rpmdec=$((0x$rpm))"rpm"
    else
        rpmdec=""
    fi
	
    write_serial   "LN1=Fan Speed:      " res
    write_serial   "LN2=$rpmdec" res
}

show_sys_temp()
{
    version=$(cat /var/log/syslog | grep "System Management Utility version" | awk '{printf $11}')
    
    core1=$(get_cpucoretemp $((1-1)))
    core2=$(get_cpucoretemp $((2-1)))
    core3=$(get_cpucoretemp $((3-1)))
    core4=$(get_cpucoretemp $((4-1)))

    core_sum=$(($core1 + $core2 + $core3 + $core4))
    cpu_temp=$(($core_sum / 4))"C"

    mb_temp=$(get_mainboardtemp)"C"

    write_serial   "LN1=Ver.: $version" res
    write_serial   "LN2=Temp: $cpu_temp $mb_temp" res
}

show_ip()
{
    ip=$(ifconfig $1 | grep inet | awk '{printf $2}')

    write_serial   "LN1=IP Address $1:" res

    if [ "$ip" == "" ]; then
        write_serial   "LN2=Disabled        " res
    else
        write_serial   "LN2=$ip" res
    fi
}

show_drive_status()
{
    state_disk1=$(smartctl -a /dev/sdb | grep "SMART overall-health" | awk '{printf $6}')
    state_disk2=$(smartctl -a /dev/sdc | grep "SMART overall-health" | awk '{printf $6}')
    state_disk3=$(smartctl -a /dev/sdd | grep "SMART overall-health" | awk '{printf $6}')
    state_disk4=$(smartctl -a /dev/sde | grep "SMART overall-health" | awk '{printf $6}')

    write_serial   "LN1=IP Address $1:" res   "LN1=Drive Status:   " res

    if [ "$state_disk1" == "PASSED" ] && [ "$state_disk2" == "PASSED" ] && [ "$state_disk3" == "PASSED" ] && [ "$state_disk4" == "PASSED" ]; then
        write_serial   "LN1=IP Address $1:" res   "LN2=Healthy         " res
    else
        write_serial   "LN1=IP Address $1:" res   "LN2=Unhealthy       " res
    fi
}

show_capacity()
{
    fsState=$(cat /var/local/emhttp/var.ini | grep fsState | sed 's/"/ /g' | awk '{printf $2}')

    write_serial   "LN1=Capacity:       " res

    if [ "$fsState" == "Stopped" ]; then
        write_serial   "LN2=Array Stopped   " res
    else
        cap=$(df -H | grep "/mnt/user0" | awk '{printf $4}')"B"
        write_serial   "LN2=$cap free       " res
    fi
}
