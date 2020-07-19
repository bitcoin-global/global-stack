#!/bin/bash
###############################################################################
#
#                             deploy-node.sh
#
# This is the install script for Bitcoin Global public node.
#
###############################################################################

ENTRYPOINT_COMMAND="-testnet"
BTC_VERSION=0.19.2
BITCOIN_NETWORK_TYPE=${BITCOIN_NETWORK_TYPE:-testnet}

### Install required packages
echo "Prepare machine"
apt-get update
apt-get install -y \
    gnupg2 ca-certificates git software-properties-common \
    python3.6 sudo nano ruby wget curl pigz \
    autoconf libssl1.0-dev dirmngr gosu dnsutils gpg wget jq npm

### Install required tools
mkdir -p /binaries
mkdir -p /bitcoin-global

### Install Bitcoin
../node/install-node.sh \
    -v ${BTC_VERSION} \
    -r v${BTC_VERSION} \
    -t /binaries \
    -d /bitcoin-global

### Generate configuration
cat <<CONFIG > /binaries/.bitglobal/bitglob.conf
listen=1
maxconnections=64
upnp=1
txindex=1

dbcache=64
par=2
checkblocks=24
checklevel=0

disablewallet=1
datadir=${BITCOIN_DATA_DIR}

rpcallowip=127.0.0.1
rpcuser=${BITCOIN_RPC_USERNAME}
rpcpassword=${BITCOIN_RPC_PASSWORD}

[${BITCOIN_NETWORK_TYPE}]
port=${BITCOIN_PORT}
bind=0.0.0.0
rpcbind=127.0.0.1
rpcport=18444
CONFIG

### Generate script
cat <<SCRIPT > /binaries/bin/bitglob-service.sh
#!/bin/bash
/binaries/bin/bitglobd -conf=/binaries/.bitglobal/bitglob.conf $ENTRYPOINT_COMMAND
SCRIPT
chmod +x /binaries/bin/bitglob-service.sh

### Generate service
cat <<SRVCCFG > /etc/systemd/system/bitglobd.service
[Unit]
Description=Bitcoin Global Daemon service
After=network.target

[Service]
ExecStart=/binaries/bin/bitglob-service.sh
User=bitcoin
LimitNOFILE=8192
TimeoutStopSec=30min
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
SRVCCFG

### Run service
systemctl daemon-reload && systemctl enable bitglobd
systemctl daemon-reload && systemctl restart bitglobd
echo "Service deployed! Success!"
