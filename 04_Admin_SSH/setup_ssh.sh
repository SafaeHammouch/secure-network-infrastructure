#!/bin/bash

# ==========================================
# CONFIGURATION SSH SÉCURISÉE - PROJET LSI3
# ==========================================
# Objectifs:
# - Désactiver l'authentification par mot de passe
# - Autoriser uniquement l'authentification par clé publique
# - Restreindre l'accès SSH aux zones ADMIN et VPN
# - Utiliser un port non-standard (2222)
# - Durcissement de la configuration SSH
# ==========================================

SSH_PORT=2222
SSH_DIR="/root/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_BACKUP="/etc/ssh/sshd_config.backup"

echo "[*] Installation d'OpenSSH Server si nécessaire..."
if ! command -v sshd &> /dev/null; then
    apt-get update && apt-get install -y openssh-server
fi

echo "[*] Création du répertoire .ssh..."
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# ==========================================
# 1. GÉNÉRATION DES CLÉS SSH (si absentes)
# ==========================================
echo "[*] Génération de la paire de clés SSH..."

# Clé pour l'administrateur
if [ ! -f "admin_key" ]; then
    ssh-keygen -t rsa -b 4096 -f admin_key -N "" -C "admin@lsi3-project"
    echo "[OK] Clé admin générée: admin_key (privée) et admin_key.pub (publique)"
else
    echo "[INFO] Clé admin existante trouvée"
fi

# Clé pour l'accès VPN
if [ ! -f "vpn_key" ]; then
    ssh-keygen -t rsa -b 4096 -f vpn_key -N "" -C "vpn-user@lsi3-project"
    echo "[OK] Clé VPN générée: vpn_key (privée) et vpn_key.pub (publique)"
else
    echo "[INFO] Clé VPN existante trouvée"
fi

# ==========================================
# 2. INSTALLATION DES CLÉS PUBLIQUES
# ==========================================
echo "[*] Installation des clés publiques autorisées..."

# Créer le fichier authorized_keys avec les deux clés
cat admin_key.pub > "$AUTHORIZED_KEYS"
cat vpn_key.pub >> "$AUTHORIZED_KEYS"

chmod 600 "$AUTHORIZED_KEYS"
echo "[OK] Clés publiques installées dans $AUTHORIZED_KEYS"

# ==========================================
# 3. DURCISSEMENT DE LA CONFIGURATION SSH
# ==========================================
echo "[*] Sauvegarde de la configuration SSH originale..."
if [ -f "$SSHD_CONFIG" ] && [ ! -f "$SSHD_CONFIG_BACKUP" ]; then
    cp "$SSHD_CONFIG" "$SSHD_CONFIG_BACKUP"
    echo "[OK] Backup créé: $SSHD_CONFIG_BACKUP"
fi

echo "[*] Application de la configuration SSH sécurisée..."

# Création d'une nouvelle configuration durcie
cat > "$SSHD_CONFIG" <<EOF
# ==========================================
# Configuration SSH Durcie - Projet LSI3
# Modèle Zero Trust
# ==========================================

# Port non-standard pour réduire les scans automatisés
Port $SSH_PORT

# Protocole SSH version 2 uniquement (plus sécurisé)
Protocol 2

# Adresses d'écoute (toutes les interfaces)
ListenAddress 0.0.0.0

# ==========================================
# AUTHENTIFICATION SÉCURISÉE
# ==========================================

# DÉSACTIVATION de l'authentification par mot de passe
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# ACTIVATION de l'authentification par clé publique
PubkeyAuthentication yes
AuthorizedKeysFile $AUTHORIZED_KEYS

# Désactiver les méthodes d'authentification obsolètes
HostbasedAuthentication no
IgnoreRhosts yes
PermitRootLogin prohibit-password

# ==========================================
# RESTRICTIONS D'ACCÈS
# ==========================================

# Autoriser uniquement l'utilisateur root (à adapter selon besoins)
AllowUsers root

# Limiter les tentatives de connexion
MaxAuthTries 3
MaxSessions 2

# Timeout pour l'authentification
LoginGraceTime 30

# ==========================================
# SÉCURITÉ RÉSEAU
# ==========================================

# Désactiver le forwarding X11 (non nécessaire pour l'admin)
X11Forwarding no

