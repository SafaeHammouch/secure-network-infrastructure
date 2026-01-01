#!/bin/bash

# ==========================================
# CONFIGURATION DES VARIABLES (Pour la lisibilité)
# ==========================================
WAN_IF="fw-eth0"    # Vers Internet (10.0.0.0/24)
DMZ_IF="fw-eth1"    # Vers Serveurs (10.0.1.0/24)
LAN_IF="fw-eth2"    # Vers Interne (10.0.2.0/24)
VPN_IF="fw-eth3"    # Vers Clients VPN (10.0.3.0/24)
ADM_IF="fw-eth4"    # Vers Admin (10.0.4.0/24)

# ==========================================
# 1. INITIALISATION (Reset complet)
# ==========================================
echo "[*] Nettoyage des règles existantes..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# ==========================================
# 2. POLITIQUE PAR DÉFAUT : ZERO TRUST
# ==========================================
echo "[*] Application de la politique ZERO TRUST (DROP par défaut)..."
# On refuse tout transit
iptables -P FORWARD DROP
# On refuse tout ce qui entre vers le pare-feu
iptables -P INPUT DROP
# On autorise le pare-feu à parler (pour ses mises à jour, DNS, etc.)
iptables -P OUTPUT ACCEPT

# ==========================================
# 3. RÈGLES DE BASE (Infrastructure)
# ==========================================
echo "[*] Autorisation du trafic local et suivi de connexion..."

# Autoriser la boucle locale (localhost) - vital pour le système
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# STATEFUL INSPECTION :
# On autorise les réponses aux connexions légitimes qu'on a initiées
# (Ex: Si le LAN demande une page Web, on laisse revenir la réponse du Web)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Autoriser le PING (ICMP) pour le debug (peut être restreint plus tard)
# Limité à 1 ping par seconde pour éviter le flood
#comment these lines in case of Zero Trust
iptables -A INPUT -p icmp -m limit --limit 1/s -j ACCEPT
iptables -A FORWARD -p icmp -m limit --limit 1/s -j ACCEPT

# ==========================================
# 4. RÈGLES SPÉCIFIQUES PAR ZONES
# ==========================================

# --- A. ACCÈS PUBLIC VERS LA DMZ---
echo "[*] Configuration DMZ..."
# Autoriser HTTP (80) et HTTPS (443) depuis N'IMPORTE OÙ (WAN) vers la DMZ
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport 443 -j ACCEPT

# --- B. ACCÈS LAN VERS INTERNET ---
echo "[*] Configuration LAN..."
# Le LAN peut aller sur Internet (HTTP/HTTPS/DNS)
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

# --- C. ACCÈS VPN  ---
echo "[*] Configuration VPN..."
# Autoriser la connexion au serveur OpenVPN (Port 1194 UDP) sur le FW lui-même
iptables -A FORWARD -i $WAN_IF -o $VPN_IF -p udp --dport 1194 -j ACCEPT
# Une fois dans le tunnel (interface tun0, simulée ici par VPN_IF pour le test),
# on autorise l'accès aux ressources
iptables -A FORWARD -s 10.8.0.0/24 -o $LAN_IF -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $ADM_IF -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -o $DMZ_IF -j ACCEPT

# --- D. ADMINISTRATION ---
echo "[*] Configuration SSH..."
# SSH autorisé UNIQUEMENT depuis le réseau Admin ou VPN vers le Pare-feu
iptables -A INPUT -i $ADM_IF -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i $VPN_IF -p tcp --dport 22 -j ACCEPT

# ==========================================
# 5. JOURNALISATION (LOGGING)
# ==========================================
# Tout ce qui n'a pas été autorisé ci-dessus sera loggué avant d'être DROPpé par la politique par défaut
echo "[*] Activation des logs..."
iptables -A INPUT -j LOG --log-prefix "FW-DROP-INPUT: " --log-level 4
iptables -A FORWARD -j LOG --log-prefix "FW-DROP-FORWARD: " --log-level 4

echo "[OK] Pare-feu configuré avec succès."