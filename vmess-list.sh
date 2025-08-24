#!/usr/bin/env bash
# LIST VMESS USER

USER_DB="/etc/xray/vmess-users.json"
DOMAIN=$(cat /etc/xray/domain.conf | cut -d= -f2)

clear
echo "=========================="
echo "     LIST VMESS USERS"
echo "=========================="

COUNT=$(jq length $USER_DB)
if [[ $COUNT -eq 0 ]]; then
  echo "⚠️ Tidak ada user VMESS."
  exit 0
fi

jq -r '.[] | "\(.user)\t|\tUUID: \(.uuid)\t|\tExp: \(.exp)\t|\tLimit: \(.limitGB)GB / \(.limitIP) IP"' $USER_DB | column -t -s $'\t'
