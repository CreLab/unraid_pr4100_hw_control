#!/bin/bash

####         Includes        ####

source ./scripts/debug.sh

####      Global Defines     ####

hwTTY=/dev/ttyS2

####        Function         ####

init_serial()
{
    case "$( uname -s )" in
        Linux*)  hwSystem=Linux;;
        *)       hwSystem="Other"
    esac

    if [ $hwSystem == Linux ]; then
        hwTTY=/dev/ttyS2
    else
        verbose " Sorry, This software version for the WD PR4100 Hardware does not support $hwSystem platform."
        verbose " Please create an issue on Github to see about gettin support added"
        exit 1
    fi
}

open_serial()
{
    exec 4<$hwTTY 5>$hwTTY
}

close_serial()
{
    exec 4<&- 5>&-
}

com_serial()
{
    local cmd=$1
    declare -n result="$2"
    local max_attempts=10
    local attempts=0

    while [ $attempts -lt $max_attempts ]; do
	    sleep 0.010
	
        open_serial

        echo "$cmd" >&5
        read -r -n 20 res <&4

        close_serial

        if [[ $res != *"ERR"* ] || [ $res != *"RR"* ] || [ $res != *"R"* ]]; then
            result=$(echo $res | cut -d'=' -f2)
            return 0
        fi

        attempts=$((attempts + 1))
        verbose " WARNING: Received an ERR with command $cmd. (Retry: $attempts)"
		
		res=""
    done

    verbose " ERROR: Maximum count of requests reached for command $cmd"
    exit 1
}
