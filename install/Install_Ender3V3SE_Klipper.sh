#!/bin/bash
#######################################################################################################################
#
#    ENDER 3 V3 SE - Klipper installation script
#
#
#
#    Copyright (c) schnoog
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################################################################



THISSCRIPT=$(readlink -f ${BASH_SOURCE[0]})
export SCRIPTDIR=$(dirname ${THISSCRIPT})"/"
export CONFIG_FILE="/dev/shm/SETTINGS.cfg"
export TMP_FILE="/dev/shm/temp.file"

#########################
Color_Off='\033[0m' 
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'
Cyan='\033[0;36m'
CO='\033[0m'

set_config_value() {
    local key=$1
    local value=$2
    if grep -q "^$key=" "$CONFIG_FILE"; then
        sudo sed -i "s/^$key=.*/$key=$value/" "$CONFIG_FILE"
    else
        sudo echo "$key=$value" >> "$CONFIG_FILE"
    fi
}

# Function to read a configuration value
get_config_value() {
    local key=$1
    grep "^$key=" "$CONFIG_FILE" | cut -d '=' -f2-
}

# Function to enable cursor blinking
enable_cursor_blink() {
    echo -e "\033[?12h\033[?25h"
}

# Function to disable cursor blinking
disable_cursor_blink() {
    echo -e "\033[?12l\033[?25h"
}

# Function to check if a process is running and blink cursor
blink_cursor_while_running() {
    local process_name=$1

    # Ensure cursor blinking is disabled on script exit
    trap disable_cursor_blink EXIT

    while true; do
        # Check if the process is running
		
        if ps aux | grep -v grep | grep "$process_name" > /dev/null; then
            enable_cursor_blink
        else
            disable_cursor_blink
            break
        fi
        sleep 1  # Wait for 1 second before checking again
    done
}



select_ws() {
    PS3="Select your choice: "
    options=("Mainsail" "Fluidd" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
            "Mainsail")
                WS=3
                echo "Mainsail selected. WS set to $WS"
                break
                ;;
            "Fluidd")
                WS=4
                echo "Fluidd selected. WS set to $WS"
                break
                ;;
            "Quit")
                echo "Exiting..."
                exit
                ;;
            *) echo "Invalid option. Please select 1 or 2.";;
        esac
    done
}

#########################


if [ "$USER" == "root" ]
then
	echo -e "$Red This script can't be run as root. Sorry $CO"
	echo -e "$Color_Off Please login as standard user and start $Green $THISSCRIPT $Color_Off again"
	exit 1
fi

sudo mkdir -p "$SCRIPTDIR""tmp/"
sudo touch "$CONFIG_FILE" && sudo chmod 666 "$CONFIG_FILE"
sudo touch "$TMP_FILE" && sudo chmod 666 "$TMP_FILE"
sudo echo "" > "$TMP_FILE"


donestep=$(get_config_value "donestep")
if [ "$donestep" == "" ] 
then
	donestep=0
fi


###Update and install git
if [ $donestep -lt 1 ]
then
	echo -e "$Yellow Apt update, screen and git install $CO"
	sudo apt-get update 
	sudo apt-get install screen git -y && donestep=1
	set_config_value "donestep" 1
	echo -e "$Green screen and git installed $CO"
fi

###Add the user to tty group
if [ $donestep -lt 2 ]
then
	echo -e "$Yellow Add the user $SETUSER to the group tty $CO"
	isin=1
	grep 'tty' /etc/group | grep "$SETUSER" >/dev/null || isin=0
	if [ "$isin" == "0" ]
	then
		echo -e "$Yellow -- user isn't in group yet, add it $CO"
		#sudo usermod -a -G tty "$SETUSER"
	fi	
	donestep=2
	set_config_value "donestep" 2
	echo -e "$Green User is in group tty $CO"
fi

### Unistall brltty if is running
if [ $donestep -lt 3 ]
then
	echo -e "$Yellow Check if brltty is running. If so, uninstall it $CO"
	ps aux | grep "brltty" | grep -v "grep" && sudo apt-get remove brltty
	donestep=3
	set_config_value "donestep" 3
	echo -e "$Green brltty is removed $CO"
fi

### Install KIAUH
if [ $donestep -lt 4 ]
then
	echo -e "$Yellow Install KIAUH in user context $CO"
	if [ -d ~/kiauh/ ]
	then
		echo -e "$Green KIAUH already installed, just updating it $CO"
		cd ~/kiauh/ && git pull
	else
		cd ~ && git clone https://github.com/dw-0/kiauh.git	
		echo -e "$Green KIAUH installed $CO"
	fi
	donestep=4
	set_config_value "donestep" 4
fi

