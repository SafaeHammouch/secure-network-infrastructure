#!/bin/bash

# --- AUTO-DETECTION ---
DETECTED_IF=$(ls /sys/class/net | grep "\-eth0" | head -n 1)
if [ -z "$DETECTED_IF" ]; then
    echo "ERROR: Could not detect network interface pattern."
    exit 1
fi
PREFIX=${DETECTED_IF%-eth0}
echo "Detected Prefix: $PREFIX"

WAN_IF="${PREFIX}-eth0"
DMZ_IF="${PREFIX}-eth1"
LAN_IF="${PREFIX}-eth2"
VPN_IF="${PREFIX}-eth3"
ADM_IF="${PREFIX}-eth4"

# 1. Nettoyage (Flushing old rules)
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
ip route add 10.8.0.0/24 via 10.0.3.2 2>/dev/null

# 2. Politique par défaut (Zero Trust)
iptables -P FORWARD DROP
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT

# 3. LOGGING (Mettez ceci EN PREMIER pour déboguer)
# On logue TOUT paquet ICMP (Ping) qui traverse le routeur
iptables -A FORWARD -p icmp -j LOG --log-prefix "FW-PING-TRACE: " --log-level 4

# 4. Règles de base
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 5. ICMP (Autoriser le Ping de PARTOUT pour le test)
# Cela corrige votre problème de Ping "100% loss"
iptables -A INPUT -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT

# 6. Règles DMZ
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -i $ADM_IF -o $DMZ_IF -j ACCEPT

# 7. Autres Zones
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT
iptables -A FORWARD -i $WAN_IF -o $VPN_IF -p udp --dport 1194 -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $LAN_IF -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $ADM_IF -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $DMZ_IF -j ACCEPT

# 8. Log des paquets rejetés (Tout ce qui n'a pas été accepté avant)
iptables -A FORWARD -j LOG --log-prefix "FW-DROP-FINAL: " --log-level 4

# 9. SSH
iptables -A INPUT -i $ADM_IF -p tcp --dport 2222 -j ACCEPT
iptables -A INPUT -i $VPN_IF -p tcp --dport 2222 -j ACCEPT

# 10. NAT
iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE

echo "[OK] Pare-feu configuré (ICMP autorisé)."