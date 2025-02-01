#!/bin/bash

####         Includes        ####

source ./scripts/debug.sh
source ./scripts/serial.sh

####      Global Defines     ####

####        Function         ####

set_pwr_led()
{
    if [ "$1" == SOLID ]; then
        write_serial "BLK=00" res
        write_serial "PLS=00" res
        if [ "$2" == BLU ]; then
            write_serial "LED=01" res
        elif [ "$2" == RED ]; then
            write_serial "LED=02" res
        elif [ "$2" == PUR ]; then
            write_serial "LED=03" res
        elif [ "$2" == GRE ]; then
            write_serial "LED=04" res
        elif [ "$2" == TEA ]; then
            write_serial "LED=05" res
        elif [ "$2" == YLW ]; then
            write_serial "LED=06" res
        elif [ "$2" == WHT ]; then
            write_serial "LED=07" res
        fi
    fi

    if [ "$1" == FLASH ]; then
        write_serial "LED=00" res
        write_serial "PLS=00" res
        if [ "$2" == BLU ]; then
            write_serial "BLK=01" res
        elif [ "$2" == RED ]; then
            write_serial "BLK=02" res
        elif [ "$2" == PUR ]; then
            write_serial "BLK=03" res
        elif [ "$2" == GRE ]; then
            write_serial "BLK=04" res
        elif [ "$2" == TEA ]; then
            write_serial "BLK=05" res
        elif [ "$2" == YLW ]; then
            write_serial "BLK=06" res
        elif [ "$2" == WHT ]; then
            write_serial "BLK=07" res
        fi
    fi

    if [ "$1" == PULSE ]; then
        write_serial "PLS=01" res
        write_serial "LED=00" res
        write_serial "BLK=00" res
    fi
}
