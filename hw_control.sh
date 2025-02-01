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

####         Includes        ####

source ./scripts/debug.sh
source ./scripts/serial.sh
source ./scripts/temperature.sh
source ./scripts/display.sh
source ./scripts/led.sh

####      Global Defines     ####

updateRate=25            # How often in seconds to update temps
hwMenu=0

####        Init Function        ####

check_for_dependencies()
{
    depenflag=0
    # S.M.A.R.T Drive Utilities
    smartctl -v >/dev/null
    if [[ $? != 1 ]]; then
        verbose " WARNING: SMART not installed please run - sudo apt install smartmontools"
        (( depenflag += 1 ))
    fi

    # lm-Sensors (For temp sensor data )
    sensors -v >/dev/null
    if [[ $? != 0 ]]; then
        verbose " WARNING: lm-sensors not installed please run - sudo apt install smartmontools "
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
        verbose "# INFO: Detected Linux Kernel #"
        init_linux_drivers
    else    
        verbose "Sorry, This software version for the WD PR4100 Hardware does not support $hwSystem platform."
        verbose "Please create an issue on Github to see about gettin support added"
        exit 1
    fi
}

####        Interrupt Function        ####

check_btn_pressed() {
    read_serial "ISR" btn
    mod=8

    verbose "Button $btn"

    case $btn in
    40*)
        verbose "Button down pressed!"
        hwMenu=$(( ($hwMenu + 1) % mod ))
        ;;
    20*)
        verbose "Button up pressed!"
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
        verbose "Unknown Menu id $hwMenu!"
        ;;
    esac
}

####        Main Function        ####

set_verbose $1
check_for_dependencies
get_sys_info

verbose "# INFO: Getting system status and firmware version! #"
read_serial "VER" res
verbose "$res"
read_serial "CFG" res
verbose "$res"
read_serial "STA" res
verbose "$res"

show_name
set_pwr_led SOLID BLU
verbose "# INIT DONE #"

while true; do
    monitor
    verbose "Next temp update in $updateRate seconds"

    for i in $(seq $updateRate); do
        sleep 0.5
        check_btn_pressed
    done
done
