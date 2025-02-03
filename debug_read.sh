#!/bin/bash

####         Includes        ####

source ./scripts/debug.sh
source ./scripts/serial.sh

####      Global Defines     ####

####      Init Function      ####

####    Interrupt Function   ####

####       Main Function     ####

set_verbose "-v"
raed_serial $1 ret
verbose $ret