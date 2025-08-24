#!/usr/bin/env bash
# EXTEND VMESS USER

USER_DB="/etc/xray/vmess-users.json"

clear
echo "=========================="
echo "     EXTEND VMESS USER"
echo "=========================="
jq -r '.[].user' $USER_DB
echo
read -rp "Masukkan username/remarks: " REMARKS

if ! jq -e --arg user "$REMARKS" '.[] | select(.user==$user)' $USER_DB >/dev/null; then
  echo "⚠️ User $REMARKS tidak ditemukan."
  exit 1
fi

read -rp "Tambahkan masa aktif (hari): " ADD_DAYS
read -rp "Limit GB baru (atau kosong untuk tidak ubah): " NEW_GB
read -rp "Limit IP baru (atau kosong untuk tidak ubah): " NEW_IP

CUR_EXP=$(jq -r --arg user "$REMARKS" '.[] | select(.user==$user).exp' $USER_DB)
NEW_EXP=$(date -d "$CUR_EXP +$ADD_DAYS days" +"%Y-%m-%d")

TMP=$(mktemp)
jq --arg user "$REMARKS" --arg exp "$NEW_EXP" --arg gb "$NEW_GB" --arg ip "$NEW_IP" '
  map(if .user==$user then
    .exp=$exp
    | (if $gb!="" then .limitGB=$gb else . end)
    | (if $ip!="" then .limitIP=$ip else . end)
  else . end)
' $USER_DB > $TMP && mv $TMP $USER_DB

echo "✅ User $REMARKS diperpanjang sampai $NEW_EXP."
