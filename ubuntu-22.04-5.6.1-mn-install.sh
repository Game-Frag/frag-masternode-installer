#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="gamefrag.conf"
GAMEFRAG_DAEMON="/usr/local/bin/gamefragd"
GAMEFRAG_CLI="/usr/local/bin/gamefrag-cli"
GAMEFRAG_REPO="https://github.com/Game-Frag/game-frag-coin.git"
GAMEFRAG_PARAMS="https://github.com/Game-Frag/game-frag-coin/releases/download/v5.6.1/util.zip"
GAMEFRAG_LATEST_RELEASE="https://github.com/Game-Frag/game-frag-coin/releases/download/v5.6.1/gamefrag-5.6.1-ubuntu22-daemon.zip"
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

function download_bootstrap() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME BootStrap${NC}"
  mkdir -p /root/tmp
  cd /root/tmp >/dev/null 2>&1
  rm -rf boot_strap* >/dev/null 2>&1
  wget -q $COIN_BOOTSTRAP
  cd $CONFIGFOLDER >/dev/null 2>&1
  rm -rf blk* database* txindex* peers.dat
  cd /root/tmp >/dev/null 2>&1
  tar -zxf $COIN_CHAIN /root/tmp >/dev/null 2>&1
  cp -Rv cache/* $CONFIGFOLDER >/dev/null 2>&1
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function install_params() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME Params FIles${NC}"
  mkdir -p /root/tmp
  cd /root/tmp >/dev/null 2>&1
  rm -rf util* >/dev/null 2>&1
  wget -q $GAMEFRAG_PARAMS
  unzip $GAMEFRAG_PARAMS >/dev/null 2>&1
  chmod -Rv +x util >/dev/null 2>&1
  util/./fetch-params.sh
  clear
}

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


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *22.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 22.04. Installation is cancelled.${NC}"
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

function prepare_system() {

echo -e "Prepare the system to install GameFrag master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get upgrade >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev ufw fail2ban pwgen curl unzip >/dev/null 2>&1
NODE_IP=$(curl -s4 icanhazip.com)
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt-get -y upgrade"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:pivx/pivx"
    echo "apt-get update"
    echo "apt install -y git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev unzip"
    exit 1
fi
clear

}

function ask_yes_or_no() {
  read -p "$1 ([Y]es or [N]o | ENTER): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function compile_gamefrag() {
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "4" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 4G of RAM without SWAP, creating 8G swap file.${NC}"
    SWAPFILE=/swapfile
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=8388608
    chown root:root $SWAPFILE
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
else
  echo -e "${GREEN}Server running with at least 4G of RAM, no swap needed.${NC}"
fi
clear
  echo -e "Clone git repo and compile it. This may take some time."
  cd $TMP_FOLDER
  git clone $GAMEFRAG_REPO gamefrag
  cd gamefrag
  ./autogen.sh
  ./configure
  make
  strip src/gamefragd src/gamefrag-cli src/gamefrag-tx
  make install
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function copy_gamefrag_binaries(){
   cd /root
  wget $GAMEFRAG_LATEST_RELEASE
  unzip gamefrag-5.6.1-ubuntu22-daemon.zip
  cp gamefrag-cli gamefragd gamefrag-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/gamefrag* >/dev/null
  clear
}

function install_gamefrag(){
  echo -e "Installing GameFrag files."
  echo -e "${GREEN}You have the choice between source code compilation (slower and requries 4G of RAM or VPS that allows swap to be added), or to use precompiled binaries instead (faster).${NC}"
  if [[ "no" == $(ask_yes_or_no "Do you want to perform source code compilation?") || \
        "no" == $(ask_yes_or_no "Are you **really** sure you want compile the source code, it will take a while?") ]]
  then
    copy_gamefrag_binaries
    clear
  else
    compile_gamefrag
    clear
  fi
}

function enable_firewall() {
  echo -e "Installing fail2ban and setting up firewall to allow ingress on port ${GREEN}$GAMEFRAG_PORT${NC}"
  ufw allow $GAMEFRAG_PORT/tcp comment "GameFrag MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_gamefrag() {
  cat << EOF > /etc/systemd/system/$GAMEFRAG_USER.service
[Unit]
Description=GameFrag service
After=network.target
[Service]
ExecStart=$GAMEFRAG_DAEMON -conf=$GAMEFRAG_FOLDER/$CONFIG_FILE -datadir=$GAMEFRAG_FOLDER
ExecStop=$GAMEFRAG_CLI -conf=$GAMEFRAG_FOLDER/$CONFIG_FILE -datadir=$GAMEFRAG_FOLDER stop
Restart=always
User=$GAMEFRAG_USER
Group=$GAMEFRAG_USER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $GAMEFRAG_USER.service
  systemctl enable $GAMEFRAG_USER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$GAMEFRAG_USER | grep $GAMEFRAG_DAEMON)" ]]; then
    echo -e "${RED}gamefragd is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $GAMEFRAG_USER.service"
    echo -e "systemctl status $GAMEFRAG_USER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function ask_port() {
read -p "GAMEFRAG Port: " -i $DEFAULT_GAMEFRAG_PORT -e GAMEFRAG_PORT
: ${GAMEFRAG_PORT:=$DEFAULT_GAMEFRAG_PORT}
}

function ask_user() {
  echo -e "${GREEN}The script will now setup GameFrag user and configuration directory. Press ENTER to accept defaults values.${NC}"
  read -p "GameFrag user: " -i $DEFAULT_GAMEFRAG_USER -e GAMEFRAG_USER
  : ${GAMEFRAG_USER:=$DEFAULT_GAMEFRAG_USER}

  if [ -z "$(getent passwd $GAMEFRAG_USER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $GAMEFRAG_USER
    echo "$GAMEFRAG_USER:$USERPASS" | chpasswd

    GAMEFRAG_HOME=$(sudo -H -u $GAMEFRAG_USER bash -c 'echo $HOME')
    DEFAULT_GAMEFRAG_FOLDER="$GAMEFRAG_HOME/.gamefrag"
    read -p "Configuration folder: " -i $DEFAULT_GAMEFRAG_FOLDER -e GAMEFRAG_FOLDER
    : ${GAMEFRAG_FOLDER:=$DEFAULT_GAMEFRAG_FOLDER}
    mkdir -p $GAMEFRAG_FOLDER
    chown -R $GAMEFRAG_USER: $GAMEFRAG_FOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $GAMEFRAG_PORT ]] || [[ ${PORTS[@]} =~ $[GAMEFRAG_PORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $GAMEFRAG_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$DEFAULT_GAMEFRAG_RPC_PORT
listen=1
server=0
daemon=1
port=$GAMEFRAG_PORT
#External GameFrag IPV4
addnode=199.127.140.224:42020
addnode=199.127.140.225:42020
addnode=199.127.140.228:42020
addnode=199.127.140.231:42020
addnode=199.127.140.233:42020
addnode=199.127.140.235:42020
addnode=199.127.140.236:42020

#External GameFrag IPV6
addnode=[2604:6800:5e11:3611::1]:42020
addnode=[2604:6800:5e11:3611::2]:42020
addnode=[2604:6800:5e11:3612::4]:42020
addnode=[2604:6800:5e11:3613::2]:42020
addnode=[2604:6800:5e11:3613::5]:42020
addnode=[2604:6800:5e11:3614::1]:42020
addnode=[2604:6800:5e11:3614::2]:42020
addnode=[2604:6800:5e11:3614::3]:42020
addnode=[2604:6800:5e11:3614::4]:42020

#External WhiteListing IPV4
whitelist=199.127.140.224
whitelist=199.127.140.225
whitelist=199.127.140.228
whitelist=199.127.140.231
whitelist=199.127.140.233
whitelist=199.127.140.235
whitelist=199.127.140.236

#External WhiteListing IPV6
whitelist=[2604:6800:5e11:3611::1]
whitelist=[2604:6800:5e11:3611::2]
whitelist=[2604:6800:5e11:3612::4]
whitelist=[2604:6800:5e11:3613::2]
whitelist=[2604:6800:5e11:3613::5]
whitelist=[2604:6800:5e11:3614::1]
whitelist=[2604:6800:5e11:3614::2]
whitelist=[2604:6800:5e11:3614::3]
whitelist=[2604:6800:5e11:3614::4]

#Internal WhiteListing IPV4
whitelist=10.36.11.1
whitelist=10.36.11.2
whitelist=10.36.12.4
whitelist=10.36.13.2
whitelist=10.36.13.5
whitelist=10.36.14.1
whitelist=10.36.14.2
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e GAMEFRAG_KEY
  if [[ -z "$GAMEFRAG_KEY" ]]; then
  su $GAMEFRAG_USER -c "$GAMEFRAG_DAEMON -conf=$GAMEFRAG_FOLDER/$CONFIG_FILE -datadir=$GAMEFRAG_FOLDER -daemon"
  sleep 15
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$GAMEFRAG_USER | grep $GAMEFRAG_DAEMON)" ]; then
   echo -e "${RED}GameFragd server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  GAMEFRAG_KEY=$(su $GAMEFRAG_USER -c "$GAMEFRAG_CLI -conf=$GAMEFRAG_FOLDER/$CONFIG_FILE -datadir=$GAMEFRAG_FOLDER createmasternodekey")
  su $GAMEFRAG_USER -c "$GAMEFRAG_CLI -conf=$GAMEFRAG_FOLDER/$CONFIG_FILE -datadir=$GAMEFRAG_FOLDER stop"
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $GAMEFRAG_FOLDER/$CONFIG_FILE
  cat << EOF >> $GAMEFRAG_FOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODE_IP:$GAMEFRAG_PORT
masternodeprivkey=$GAMEFRAG_KEY
EOF
  chown -R $GAMEFRAG_USER: $GAMEFRAG_FOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "GameFrag Masternode is up and running as user ${GREEN}$GAMEFRAG_USER${NC} and it is listening on port ${GREEN}$GAMEFRAG_PORT${NC}."
 echo -e "${GREEN}$GAMEFRAG_USER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$GAMEFRAG_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $GAMEFRAG_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $GAMEFRAG_USER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODE_IP:$GAMEFRAG_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$GAMEFRAG_KEY${NC}"
 echo -e "Please check GameFrag is running with the following command: ${GREEN}systemctl status $GAMEFRAG_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  download_bootstrap
  install_params
  systemd_gamefrag
  important_information
}


##### Main #####
clear
purgeOldInstallation
checks
prepare_system
install_gamefrag
setup_node
