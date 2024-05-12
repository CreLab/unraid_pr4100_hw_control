# unraid_pr4100_hw_control

Unraid PR4100 hardware control gives you full access to LCD, button and fan control for WD My Cloud PR4100.

This script is based on https://github.com/Coltonton/WD-PR4100-FreeNAS-Control.

**Project Description**:

This script is pre-configured and should run on PR4100 and PR2100. If not, please create an issue ticket.

**Installation**:
For full use after reboot use the following install script:

```
  $ git clone https://github.com/CreLab/unraid_pr4100_hw_control.git
  $ cd ./unraid_pr4100_hw_control
  $ sh install.sh
  $ shutdown -r now
```

**Usage**:
For testing only use this command:

```
  $ sh ./hw_control.sh &
```

**License**:

This project is licensed under the BSD 3-Clause License by TFL.
