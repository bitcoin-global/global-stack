#!/bin/bash
###############################################################################
#
#                             deploy-explorer.sh
#
# This is the install script for Bitcoin Global public explorer server.
#
###############################################################################

### Configuration
BITCOIN_RPC_USERNAME=${BITCOIN_RPC_USERNAME:-admin}
BITCOIN_RPC_PASSWORD=${BITCOIN_RPC_PASSWORD:-verysecretpassword}
BITCOIN_RPC_PORT=${BITCOIN_RPC_PORT:-18444}
BITCOIN_NETWORK_TYPE=${BITCOIN_NETWORK_TYPE:-testnet}
IN_LOCATION=${IN_LOCATION:-europe}
CERTBOT_EMAIL=${CERTBOT_EMAIL:-admin@bitcoin-global.io}
PUBLIC_DOMAIN=${PUBLIC_DOMAIN}

 ### Install requirements
apt update -y && apt upgrade -y
apt install -y git python-software-properties software-properties-common nginx gcc g++ make
add-apt-repository ppa:certbot/certbot -y
apt update -y && apt upgrade -y
apt install -y python-certbot-nginx
python3 -m pip install cffi
npm install pm2 --global

### Deploy certificates for regional server
if [ ! -f /etc/letsencrypt/live/${PUBLIC_DOMAIN}/cert.pem ]; then
certbot --nginx --agree-tos -n \
    -d ${PUBLIC_DOMAIN} \
    -m ${CERTBOT_EMAIL}
fi

### Create nginx config
cat <<CERTS > /etc/nginx/sites-available/${PUBLIC_DOMAIN}.conf
server {
    server_name ${PUBLIC_DOMAIN};
    listen 80;
    #listen [::]:80 ipv6only=on;

    location / {
        return 301 https://${PUBLIC_DOMAIN}\$request_uri;
    }
}

server {
    server_name ${PUBLIC_DOMAIN};
    listen 443 ssl http2;
    #listen [::]:443 ssl http2 ipv6only=on;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    ssl_certificate     /etc/letsencrypt/live/${PUBLIC_DOMAIN}/cert.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PUBLIC_DOMAIN}/privkey.pem;

    location / {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
    }
}
CERTS

### Enable nginx mapping
ln -s /etc/nginx/sites-available/*.conf /etc/nginx/sites-enabled/
rm -rf /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-available/default
fuser -k 80/tcp
fuser -k 443/tcp
service nginx restart

cd /etc/ssl/certs
if [ ! -f dhparam.pem ]; then
    openssl dhparam -out dhparam.pem 4096
fi

### Install explorer
rm -rf /explorer
git clone https://github.com/bitcoin-global/explorer.git /explorer
cd /explorer
npm install || echo "Skipping"

### Generate explorer configuration
mkdir -p ~/.config
cat <<CONFIG > ~/.config/glob-rpc-explorer.env
BGEXP_HOST=127.0.0.1
BGEXP_PORT=3002
BGEXP_BITGLOBD_HOST=127.0.0.1
BGEXP_BITGLOBD_PORT=${BITCOIN_RPC_PORT}
BGEXP_BITGLOBD_USER=${BITCOIN_RPC_USERNAME}
BGEXP_BITGLOBD_PASS=${BITCOIN_RPC_PASSWORD}
BGEXP_ADDRESS_API=electrumx
BGEXP_ELECTRUMX_SERVERS=ssl://127.0.0.1:50001
CONFIG

### Generate service configuration
chmod +x /explorer/bin/www
cat <<SRVCCFG > /etc/systemd/system/explorer.service
[Unit]
Description=Bitcoin Explorer service
After=network.target

[Service]
ExecStart=/explorer/bin/www
User=explorer
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
