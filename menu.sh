#!/usr/bin/env bash

while true; do
  clear
  OS=$(lsb_release -d | cut -f2)
  CPU=$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)
  RAM=$(free -h --si | awk '/Mem:/ {print $2}')
  DATE=$(date '+%Y-%m-%d %H:%M:%S')
  IP=$(curl -s ifconfig.me)

  STATUS_XRAY=$(systemctl is-active xray)
  STATUS_NGINX=$(systemctl is-active nginx)

  echo "=========================="
  echo "     PREMIUM SCRIPT"
  echo "=========================="
  echo "OS SYSTEM : $OS"
  echo "CPU       : $CPU"
  echo "RAM       : $RAM"
  echo "DATE      : $DATE"
  echo "LOCATION  : $IP"
  echo "STATUS    : XRAY=$STATUS_XRAY | NGINX=$STATUS_NGINX"
  echo "=========================="
  echo "     XRAY MANAGEMENT"
  echo "=========================="
  echo "1) MENU VMESS"
  echo "2) MENU VLESS"
  echo "3) MENU TROJAN"
  echo "4) RESTART ALL SERVICE"
  echo "x) EXIT"
  echo

  read -rp "Pilih menu: " opt
  case $opt in
    1) bash /usr/local/bin/vmess-menu.sh ;;
    2) bash /usr/local/bin/vless-menu.sh ;;
    3) bash /usr/local/bin/trojan-menu.sh ;;
    4) systemctl restart xray && systemctl restart nginx && echo "✅ Semua service direstart!"; sleep 2;;
    x) exit ;;
    *) echo "⚠️ Pilihan salah!"; sleep 1;;
  esac
done
