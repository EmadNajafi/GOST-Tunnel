#!/bin/bash

GOST_BIN="/usr/local/bin/gost"
SERVICE_DIR="/etc/systemd/system"

install_gost() {

if [ -f "$GOST_BIN" ]; then
echo "GOST already installed."
return
fi

echo "Installing GOST..."

apt update
apt install wget iptables bc -y

wget -q https://github.com/ginuerzh/gost/releases/download/v2.11.1/gost-linux-amd64-2.11.1.gz
gunzip gost-linux-amd64-2.11.1.gz

mv gost-linux-amd64-2.11.1 $GOST_BIN
chmod +x $GOST_BIN

echo "GOST installed successfully."
}

create_tunnel() {

read -p "Tunnel name: " NAME

SERVICE_FILE="$SERVICE_DIR/gost-$NAME.service"

if [ -f "$SERVICE_FILE" ]; then
echo "Tunnel already exists."
return
fi

read -p "Local Port: " LPORT
read -p "Destination IP: " DIP
read -p "Destination Port: " DPORT

cat <<EOF > $SERVICE_FILE
[Unit]
Description=GOST Tunnel $NAME
After=network.target

[Service]
Type=simple
ExecStart=$GOST_BIN -L=tcp://:$LPORT/$DIP:$DPORT
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gost-$NAME
systemctl start gost-$NAME

iptables -I INPUT -p tcp --dport $LPORT -j ACCEPT
iptables -I OUTPUT -p tcp --sport $LPORT -j ACCEPT

echo "Tunnel created successfully."
}

edit_tunnel() {

read -p "Tunnel name to edit: " NAME
SERVICE_FILE="$SERVICE_DIR/gost-$NAME.service"

if [ ! -f "$SERVICE_FILE" ]; then
echo "Tunnel not found."
return
fi

echo "Current config:"
grep ExecStart $SERVICE_FILE

read -p "New Local Port: " LPORT
read -p "New Destination IP: " DIP
read -p "New Destination Port: " DPORT

cat <<EOF > $SERVICE_FILE
[Unit]
Description=GOST Tunnel $NAME
After=network.target

[Service]
Type=simple
ExecStart=$GOST_BIN -L=tcp://:$LPORT/$DIP:$DPORT
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart gost-$NAME

echo "Tunnel updated."
}

delete_tunnel() {

read -p "Tunnel name to delete: " NAME

SERVICE_FILE="$SERVICE_DIR/gost-$NAME.service"

if [ ! -f "$SERVICE_FILE" ]; then
echo "Tunnel not found."
return
fi

PORT=$(grep ExecStart $SERVICE_FILE | sed -n 's/.*tcp:\/\/:\([0-9]*\)\/.*/\1/p')

systemctl stop gost-$NAME
systemctl disable gost-$NAME

rm -f $SERVICE_FILE

iptables -D INPUT -p tcp --dport $PORT -j ACCEPT
iptables -D OUTPUT -p tcp --sport $PORT -j ACCEPT

systemctl daemon-reload

echo "Tunnel deleted."
}

restart_tunnel() {

read -p "Tunnel name: " NAME

systemctl restart gost-$NAME

echo "Tunnel restarted."
}

status_tunnels() {

echo "Active GOST tunnels:"
systemctl list-units --type=service | grep gost

}

traffic_tunnel() {

read -p "Enter tunnel local port: " PORT

BYTES=$(iptables -L INPUT -v -n | grep "dpt:$PORT" | awk '{print $2}')

if [ -z "$BYTES" ]; then
echo "No traffic data found."
return
fi

KB=$(echo "scale=2; $BYTES/1024" | bc)
MB=$(echo "scale=2; $BYTES/1024/1024" | bc)
GB=$(echo "scale=2; $BYTES/1024/1024/1024" | bc)

echo "Traffic statistics"
echo "------------------"
echo "Port: $PORT"
echo "Bytes: $BYTES"
echo "KB: $KB"
echo "MB: $MB"
echo "GB: $GB"

}

menu() {

while true
do

echo "================================"
echo "        GOST Tunnel Manager"
echo "================================"
echo "1) Install GOST"
echo "2) Create Tunnel"
echo "3) Edit Tunnel"
echo "4) Delete Tunnel"
echo "5) Restart Tunnel"
echo "6) Tunnel Status"
echo "7) Tunnel Traffic"
echo "0) Exit"
echo "================================"

read -p "Choose option: " CHOICE

case $CHOICE in

1) install_gost ;;
2) create_tunnel ;;
3) edit_tunnel ;;
4) delete_tunnel ;;
5) restart_tunnel ;;
6) status_tunnels ;;
7) traffic_tunnel ;;
0) exit ;;
*) echo "Invalid option" ;;

esac

echo ""

done

}

menu
