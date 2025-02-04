# unraid_pr4100_hw_control

Unraid PR4100 hardware control gives you full access to LCD, button and fan control for WD My Cloud PR4100.

This script is based on https://github.com/Coltonton/WD-PR4100-FreeNAS-Control.

Here you can find all commands for the PR4100 controler:
https://community.wd.com/t/my-cloud-os5-firmware-notes/286949

or inside the PDF file:

MyCloudOS5_Display_Control_FW_Manual.pdf

## Project Description

This script is pre-configured and should run on PR4100 and PR2100. If not, please create an issue ticket.

## Installation via install.sh
For full use after reboot use the following install script:

```
  $ git clone https://github.com/CreLab/unraid_pr4100_hw_control.git
  $ cd ./unraid_pr4100_hw_control
  $ sh ./install.sh
  $ shutdown -r now
```
If you have some problems with this method. Run the following commands to revert the `go` script first and try the the second install method:

```
  $ rm /boot/config/go
  $ cp /boot/config/go.bak /boot/config/go
```

## Installation via User Scripts Plugin
To run a script on startup in Unraid, you can use the User Scripts plugin. Here are the steps to achieve this:

1. Install the User Scripts Plugin
This plugin allows you to run scripts at specific times, including at startup.

2. Create Your Script
Write your script in a text file, for example with `nano` or `vi`. Save it in a directory that you can easily access.

3. Place the Script in the Right Directory
Open `install.sh` file in editor and change the `targetPath` to the directory `/boot/startup.d`. Save and close the file and execute by `sh ./install.sh`. All scripts in this directory are executed in alphabetical order during startup.

5. Make the Script Executable
Change the permissions of the script to make it executable. You can do this with the command `chmod +x /boot/startup.d/unraid_pr4100_hw_control.sh`.

6. Test the Script
Restart your Unraid server to ensure that the script is executed as expected.

## Usage
For testing only use this command:

```
  $ sh ./hw_control.sh &
```

## License

This project is licensed under the BSD 3-Clause License by TFL.
