#!/bin/bash

# Installation d'OpenVPN si absent
if ! command -v openvpn &> /dev/null; then
    echo "[*] Installation d'OpenVPN..."
    apt-get update && apt-get install -y openvpn
fi

# Création d'une clé secrète partagée (Static Key)
# C'est suffisant pour la simulation et évite la complexité PKI
if [ ! -f static.key ]; then
    echo "[*] Génération de la clé VPN..."
    openvpn --genkey --secret static.key
fi

# Configuration Serveur (sera lancé sur h_vpn)
cat > server.conf <<EOF
dev tun
ifconfig 10.8.0.1 10.8.0.2
secret static.key
proto udp
port 1194
keepalive 10 120
cipher AES-256-CBC
verb 3
EOF

# Configuration Client (sera utilisé par h_wan)
cat > client.conf <<EOF
remote 10.0.3.2 1194
dev tun
ifconfig 10.8.0.2 10.8.0.1
secret static.key
proto udp
cipher AES-256-CBC
# --- ROUTE AUTO VERS LAN ---
route 10.0.2.0 255.255.255.0
verb 3
EOF

echo "[OK] Fichiers de configuration VPN générés."