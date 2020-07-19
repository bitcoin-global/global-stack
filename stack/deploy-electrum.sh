#!/bin/bash
###############################################################################
#
#                             deploy-electrum.sh
#
# This is the install script for Bitcoin Global public Electrum server.
#
###############################################################################

### Configuration
BITCOIN_RPC_USERNAME=${BITCOIN_RPC_USERNAME:-admin}
BITCOIN_RPC_PASSWORD=${BITCOIN_RPC_PASSWORD:-verysecretpassword}
BITCOIN_RPC_PORT=${BITCOIN_RPC_PORT:-18444}
BITCOIN_NETWORK_TYPE=${BITCOIN_NETWORK_TYPE:-testnet}
IN_LOCATION=${IN_LOCATION:-europe}

### Install Electrum
rm -rf ~/.electrumx-installer/
wget https://raw.githubusercontent.com/bauerj/electrumx-installer/master/bootstrap.sh -O - | \
    bash -s - \
        --leveldb \
        --update-python \
        --electrumx-git-url https://github.com/bitcoin-global/global-electrumx.git \
        --electrumx-git-branch altcoin

### Generate SSL
touch ~/.rnd
cd /etc/
mkdir -p electrumx.${IN_LOCATION}.${BITCOIN_NETWORK_TYPE}net.bitcoin-global.io
cd electrumx.${IN_LOCATION}.${BITCOIN_NETWORK_TYPE}net.bitcoin-global.io

openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/C=XX/ST=XX/O=Bitcoin Global/OU=ElectrumX/CN=bitcoin-global.io"
openssl x509 -req -days 1825 -in server.csr -signkey server.key -out server.crt

### Generate Electrum configuration
cat <<SRVCCFG > /etc/electrumx.conf
DB_DIRECTORY=/db
DAEMON_URL=http://${BITCOIN_RPC_USERNAME}:${BITCOIN_RPC_PASSWORD}@127.0.0.1:${BITCOIN_RPC_PORT}/
COIN=BitcoinGlobal
NET=${BITCOIN_NETWORK_TYPE}net
SSL_CERTFILE=/etc/electrumx.${IN_LOCATION}.${BITCOIN_NETWORK_TYPE}net.bitcoin-global.io/server.crt
SSL_KEYFILE=/etc/electrumx.${IN_LOCATION}.${BITCOIN_NETWORK_TYPE}net.bitcoin-global.io/server.key
SERVICES=SSL://:50001,SSL://:50002,SSL://:51001,SSL://:51002
SRVCCFG

cat <<SRVCCFG > /etc/systemd/system/electrumx.service
[Unit]
Description=Electrumx Service
After=network.target

[Service]
EnvironmentFile=/etc/electrumx.conf
ExecStart=/usr/local/bin/electrumx_server
User=electrumx
LimitNOFILE=8192
TimeoutStopSec=30min
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
SRVCCFG

### Run service
systemctl daemon-reload && systemctl enable electrumx
systemctl daemon-reload && systemctl restart electrumx
echo "Service deployed! Success!"
