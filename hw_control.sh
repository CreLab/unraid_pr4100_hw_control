#!/bin/bash
#
# Post-init script for Unraid on Western Digital PR4100
# based on wdhws v1.0 by TFL
#
# ported to unraid by CreLab
# 
# BSD 3 LICENSE
#

setup_tty() {
    com=$(dmesg | grep tty | grep 1e.4 | cut -d' ' -f7)
    tty=/dev/$com
    exec 4<$tty 5>$tty
}

setup_i2c() {
    # load kernel modules required for the temperature sensor on the RAM modules
    # kldload -n iicbus smbus smb ichsmb
    return 0
}

send() {
    setup_tty
    # send a command to the PMC module and echo the answer
    echo -ne "$1\r" >&5

    read ans <&4
    start_ts=$(date +%s)
    while :; do
        now_ts=$(date +%s)

        if [ "$ans" != "ERR" ]; then
            break
        fi

        if [ $((now_ts - start_ts)) -gt 5 ]; then
            echo "Timeout."
            break
        fi

        read ans <&4
        sleep 0.1
    done

    if [ "$ans" = "ALERT" ]; then
        echo -ne ALERT >&2
        exit 2
    else
        # keep this for debugging failing commands
        if [ "$ans" = "ERR" ] || [ -z "$ans" ]; then
            echo "CMD $1 gives ERR at $2" >&2
            send_empty
            ans=$(send "$1" $(($2 + 1)))
            exit 1
        fi
    fi
    echo $ans
    send_empty
    # deconstruct tty file pointers, otherwise this script breaks on sleep 
    exec 4<&- 5>&-
}

send_empty() {
    # send a empty command to clear the output
    echo -ne "\r" >&5
    read ignore <&4
}

get_ncpu() {
    # get the number of CPUs
    lscpu | grep -E '^CPU\(s):' | tr -d -c 0-9
}

get_coretemp() {
    # get the CPU temperature and strip of the Celsius
    sensors | grep -E 'Core 2:' | cut -d'.' -f1 | cut -d'+' -f2
}

get_disktemp() {
	case $1 in
		0) hdd="sdb" ;;
		1) hdd="sdc" ;;
		2) hdd="sdd" ;;
		3) hdd="sde" ;;
		*) exit 3 ;;
    esac

    # get the disk $i temperature only if it is spinning
    smartctl -n standby -A /dev/$hdd | grep Temperature_Celsius | awk '{print $NF}'
}

get_ramtemp() {
    # get the memory temperature from the I2C sensor
    # smbmsg -s 0x98 -c 0x0$1 -i 1 -F %d
    echo "20"
}

get_pmc() {
    # get a value from the PMC
    # e.g. TMP returns TMP=25 --> 25
    send $1 | cut -d'=' -f2
}

init() {
    setup_tty
    setup_i2c

    echo "get system status and firmware"
    send VER
    send CFG
    # send STA

    show_welcome
    stop_powerled
}

show_welcome() {
    # set welcome message
    # maximum  "xxx xxx xxx xxx "
    send   "LN1=     UNRAID     "
    send   "LN2=WD PR4100 Server"
}

show_fan_speed() {
    # set fan speed message
    # maximum  "xxx xxx xxx xxx "
    send   "LN1=Fan Speed:      "

    rpm=$((0x$(get_pmc RPM)))

    send   "LN2=$rpm"
}

stop_powerled() {
    # stop blinking power LED
    send PLS=00
    send LED=01  # set to 01 to enable it
    send BLK=00
}

show_ip() {
    send "LN1=Interface br$1"
    ip=$(ifconfig br$1 | grep inet | awk '{printf $2}')
    send "LN2=$ip"
}

monitor() {
    lvl="COOL"

    # check RPM (fan may get stuck) and convert hex to dec
    fan=$(get_pmc FAN)
    rpm=$((0x$(get_pmc RPM)))
    echo "Got rpm $rpm"
    if [ "$rpm" != ERR ]; then
        if [ "$rpm" -lt 400 ]; then
            echo "WARNING: low RPM - $rpm - clean dust!"
        fi
    fi

    # check pmc
    tmp=$((0x$(get_pmc TMP)))
    if [ "$tmp" -gt 64 ]; then
        lvl="HOT"
    fi

    # check disks [adjust this for PR2100!!]
    for i in 0 1 2 3 ; do
        tmp=$(get_disktemp $i)
        echo "disk $i is $tmp"
        if [ ! -z $tmp ] && [ "$tmp" -gt 40 ]; then
            echo "Disk $i temperature is $tmp"
            lvl="HOT"
        fi
    done

    # check cpu
    for i in $(seq $(get_ncpu)); do
        tmp=$(get_coretemp $((i-1)))
        echo "cpu $i is $tmp"
        if [ "$tmp" -gt 50 ]; then
            echo "CPU $i temperature is $tmp"
            lvl="HOT"
        fi
    done

    # check ram
    for i in 0 1; do
        tmp=$(get_ramtemp $i)
        echo "ram temp is $tmp for $i"
        if [ "$tmp" -gt 40 ]; then
            echo "RAM $i temperature is $tmp"
            lvl="HOT"
        fi
    done

    echo "Temperature LVL is $lvl"
    if [ "$lvl" == HOT ] ; then
        if [ "$fan" != 40 ]; then
            send FAN=40
        fi
    else
        if [ "$fan" != 20 ]; then
            send FAN=20
        fi
    fi
}

check_btn_pressed() {
    btn=$(get_pmc ISR)
    #echo "Btn is .$btn."

    case $btn in
    20*)
        echo "Button up pressed!"
        menu=$(( ($menu + 1) % 3 ))
        ;;
    40*)
        echo "Button down pressed!"
        menu=$(( ($menu + 2) % 3 ))
        ;;
    *)
        return
    esac

    case "$menu" in
    0)
        show_welcome
        ;;
    1)
        show_ip 0
        ;;
    2)
        show_fan_speed
        ;;
    # if you add menu items here, update mod 3 uses above
    esac
}

# initial setup
init

while :; do
    # adjust fan speed every 30 seconds
    monitor

    # check for button presses
    for i in $(seq 30); do
        sleep 1
        check_btn_pressed
    done
done


