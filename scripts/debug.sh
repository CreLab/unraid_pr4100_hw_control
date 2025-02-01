#!/bin/bash

####      Global Defines     ####

hwVerbose=0

####        Function         ####

set_verbose()
{
	if [ "$1" = "-v" ]; then
		hwVerbose=1
	else
	    hwVerbose=0
	fi
}

verbose()
{
    if [ $hwVerbose -eq 1 ]; then
        echo $1
    fi
}
