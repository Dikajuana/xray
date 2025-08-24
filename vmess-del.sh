#!/usr/bin/env bash
# DELETE VMESS USER

CONFIG="/usr/local/etc/xray/config.json"
USER_DB="/etc/xray/vmess-users.json"

clear
echo "=========================="
echo "      DELETE VMESS USER"
echo "=========================="
jq -r '.[].user' $USER_DB
echo
read -rp "Masukkan username/remarks yang akan dihapus: " REMARKS

if ! jq -e --arg user "$REMARKS" '.[] | select(.user==$user)' $USER_DB >/dev/null; then
  echo "⚠️ User $REMARKS tidak ditemukan."
  exit 1
fi

# Hapus dari user DB
TMP=$(mktemp)
jq --arg user "$REMARKS" 'del(.[] | select(.user==$user))' $USER_DB > $TMP && mv $TMP $USER_DB

# Hapus dari config.json
TMP=$(mktemp)
jq --arg user "$REMARKS" '
  (.inbounds[] | select(.tag=="vmess-ws").settings.clients) |= map(select(.email!=$user)) |
  (.inbounds[] | select(.tag=="vmess-grpc").settings.clients) |= map(select(.email!=$user))
' $CONFIG > $TMP && mv $TMP $CONFIG

systemctl restart xray

rm -f /var/www/html/vmess-${REMARKS}.txt

echo "✅ User $REMARKS berhasil dihapus."
