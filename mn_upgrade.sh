#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="gamefrag.conf"
GAMEFRAG_DAEMON="/usr/local/bin/gamefragd"
GAMEFRAG_CLI="/usr/local/bin/gamefrag-cli"
GAMEFRAG_REPO="https://github.com/Game-Frag/game-frag-coin.git"
GAMEFRAG_LATEST_RELEASE="https://github.com/Game-Frag/game-frag-coin/releases/download/v5.2.0.1/gamefrag-5.2.0.1-ubuntu18-daemon.zip"
COIN_BOOTSTRAP='https://bootstrap.gamefrag.com/boot_strap.tar.gz'
COIN_ZIP=$(echo $GAMEFRAG_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')

DEFAULT_GAMEFRAG_PORT=42020
DEFAULT_GAMEFRAG_RPC_PORT=42021
DEFAULT_GAMEFRAG_USER="gamefrag"
GAMEFRAG_USER="gamefrag"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME Daemon{NC}"
    #kill wallet daemon
	systemctl stop $GAMEFRAG_USER.service
	
	#Clean block chain for Bootstrap Update
    cd $CONFIGFOLDER >/dev/null 2>&1
    rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
	
    #remove binaries and GameFrag utilities
    cd /usr/local/bin && sudo rm gamefrag-cli gamefrag-tx gamefragd > /dev/null 2>&1 && cd
    echo -e "${GREEN}* Done${NONE}";
}


function download_bootstrap() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME BootStrap${NC}"
  mkdir -p /root/tmp
  cd /root/tmp >/dev/null 2>&1
  rm -rf boot_strap* >/dev/null 2>&1
  wget -q $COIN_BOOTSTRAP
  cd $CONFIGFOLDER >/dev/null 2>&1
  rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
  cd /root/tmp >/dev/null 2>&1
  tar -zxf $COIN_CHAIN /root/tmp >/dev/null 2>&1
  cp -Rv cache/* $CONFIGFOLDER >/dev/null 2>&1
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *18.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 18.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $GAMEFRAG_DAEMON)" ] || [ -e "$GAMEFRAG_DAEMON" ] ; then
  echo -e "${GREEN}\c"
  echo -e "GameFrag is already installed. Exiting..."
  echo -e "{NC}"
  exit 1
fi
}


function copy_gamefrag_binaries(){
  cd /root
  wget $GAMEFRAG_LATEST_RELEASE
  unzip gamefrag-5.2.0.1-ubuntu18-daemon.zip
  cp gamefrag-cli gamefragd gamefrag-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/gamefrag* >/dev/null
  clear
}

function install_gamefrag(){
  echo -e "Installing GameFrag files."
  copy_gamefrag_binaries
  clear
}


function systemd_gamefrag() {
sleep 2
systemctl start $GAMEFRAG_USER.service
}


function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "GameFrag Masternode Upgraded to the Latest Version{NC}"
 echo -e "Commands to Interact with the service are listed below{NC}"
 echo -e "Start: ${RED}systemctl start $GAMEFRAG_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $GAMEFRAG_USER.service${NC}"
 echo -e "Please check GameFrag is running with the following command: ${GREEN}systemctl status $GAMEFRAG_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	download_bootstrap
	systemd_gamefrag
	important_information
}


##### Main #####
clear
purgeOldInstallation
checks
install_gamefrag

