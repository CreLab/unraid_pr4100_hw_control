#!/bin/bash

targetPath="/boot/config/plugins/PR4100_Ctrl"

# copy all files to save space
rm -rf $targetPath/
mkdir $targetPath/
mkdir $targetPath/scripts/

cp ./hw_control.sh $targetPath/hw_control-x86_64-CreLab.sh
cp -r ./scripts/* $targetPath/scripts/

# modify include path 
find "$targetPath" -type f -exec sed -i "s|./scripts|$targetPath/scripts|g" {} +

# modify go script
tmp=$(ls /boot/config/ | grep go.bak)
if [[ "$tmp" == "" ]]; then
    cp /boot/config/go /boot/config/go.bak
else
    rm /boot/config/go
    cp /boot/config/go.bak /boot/config/go
fi

echo "sh $targetPath/hw_control-x86_64-CreLab.sh > ~/hw_control_pr4100_log.txt &" >> /boot/config/go
