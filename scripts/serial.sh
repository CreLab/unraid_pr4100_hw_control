#!/bin/bash

####      Global Defines     ####

hwTTY=/dev/ttyS2              # Used to init tty variable, gets changed based on kernal in get_sys_info()

####        Function         ####

init_serial()
{
    hwTTY=/dev/ttyS2
}

open_serial()
{
    exec 4<$hwTTY 5>$hwTTY
}

close_serial()
{
    exec 4<&- 5>&-
}

read_serial()
{
    local cmd=$1
    declare -n result="$2"

    open_serial

    echo "$cmd" >&5
    read -r -n 20 res <&4

    close_serial

    result=$(echo $res | cut -d'=' -f2)
}

write_serial()
{
    local cmd=$1
    declare -n result="$2"

    open_serial

    echo "$cmd\r" >&5
    read -r -n 20 res <&4

    close_serial

    result=$res
}
