#!/usr/bin/env bash

while true; do
  clear
  echo "=========================="
  echo "       VMESS MENU"
  echo "=========================="
  echo "1) ADD VMESS"
  echo "2) DELETE VMESS"
  echo "3) LIST VMESS"
  echo "4) EXTEND VMESS"
  echo "x) BACK"
  echo

  read -rp "Pilih menu: " opt
  case $opt in
    1) bash /usr/local/bin/vmess-add.sh; read -n1 -r -p "Tekan tombol apapun untuk kembali...";;
    2) bash /usr/local/bin/vmess-del.sh; read -n1 -r -p "Tekan tombol apapun untuk kembali...";;
    3) bash /usr/local/bin/vmess-list.sh; read -n1 -r -p "Tekan tombol apapun untuk kembali...";;
    4) bash /usr/local/bin/vmess-extend.sh; read -n1 -r -p "Tekan tombol apapun untuk kembali...";;
    x) bash /usr/local/bin/menu.sh; exit 0;;
    *) echo "⚠️ Pilihan salah!"; sleep 1;;
  esac
done
