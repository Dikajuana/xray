#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# XRAY + NGINX + CERTBOT + FAIL2BAN + UFW (ALL-IN-ONE)
# =========================================================
# Ports Mapping:
# VMESS WS       : 80  (via Nginx -> Xray :10001)
# VMESS WS+TLS   : 443 (via Nginx -> Xray :10001)
# VMESS gRPC TLS : 443 (via Nginx -> Xray :20001)
# VLESS WS       : 80  (via Nginx -> Xray :10002)
# VLESS WS+TLS   : 443 (via Nginx -> Xray :10002)
# VLESS gRPC TLS : 443 (via Nginx -> Xray :20002)
# TROJAN WS+TLS  : 443 (via Nginx -> Xray :10003)
# TROJAN gRPC TLS: 443 (via Nginx -> Xray :20003)
# =========================================================

if [[ $EUID -ne 0 ]]; then
  echo "⚠️ Jalankan sebagai root."
  exit 1
fi

# --- Input Domain ---
read -rp "Masukkan domain (A record sudah diarahkan ke IP VPS ini): " DOMAIN
if [[ -z "${DOMAIN:-}" ]]; then
  echo "⚠️ Domain tidak boleh kosong."
  exit 1
fi

# --- Update & Dependencies ---
apt update -y
apt upgrade -y
apt install -y curl jq socat cron nginx certbot python3-certbot-nginx fail2ban ufw lsb-release

# --- Install Xray Core (resmi) ---
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# --- Struktur Direktori ---
mkdir -p /etc/xray
mkdir -p /usr/local/etc/xray
mkdir -p /var/www/html
touch /etc/xray/vmess-users.json
[ ! -s /etc/xray/vmess-users.json ] && echo "[]" > /etc/xray/vmess-users.json
echo "DOMAIN=$DOMAIN" > /etc/xray/domain.conf

# --- Nginx sementara (HTTP saja) untuk verifikasi cert ---
cat >/etc/nginx/sites-available/$DOMAIN.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/$DOMAIN.conf
[ -e /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# --- Dapatkan sertifikat Let's Encrypt ---
EMAIL="admin@$DOMAIN"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
  echo "⚠️ Sertifikat tidak ditemukan. Pastikan domain mengarah ke IP VPS & ulangi."
  exit 1
fi

# --- Xray Config (listen di port internal, Nginx handle 80/443) ---
cat >/usr/local/etc/xray/config.json <<'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    }
  },
  "inbounds": [
    {
      "tag": "vmess-ws",
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "tag": "vless-ws",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vless" }
      }
    },
    {
      "tag": "trojan-ws",
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/trojan" }
      }
    },
    {
      "tag": "vmess-grpc",
      "port": 20001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "vmess-grpc" }
      }
    },
    {
      "tag": "vless-grpc",
      "port": 20002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "vless-grpc" }
      }
    },
    {
      "tag": "trojan-grpc",
      "port": 20003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "trojan-grpc" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ]
}
EOF

# --- Nginx reverse proxy untuk WS & gRPC ---
cat >/etc/nginx/snippets/xray-common.conf <<'EOF'
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $host;
proxy_http_version 1.1;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
EOF

cat >/etc/nginx/sites-available/$DOMAIN.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/html;
    index index.html;

    location /.well-known/acme-challenge/ { allow all; }

    # Non-TLS WS
    location /vmess { include snippets/xray-common.conf; proxy_pass http://127.0.0.1:10001; }
    location /vless { include snippets/xray-common.conf; proxy_pass http://127.0.0.1:10002; }

    location / { try_files \$uri \$uri/ =404; }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate     $CERT;
    ssl_certificate_key $KEY;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    # WS (TLS)
    location /vmess  { include snippets/xray-common.conf; proxy_pass http://127.0.0.1:10001; }
    location /vless  { include snippets/xray-common.conf; proxy_pass http://127.0.0.1:10002; }
    location /trojan { include snippets/xray-common.conf; proxy_pass http://127.0.0.1:10003; }

    # gRPC (TLS)
    location /vmess-grpc  { grpc_pass grpc://127.0.0.1:20001; }
    location /vless-grpc  { grpc_pass grpc://127.0.0.1:20002; }
    location /trojan-grpc { grpc_pass grpc://127.0.0.1:20003; }

    location /files/ {
        alias /var/www/html/;
        autoindex on;
    }
}
EOF

nginx -t
systemctl reload nginx

# --- Fail2ban basic ---
cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h

[nginx-http-auth]
enabled = true

[nginx-badbots]
enabled = true

[nginx-botsearch]
enabled = true
EOF
systemctl restart fail2ban

# --- Firewall (UFW) ---
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# --- Enable & start services ---
systemctl enable xray
systemctl restart xray
systemctl restart nginx

# --- Certbot auto-renew ---
( crontab -l 2>/dev/null; echo '0 3 * * * certbot renew --quiet --deploy-hook "systemctl reload nginx; systemctl restart xray"' ) | crontab -

clear
echo "=================================================="
echo " INSTALLER SELESAI ✅"
echo "=================================================="
echo "Domain      : $DOMAIN"
echo "Cert        : $CERT"
echo "Key         : $KEY"
echo "Xray Config : /usr/local/etc/xray/config.json"
echo "User DB     : /etc/xray/vmess-users.json"
echo "Static Path : /var/www/html (akses: https://$DOMAIN/files/ )"
echo "=================================================="
echo "Mapping:"
echo "- VMESS WS (80):        http://$DOMAIN/vmess"
echo "- VMESS WS TLS (443):   https://$DOMAIN/vmess"
echo "- VMESS gRPC (443):     https://$DOMAIN/vmess-grpc"
echo "- VLESS WS (80):        http://$DOMAIN/vless"
echo "- VLESS WS TLS (443):   https://$DOMAIN/vless"
echo "- VLESS gRPC (443):     https://$DOMAIN/vless-grpc"
echo "- TROJAN WS TLS (443):  https://$DOMAIN/trojan"
echo "- TROJAN gRPC (443):    https://$DOMAIN/trojan-grpc"
echo "=================================================="
echo "Jalankan menu manajemen dengan perintah: menu.sh"
echo "=================================================="
echo
echo "✅ Instalasi selesai"
echo "Tekan ENTER untuk masuk ke XRAY MANAGEMENT..."
read
clear
bash /usr/local/bin/menu.sh