### Set the repo
if [ $donestep -lt 5 ]
then
	echo -e "$Yellow Create the Ender V3 SE repo file $CO"
	echo "https://github.com/Klipper3d/klipper" > ~/kiauh/klipper_repos.txt
	echo "https://github.com/jpcurti/ender3-v3-se-klipper-with-display" >> ~/kiauh/klipper_repos.txt
	echo -e "$Green Repo file created $CO"
	donestep=5
	set_config_value "donestep" 5
fi

### kiauh magic
if [ $donestep -lt 6 ]
then
	cd ~
	echo "" > screenlog.0
	echo -e "$Yellow Let's do some work in kiauh $CO"
	echo -e "$Yellow  -- starting kiauh screen session"
	screen -d -m -S kia ~/kiauh/kiauh.sh
	#Set custom repo
	echo -e "$Cyan --settings $CO"
	screen -S kia -X stuff "6\\r"
	sleep 2
	echo -e "$Cyan ---Set custom Klipper repository $CO"
	screen -S kia -X stuff "1\\r"
	sleep 2
	echo -e "$Cyan ---jpcurti/ender3-v3-se-klipper-with-display  $CO"
	screen -S kia -X stuff "1\\r"
	sleep 2
	echo -e "$Cyan ---Back $CO"
	screen -S kia -X stuff "B\\r"
	sleep 2
	echo -e "$Cyan ---Back to mainpage $CO"
	screen -S kia -X stuff "B\\r"
	sleep 2
	
	

	#install
	echo -e "$Cyan ---Install $CO"	
	screen -S kia -X stuff "1\\r"
	sleep 2
	echo -e "$Cyan ---Klipper $CO"	
	#install klipper
	screen -S kia -X stuff "1\\r"
	sleep 4
	echo -e "$Cyan ---[Python 3.x]  (recommended) $CO"	
	#select python
	screen -S kia -X stuff "\\r"
	sleep 2
	#number of instances
	echo -e "$Cyan ---Number of Klipper instances to set up: 1 $CO"
	echo -e "$Cyan ---Run installation. Please stay tuned $CO"
	screen -S kia -X stuff "\\r"
	sleep 2	
	#<----installing---->
	
	isinstalled=0
	enable_cursor_blink
	while [ "$isinstalled" == "0" ]
	do
		screen -S kia -X hardcopy "$TMP_FILE"
		grep 'Klipper has been set up!' "$TMP_FILE" && isinstalled=1
		echo -n "X"
		sleep 5
	done
	echo ""
	disable_cursor_blink
	
	echo -e "$Cyan ---Back $CO"	
	screen -S kia -X stuff "B\\r"
	sleep 1
	echo -e "$Cyan ---Quit $CO"	
	screen -S kia -X stuff "Q\\r"
	sleep 1
	#<----leaving kiauh--->
	echo -e "$Green Klipper is installed $CO"
	donestep=6
	set_config_value "donestep" 6
fi


### Set the repo
if [ $donestep -lt 7 ]
then
	echo -e "$Yellow Install Moonraker $CO"
	cd ~
	echo "" > screenlog.0
	echo -e "$Yellow Let's do some work in kiauh $CO"
	echo -e "$Yellow  -- starting kiauh screen session"
	screen -d -m -S kia ~/kiauh/kiauh.sh
	#Set custom repo
	echo -e "$Cyan ---Install $CO"
	screen -S kia -X stuff "1\\r"
	sleep 2
	echo -e "$Cyan ---[Moonraker] $CO"
	screen -S kia -X stuff "2\\r"
	sleep 2
	echo -e "$Cyan ---y $CO"
	echo -e "$Cyan --- Install moonraker, please stay tuned $CO"
	screen -S kia -X stuff "Y\\r"
	sleep 2

	isinstalled=0
	enable_cursor_blink
	while [ "$isinstalled" == "0" ]
	do
		screen -S kia -X hardcopy "$TMP_FILE"
		grep 'Moonraker has been set up!' "$TMP_FILE" && isinstalled=1
		echo -n "X"
		sleep 5
	done
	echo ""
	disable_cursor_blink

	echo -e "$Cyan ---Back $CO"	
	screen -S kia -X stuff "B\\r"
	sleep 1
	echo -e "$Cyan ---Quit $CO"	
	screen -S kia -X stuff "Q\\r"

	echo -e "$Green Moonraker installed $CO"
	donestep=7
	set_config_value "donestep" 7
fi


