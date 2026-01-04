#!/bin/bash

# --- AUTO-DETECTION OF PREFIX ---
DETECTED_IF=$(ls /sys/class/net | grep "-eth0" | head -n 1)
if [ -z "$DETECTED_IF" ]; then
    echo "ERROR: Could not detect network interface pattern."
    exit 1
fi

# We strip the "-eth0" suffix to get just "fw1" or "fw2"
PREFIX=${DETECTED_IF%-eth0}

echo "Detected Prefix: $PREFIX"

# --- Interface Definitions ---
WAN_IF="${PREFIX}-eth0"
DMZ_IF="${PREFIX}-eth1"
LAN_IF="${PREFIX}-eth2"
VPN_IF="${PREFIX}-eth3"
ADM_IF="${PREFIX}-eth4"

# 1. Nettoyage
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
ip route add 10.8.0.0/24 via 10.0.3.2 2>/dev/null

# 2. Politique par défaut (Zero Trust)
iptables -P FORWARD DROP
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT

# 3. Règles de base
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 5. ICMP
iptables -A INPUT -p icmp -j ACCEPT
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -p icmp -j ACCEPT
iptables -A FORWARD -i $ADM_IF -p icmp -j ACCEPT

# 6. Règles DMZ
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport 443 -j ACCEPT

# === CORRECTIF MANUEL INTÉGRÉ : ADMIN -> DMZ ===
# Indispensable pour que le script de validation (curl) fonctionne
iptables -A FORWARD -i $ADM_IF -o $DMZ_IF -j ACCEPT

# 7. Autres Zones
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT
iptables -A FORWARD -i $WAN_IF -o $VPN_IF -p udp --dport 1194 -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $LAN_IF -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $ADM_IF -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $DMZ_IF -j ACCEPT

# 4. === CORRECTIF MANUEL INTÉGRÉ : LOG EN PREMIER ===
# On logue les tentatives de connexion AVANT de les accepter ou refuser
# Cela garantit que le script de validation trouve des traces
# ----> MOVED after all ACCEPT rules
iptables -A FORWARD -j LOG --log-prefix "FW-DROP-FORWARD: " --log-level 4

# 8. SSH
iptables -A INPUT -i $ADM_IF -p tcp --dport 2222 -j ACCEPT
iptables -A INPUT -i $VPN_IF -p tcp --dport 2222 -j ACCEPT

# 9. NAT
iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE

echo "[OK] Pare-feu configuré (Version Finale)."
