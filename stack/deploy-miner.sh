#!/bin/bash
###############################################################################
#
#                             deploy-explorer.sh
#
# This is the install script for Bitcoin Global public explorer server.
#
###############################################################################

### Configuration
BITCOIN_RPC_PORT=${BITCOIN_RPC_PORT:-18444}
BITCOIN_P2P_PORT=${BITCOIN_RPC_PORT:-18222}
MINER_PORT=${MINER_PORT:-19222}
BITCOIN_NETWORK_TYPE=${BITCOIN_NETWORK_TYPE:-testnet}
ADDITIONAL_PARAMS="--testnet"
MINER_ADDRESS=${MINER_ADDRESS:-mtH8N2GuwPPLP9tEv82r9FnZdNxRYQp9V8}

### Install explorer
rm -rf /global-p2pool
git clone https://github.com/bitcoin-global/global-p2pool.git /global-p2pool
cd /global-p2pool

### Generate script
cat <<SCRIPT > /binaries/bin/miner-service.sh
#!/bin/bash
python2 /global-p2pool/run_p2pool.py \
    --net bitglobal \
    $ADDITIONAL_PARAMS \
    --give-author 0 \
    --bitcoind-config-path /binaries/.bitglobal/bitglob.conf \
    --bitcoind-rpc-port $BITCOIN_RPC_PORT \
    --bitcoind-p2p-port $BITCOIN_P2P_PORT \
    -a $MINER_ADDRESS
SCRIPT
chmod +x /binaries/bin/miner-service.sh

### Generate service configuration
cat <<SRVCCFG > /etc/systemd/system/miner.service
[Unit]
Description=Bitcoin Miner service
After=bitglobd.target

[Service]
ExecStart=/binaries/bin/miner-service.sh
User=root
LimitNOFILE=8192
TimeoutStopSec=30min
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
SRVCCFG

### Run service
systemctl daemon-reload && systemctl enable miner
systemctl daemon-reload && systemctl restart miner
echo "Service deployed! Success!"
