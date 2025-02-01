#!/bin/bash

# copy all files to save space
chmod +x ./hw_control.sh
rm -rf /boot/config/plugins/PR4100_Ctrl/
mkdir /boot/config/plugins/PR4100_Ctrl/
mkdir /boot/config/plugins/PR4100_Ctrl/scripts/

cp ./hw_control.sh /boot/config/plugins/PR4100_Ctrl/hw_control-x86_64-CreLab.sh
cp ./scripts/debug.sh /boot/config/plugins/PR4100_Ctrl/scripts/debug.sh
cp ./scripts/serial.sh /boot/config/plugins/PR4100_Ctrl/scripts/serial.sh
cp ./scripts/temperature.sh /boot/config/plugins/PR4100_Ctrl/scripts/temperature.sh
cp ./scripts/led.sh /boot/config/plugins/PR4100_Ctrl/scripts/led.sh
cp ./scripts/display.sh /boot/config/plugins/PR4100_Ctrl/scripts/display.sh

# modify go script
tmp=$(ls /boot/config/ | grep go.bak)
if [[ "$tmp" == "" ]]; then
    cp /boot/config/go /boot/config/go.bak
else
    rm /boot/config/go
    cp /boot/config/go.bak /boot/config/go
fi

echo "cp /boot/config/plugins/PR4100_Ctrl/hw_control-x86_64-CreLab.sh /usr/adm/scripts/" >> /boot/config/go
echo "sh /usr/adm/scripts/hw_control-x86_64-CreLab.sh > /usr/adm/hw_control_pr4100_log &" >> /boot/config/go
