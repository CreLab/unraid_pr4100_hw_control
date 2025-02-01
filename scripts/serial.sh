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
    declare -n result="$2"

    open_serial()

	echo "$1" >&5
	read -r -n 20 res <&4

    close_serial()

    result="$res"
}

write_serial()
{
    declare -n result="$2"

    open_serial()

	echo "$1\n" >&5
	read -r -n 20 res <&4

    close_serial()

	result=$(echo $res | cut -d'=' -f2)
}
