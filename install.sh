#!/bin/bash

# copy all files to save space
rm -rf /boot/config/plugins/PR4100_Ctrl/
mkdir /boot/config/plugins/PR4100_Ctrl/
mkdir /boot/config/plugins/PR4100_Ctrl/scripts/

cp ./hw_control.sh /boot/config/plugins/PR4100_Ctrl/hw_control-x86_64-CreLab.sh
cp -r ./scripts/ /boot/config/plugins/PR4100_Ctrl/scripts/

# modify go script
tmp=$(ls /boot/config/ | grep go.bak)
if [[ "$tmp" == "" ]]; then
    cp /boot/config/go /boot/config/go.bak
else
    rm /boot/config/go
    cp /boot/config/go.bak /boot/config/go
fi

echo "cp /boot/config/plugins/PR4100_Ctrl/hw_control-x86_64-CreLab.sh /usr/adm/scripts/" >> /boot/config/go
echo "cp -r /boot/config/plugins/PR4100_Ctrl/scripts/ /usr/adm/scripts/scripts/" >> /boot/config/go
echo "sh /usr/adm/scripts/hw_control-x86_64-CreLab.sh > /usr/adm/hw_control_pr4100_log &" >> /boot/config/go