# Désactiver le forwarding de port (peut être activé si besoin)
AllowTcpForwarding no
AllowStreamLocalForwarding no
GatewayPorts no

# Désactiver l'agent forwarding
AllowAgentForwarding no

# ==========================================
# DURCISSEMENT CRYPTOGRAPHIQUE
# ==========================================

# Algorithmes de chiffrement modernes
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Algorithmes MAC sécurisés
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Algorithmes d'échange de clés
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# ==========================================
# JOURNALISATION
# ==========================================

# Niveau de log détaillé pour audit
LogLevel VERBOSE
SyslogFacility AUTH

# ==========================================
# OPTIMISATIONS
# ==========================================

# Keep-alive pour éviter les déconnexions
ClientAliveInterval 300
ClientAliveCountMax 2

# Compression (peut être désactivée pour plus de sécurité)
Compression no

# Banner de connexion (optionnel)
# Banner /etc/ssh/banner.txt

# ==========================================
# RESTRICTIONS PAR IP (via iptables, voir firewall.sh)
# L'accès SSH est contrôlé par le pare-feu:
# - Autorisé depuis le réseau ADMIN (10.0.4.0/24)
# - Autorisé depuis le VPN (10.0.3.0/24 ou 10.8.0.0/24)
# - BLOQUÉ depuis toutes les autres sources
# ==========================================

# Subsystem SFTP (si nécessaire pour transfert de fichiers)
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

echo "[OK] Configuration SSH durcie appliquée"

# ==========================================
# 4. PERMISSIONS ET SÉCURITÉ
# ==========================================
echo "[*] Application des permissions restrictives..."

chmod 600 admin_key vpn_key 2>/dev/null
chmod 644 admin_key.pub vpn_key.pub 2>/dev/null
chmod 644 "$SSHD_CONFIG"

echo "[OK] Permissions appliquées"

# ==========================================
# 5. REDÉMARRAGE DU SERVICE SSH
# ==========================================
echo "[*] Redémarrage du service SSH..."

# Test de la configuration avant de redémarrer
if sshd -t -f "$SSHD_CONFIG" 2>/dev/null; then
    echo "[OK] Configuration SSH valide"
    
    # Redémarrage du service
    if systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null; then
        echo "[OK] Service SSH redémarré avec succès"
    else
        echo "[WARNING] Impossible de redémarrer le service SSH automatiquement"
        echo "          Exécutez manuellement: systemctl restart sshd"
    fi
else
    echo "[ERROR] Configuration SSH invalide! Restauration du backup..."
    cp "$SSHD_CONFIG_BACKUP" "$SSHD_CONFIG"
    exit 1
fi

# ==========================================
# 6. AFFICHAGE DES INFORMATIONS
# ==========================================
echo ""
echo "=========================================="
echo "Configuration SSH terminée avec succès!"
echo "=========================================="
echo ""
echo " INFORMATIONS IMPORTANTES:"
echo ""
echo "Port SSH: $SSH_PORT"
echo "Méthode d'authentification: Clé publique uniquement"
echo "Mot de passe: DÉSACTIVÉ"
echo ""
echo " Clés générées:"
echo "  - Admin: admin_key (privée) / admin_key.pub (publique)"
echo "  - VPN:   vpn_key (privée) / vpn_key.pub (publique)"
echo ""
echo " Accès autorisé UNIQUEMENT depuis:"
echo "  - Réseau ADMIN (10.0.4.0/24)"
echo "  - Réseau VPN (10.0.3.0/24 et 10.8.0.0/24)"
echo ""
echo " Pour se connecter depuis h_admin:"
echo "  ssh -i admin_key -p $SSH_PORT root@10.0.2.1"
echo "  (ou l'IP de l'interface du FW depuis la zone admin)"
echo ""
echo " Pour se connecter via VPN:"
echo "  ssh -i vpn_key -p $SSH_PORT root@<FW_IP>"
echo ""
echo "  RAPPEL SÉCURITÉ:"
echo "  - Conservez les clés privées en lieu sûr"
echo "  - Ne partagez JAMAIS les clés privées"
echo "  - Les règles de pare-feu contrôlent l'accès"
echo "  - Tous les accès sont journalisés"
echo ""
echo "=========================================="