#!/bin/bash

####         Includes        ####

source ./scripts/debug.sh
source ./scripts/serial.sh

####      Global Defines     ####

####        Function         ####

set_pwr_led()
{
    if [ "$1" = "SOLID" ]; then
        com_serial "BLK=00" res
        com_serial "PLS=00" res

        case "$2" in
            "BLU")
                com_serial "LED=01" res
                ;;
            "RED")
                com_serial "LED=02" res
                ;;
            "PUR")
                com_serial "LED=03" res
                ;;
            "GRE")
                com_serial "LED=04" res
                ;;
            "TEA")
                com_serial "LED=05" res
                ;;
            "YLW")
                com_serial "LED=06" res
                ;;
            "WHT")
                com_serial "LED=07" res
                ;;
            *)
                verbose " INFO: Unknown LED mode $2!"
                ;;
        esac
    fi

    if [ "$1" = "FLASH" ]; then
        com_serial "LED=00" res
        com_serial "PLS=00" res

        case "$2" in
            "BLU")
                com_serial "BLK=01" res
                ;;
            "RED")
                com_serial "BLK=02" res
                ;;
            "PUR")
                com_serial "BLK=03" res
                ;;
            "GRE")
                com_serial "BLK=04" res
                ;;
            "TEA")
                com_serial "BLK=05" res
                ;;
            "YLW")
                com_serial "BLK=06" res
                ;;
            "WHT")
                com_serial "BLK=07" res
                ;;
            *)
                verbose " INFO: Unknown LED mode $2!"
                ;;
        esac
    fi

    if [ "$1" = "PULSE" ]; then
        com_serial "PLS=01" res
        com_serial "LED=00" res
        com_serial "BLK=00" res
    fi
}
