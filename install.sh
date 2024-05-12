#!/bin/bash

# copy all files to save space
chmod +x hw_control.sh
rm -rf /boot/config/plugins/PR4100_Ctrl/
mkdir /boot/config/plugins/PR4100_Ctrl/
cp ./hw_control.sh /boot/config/plugins/PR4100_Ctrl/hw_control-x86_64-CreLab.sh

# modify go script
tmp=$(ls /boot/config/ | grep go.bak)
if [[ "$tmp" == "" ]]; then
    cp /boot/config/go /boot/config/go.bak
else
    rm /boot/config/go
    cp /boot/config/go.bak /boot/config/go
fi

echo "cp /boot/config/plugins/PR4100_Ctrl/hw_control-x86_64-CreLab.sh /usr/adm/scripts/" >> /boot/config/go
echo "sh /usr/adm/scripts/hw_control-x86_64-CreLab.sh &" >> /boot/config/go
