#!/usr/bin/env bash
# ADD VMESS USER

CONFIG="/usr/local/etc/xray/config.json"
USER_DB="/etc/xray/vmess-users.json"
DOMAIN=$(cat /etc/xray/domain.conf | cut -d= -f2)

clear
echo "=========================="
echo "       ADD VMESS USER"
echo "=========================="
read -rp "Remarks (username): " REMARKS
read -rp "Masa aktif (hari): " DAYS
read -rp "Limit GB (contoh: 10): " LIMIT_GB
read -rp "Limit IP (contoh: 2): " LIMIT_IP

UUID=$(cat /proc/sys/kernel/random/uuid)
EXP_DATE=$(date -d "$DAYS days" +"%Y-%m-%d")

# Tambah ke user DB
TMP=$(mktemp)
jq --arg user "$REMARKS" --arg uuid "$UUID" \
   --arg exp "$EXP_DATE" --arg gb "$LIMIT_GB" --arg ip "$LIMIT_IP" \
   '. += [{"user":$user,"uuid":$uuid,"exp":$exp,"limitGB":$gb,"limitIP":$ip}]' \
   $USER_DB > $TMP && mv $TMP $USER_DB

# Tambah ke config.json (inbound vmess-ws & vmess-grpc)
TMP=$(mktemp)
jq --arg uuid "$UUID" --arg user "$REMARKS" '
  (.inbounds[] | select(.tag=="vmess-ws").settings.clients) += [{"id":$uuid,"alterId":0,"email":$user}] |
  (.inbounds[] | select(.tag=="vmess-grpc").settings.clients) += [{"id":$uuid,"alterId":0,"email":$user}]
' $CONFIG > $TMP && mv $TMP $CONFIG

# Restart service
systemctl restart xray

# Base64 links
VMESS_TLS=$(echo -n '{
 "v": "2",
 "ps": "'$REMARKS' TLS",
 "add": "'$DOMAIN'",
 "port": "443",
 "id": "'$UUID'",
 "aid": "0",
 "net": "ws",
 "path": "/vmess",
 "type": "none",
 "host": "'$DOMAIN'",
 "tls": "tls"
}' | base64 -w0)

VMESS_NTLS=$(echo -n '{
 "v": "2",
 "ps": "'$REMARKS' NTLS",
 "add": "'$DOMAIN'",
 "port": "80",
 "id": "'$UUID'",
 "aid": "0",
 "net": "ws",
 "path": "/vmess",
 "type": "none",
 "host": "'$DOMAIN'",
 "tls": "none"
}' | base64 -w0)

VMESS_GRPC=$(echo -n '{
 "v": "2",
 "ps": "'$REMARKS' gRPC",
 "add": "'$DOMAIN'",
 "port": "443",
 "id": "'$UUID'",
 "aid": "0",
 "net": "grpc",
 "path": "vmess-grpc",
 "type": "none",
 "host": "'$DOMAIN'",
 "tls": "tls"
}' | base64 -w0)

# Simpan config text untuk OpenClash/Clash
CONF_PATH="/var/www/html/vmess-${REMARKS}.txt"
cat > $CONF_PATH <<EOF
{
 "v": "2",
 "ps": "$REMARKS",
 "add": "$DOMAIN",
 "port": "443",
 "id": "$UUID",
 "aid": "0",
 "net": "ws",
 "path": "/vmess",
 "type": "none",
 "host": "$DOMAIN",
 "tls": "tls"
}
EOF

# --- OUTPUT ---
clear
echo "───────────────────────────"
echo "    Xray/Vmess Account"
echo "───────────────────────────"
echo "Remarks      : $REMARKS"
echo "Domain       : $DOMAIN"
echo "Location     : $(curl -s ipinfo.io/country)"
echo "Port TLS     : 443"
echo "Port non TLS : 80"
echo "Port GRPC    : 443"
echo "AlterId      : 0"
echo "Security     : auto"
echo "Network      : WS / gRPC"
echo "Path         : /vmess"
echo "ServiceName  : vmess-grpc"
echo "User ID      : $UUID"
echo "───────────────────────────"
echo "TLS Link    : vmess://$VMESS_TLS"
echo "───────────────────────────"
echo "NTLS Link   : vmess://$VMESS_NTLS"
echo "───────────────────────────"
echo "GRPC Link   : vmess://$VMESS_GRPC"
echo "───────────────────────────"
echo "OpenClash Format : https://$DOMAIN/files/vmess-${REMARKS}.txt"
echo "───────────────────────────"
echo "Limit GB    : ${LIMIT_GB}GB"
echo "Limit IP    : $LIMIT_IP"
echo "Expires On  : $EXP_DATE"
echo "───────────────────────────"
