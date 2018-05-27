#!/bin/bash
# Reef Coin Node setup for Ubuntu 16.04 LTS
# (c) 2018 by Dwigt007 for Reef
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#Reef TCP port
PORT=9058

#Clear keyboard input buffer
function clear_stdin { while read -r -t 0; do read -r; done; }

#Delay script execution for N seconds
function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }

#Stop daemon if it's already running
function stop_daemon {
    if pgrep -x 'reefd' > /dev/null; then
        echo -e "${YELLOW}Attempting to stop reefd${NC}"
        reef-cli stop
        delay 30
        if pgrep -x 'reef' > /dev/null; then
            echo -e "${RED}reefd daemon is still running!${NC} \a"
            echo -e "${RED}Attempting to kill...${NC}"
            pkill reefd
            delay 30
            if pgrep -x 'reefd' > /dev/null; then
                echo -e "${RED}Can't stop reefd! Reboot and try again...${NC} \a"
                exit 2
            fi
        fi
    fi
}

#Process command line parameters
genkey=$1

clear

echo -e "${YELLOW}Reef Node setup for Ubuntu 16.04 LTS${NC}"
echo -e "${GREEN}Updating system and installing required packages...${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -n "$publicip" ]; then
    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}
else
    echo -e "${RED}ERROR: Public IP Address was not detected!${NC} \a"
    clear_stdin
    read -e -p "Enter VPS Public IP Address: " publicip
    if [ -z "$publicip" ]; then
        echo -e "${RED}ERROR: Public IP Address must be provided. Try again...${NC} \a"
        exit 1
    fi
fi

# update packages and upgrade Ubuntu
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano htop jq
sudo apt-get -y install libzmq3-dev
sudo apt-get -y install libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev
sudo apt-get -y install libevent-dev

sudo apt -y install software-properties-common
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get -y update
sudo apt-get -y install libdb4.8-dev libdb4.8++-dev

sudo apt-get -y install libminiupnpc-dev

sudo apt-get -y install fail2ban
sudo service fail2ban restart

sudo apt-get install ufw -y
sudo apt-get update -y

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow $PORT/tcp
sudo ufw allow 22/tcp
sudo ufw limit 22/tcp
echo -e "${YELLOW}"
sudo ufw --force enable
echo -e "${NC}"
sudo apt-get install -y unzip libzmq3-dev build-essential libssl-dev libboost-all-dev libqrencode-dev libminiupnpc-dev libboost-system1.58.0 libboost1.58-all-dev libdb4.8++ libdb4.8 libdb4.8-dev libdb4.8++-dev libevent-pthreads-2.0-5

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then
    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"
else
    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"
    touch /var/swap.img
    chmod 600 swap.img
    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
    mkswap /var/swap.img 2> /dev/null
    swapon /var/swap.img 2> /dev/null
    if [ $? -eq 0 ]; then
        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}Swap was created successfully!${NC} \n"
    else
        echo -e "${RED}Operation not permitted! Optional swap was not created.${NC} \a"
        rm /var/swap.img
    fi
fi

#killing Daemon
./reef-cli stop
pkill ./reefd

#delete old dir
rm -r .reefcore

#Installing Daemon
cd ~
mkdir ~/ReefMasternodeSetup/reefcore_linux
   wget https://github.com/reefcoin-io/reefcore/releases/download/v0.9.0/reefcore_linux.zip
unzip reefcore_linux.zip -d ~/ReefMasternodeSetup/reefcore_linux
rm -r reefcore_linux.zip
 
 stop_daemon

# Deploy binaries to /usr/bin
 sudo cp ReefMasternodeSetup/reefcore_linux/reef* /usr/bin/
 sudo chmod 755 -R ~/reef
 sudo chmod 755 /usr/bin/reef*
 
#Finally, starting reef daemon
reefd -daemon
delay 5

#Setting auto start cron job for reefd
cronjob="@reboot sleep 30 && reefd -daemon"
crontab -l > tempcron
if ! grep -q "$cronjob" tempcron; then
    echo -e "${GREEN}Configuring crontab job...${NC}"
    echo $cronjob >> tempcron
    crontab tempcron
fi
rm tempcron

echo -e "========================================================================
${YELLOW}NODE setup is complete!${NC}
========================================================================"

#EOF
 