### Unistall brltty if is running
if [ $donestep -lt 8 ]
then
	echo -e "$Greed Please select the webinterface to install $CO"
	select_ws
	
	echo "$WS"


	echo -e "$Yellow Install Webinterface $CO"
	cd ~
	echo "" > screenlog.0
	echo -e "$Yellow Let's do some work in kiauh $CO"
	echo -e "$Yellow  -- starting kiauh screen session"
	screen -d -m -S kia ~/kiauh/kiauh.sh
	sleep 1
	#Set custom repo
	echo -e "$Cyan ---Install $CO"
	screen -S kia -X stuff "1\\r"
	sleep 2
	echo -e "$Cyan ---[Moonraker] $CO"
	screen -S kia -X stuff "$WS\\r"
	sleep 2


	isinstalled=0
	enable_cursor_blink
	while [ "$isinstalled" == "0" ]
	do
		screen -S kia -X hardcopy "$TMP_FILE"
		grep 'Download the recommended macros?' "$TMP_FILE" && isinstalled=1
		echo -n "X"
		sleep 2
	done
	echo ""
	disable_cursor_blink	
	
	echo -e "$Cyan ---Y $CO"
	screen -S kia -X stuff "Y\\r"
	sleep 2	
	isinstalled=0
	enable_cursor_blink
	while [ "$isinstalled" == "0" ]
	do
		screen -S kia -X hardcopy "$TMP_FILE"
		grep 'Mainsail has been set up!' "$TMP_FILE" && isinstalled=1
		grep 'Fluidd has been set up!' "$TMP_FILE" && isinstalled=1
		echo -n "X"
		sleep 2
	done
	echo ""
	disable_cursor_blink	

	echo -e "$Cyan ---Back $CO"	
	screen -S kia -X stuff "B\\r"
	sleep 1
	echo -e "$Cyan ---Quit $CO"	
	screen -S kia -X stuff "Q\\r"


	donestep=8
	set_config_value "donestep" 8
	echo -e "$Green Webinterface installed $CO"
fi



### 
if [ $donestep -lt 9 ]
then
	echo -e "$Yellow Preparing printer.cfg $CO"
	cd ~/printer_data/config
	echo -e "$Cyan ---Download prtouch.cfg $CO"	
	wget "https://raw.githubusercontent.com/0xD34D/ender3-v3-se-klipper-config/main/prtouch.cfg" 2>/dev/null
	echo -e "$Cyan ---Download config and rename it to printer.cfg $CO"			
	wget https://raw.githubusercontent.com/0xD34D/ender3-v3-se-klipper-config/main/printer-creality-ender3-v3-se-2023.cfg 2>/dev/null && mv printer-creality-ender3-v3-se-2023.cfg printer.cfg
	echo -e "$Cyan ---Include prtouch.cfg and add display settings to printer.cfg $CO"	
	echo '[include prtouch.cfg]' >> printer.cfg
	echo '' >> printer.cfg
	echo '[e3v3se_display]' >> printer.cfg
	echo 'language: english' >> printer.cfg
	
	echo -e "$Green Printer.cfg downloaded and adjusted $CO"
	donestep=9
	set_config_value "donestep" 9
fi

### 
if [ $donestep -lt 10 ]
then
	echo -e "$Yellow Build the klipper firmware $CO"
	cd ~/klipper/
	rm .config 2>/dev/null
	echo -e "$Cyan ---Starting menuconfig in screen $CO"
	screen -d -m -S mc make menuconfig
	sleep 3

	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'k\\r'
	sleep 0.5
	screen -S mc -X stuff 'k\\r'
	sleep 0.5
	screen -S mc -X stuff 'k\\r'
	sleep 0.5
	screen -S mc -X stuff 'k\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'j\\r'
	sleep 0.5
	screen -S mc -X stuff ' \\r'
	sleep 0.5
	screen -S mc -X stuff 'q\\r'
	sleep 0.5
	screen -S mc -X stuff 'y\\r'

	echo -e "$Green make menuconfig completed now buildig the firmware $CO"
	make
	
	
	echo -e "$Green Firmware created $CO"
	donestep=10
	set_config_value "donestep" 10
	

	
fi


### 
if [ $donestep -lt 11 ]
then
	echo -e "$Yellow Now it's on you $CO"
	
	echo -e "$Green ++++++++++++++++++++++++++++++++++++++++++ $CO"
	echo -e "$Green +      Klipper firmware was created      + $CO"
	echo -e "$Green +                                        + $CO"
	echo -e "$Green +          Please copy the file          + $CO"
	echo -e "$Green + $Red  "$(realpath ~/klipper/out/klipper.bin)"  $CO"
	echo -e "$Green +      to an SDCard and rename it to     + $CO"
	echo -e "$Green + $Red               "$(tr -dc 'A-Z' </dev/urandom | head -c 5)".bin           $Green     + $CO"	
	echo -e "$Green +        Power down your printer         + $CO"	
	echo -e "$Green +          insert the SD card            + $CO"
	echo -e "$Green +    Power on the printer and wait       + $CO"	
	echo -e "$Green +    for 2 minutes. Then power-cycle     + $CO"	
	echo -e "$Green +    the printer. The display should     + $CO"	
	echo -e "$Green +       now show the printer menue       + $CO"
	echo -e "$Green ++++++++++++++++++++++++++++++++++++++++++ $CO"	
	donestep=11
	set_config_value "donestep" 11
fi




