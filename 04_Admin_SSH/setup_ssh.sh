#!/bin/bash
# setup_ssh_fixed.sh - Configuration SSH sécurisée avec vérifications

set -e  # Arrêter en cas d'erreur

echo "=========================================="
echo "Configuration SSH Sécurisé - Zero Trust"
echo "=========================================="

# ==========================================
# 1. Vérification de l'installation de SSH
# ==========================================
echo ""
echo "[1] Vérification du serveur SSH..."
if ! command -v sshd &> /dev/null; then
    echo "[!] OpenSSH Server non installé. Installation..."
    apt-get update -qq
    apt-get install -y openssh-server
else
    echo "[✓] OpenSSH Server déjà installé"
fi

# ==========================================
# 2. Génération des Clés SSH
# ==========================================
echo ""
echo "[2] Génération des clés SSH..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_PATH="$SCRIPT_DIR/id_rsa"

if [ -f "$KEY_PATH" ]; then
    echo "[✓] Clé existante trouvée: $KEY_PATH"
else
    echo "[*] Génération d'une nouvelle paire de clés..."
    ssh-keygen -t rsa -b 2048 -f "$KEY_PATH" -q -N "" -C "admin@zerotrust"
    echo "[✓] Clé générée: $KEY_PATH"
fi

# ==========================================
# 3. Configuration du répertoire .ssh
# ==========================================
echo ""
echo "[3] Configuration du répertoire .ssh..."

SSH_DIR="/root/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Ajouter la clé publique aux clés autorisées
cat "$KEY_PATH.pub" > "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"

echo "[✓] Clé publique installée dans $SSH_DIR/authorized_keys"

# ==========================================
# 4. Création de la Configuration SSH Sécurisée
# ==========================================
echo ""
echo "[4] Création de la configuration SSH sécurisée..."

CONFIG_FILE="/etc/ssh/sshd_config_secure"

cat > "$CONFIG_FILE" <<'EOF'
# Configuration SSH Sécurisée - Projet Zero Trust
Port 2222
AddressFamily inet

# Authentification
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Fichiers de clés
AuthorizedKeysFile /root/.ssh/authorized_keys

# Sécurité
UsePAM no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

# Fichiers
PidFile /var/run/sshd_secure.pid
EOF

chmod 644 "$CONFIG_FILE"
echo "[✓] Configuration créée: $CONFIG_FILE"

# ==========================================
# 5. Génération des Clés Hôte (si manquantes)
# ==========================================
echo ""
echo "[5] Vérification des clés hôte SSH..."

if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[*] Génération des clés hôte SSH..."
    ssh-keygen -A
else
    echo "[✓] Clés hôte déjà présentes"
fi

# ==========================================
# 6. Arrêt du service SSH existant
# ==========================================
echo ""
echo "[6] Arrêt des services SSH existants..."

# Tuer tous les processus sshd personnalisés
pkill -f "sshd.*sshd_config_secure" 2>/dev/null || true
pkill -f "sshd.*2222" 2>/dev/null || true

sleep 1
echo "[✓] Services SSH nettoyés"

# ==========================================
# 7. Démarrage du Serveur SSH
# ==========================================
echo ""
echo "[7] Démarrage du serveur SSH sur le port 2222..."

# Test de la configuration avant de démarrer
if /usr/sbin/sshd -t -f "$CONFIG_FILE" 2>&1; then
    echo "[✓] Configuration SSH valide"
else
    echo "[✗] Erreur dans la configuration SSH!"
    /usr/sbin/sshd -t -f "$CONFIG_FILE"
    exit 1
fi

# Démarrage du daemon
/usr/sbin/sshd -f "$CONFIG_FILE"

sleep 2

# ==========================================
# 8. Vérification du Démarrage
# ==========================================
echo ""
echo "[8] Vérification du service..."

if ss -tuln | grep -q ":2222"; then
    echo "[✓] SSH écoute sur le port 2222"
    ss -tuln | grep ":2222"
else
    echo "[✗] ERREUR: SSH n'écoute PAS sur le port 2222"
    echo ""
    echo "Logs d'erreur:"
    tail -20 /var/log/auth.log 2>/dev/null || echo "Fichier de log introuvable"
    exit 1
fi

# Vérifier le processus
if pgrep -f "sshd.*sshd_config_secure" > /dev/null; then
    echo "[✓] Processus SSH actif (PID: $(pgrep -f "sshd.*sshd_config_secure"))"
else
    echo "[✗] ERREUR: Processus SSH introuvable"
    exit 1
fi

# ==========================================
# 9. Instructions Finales
# ==========================================
echo ""
echo "=========================================="
echo "Configuration SSH Terminée avec Succès!"
echo "=========================================="
echo ""
echo "Clé privée générée: $KEY_PATH"
echo "Clé publique: $KEY_PATH.pub"
echo ""
echo "Pour copier la clé sur h_admin:"
echo "  mininet> h_lan cp $KEY_PATH /tmp/"
echo "  mininet> h_admin mkdir -p /root/.ssh && cp /tmp/id_rsa /root/.ssh/ && chmod 600 /root/.ssh/id_rsa"
echo ""
echo "Pour se connecter depuis h_admin:"
echo "  mininet> h_admin ssh -p 2222 -i /root/.ssh/id_rsa root@10.0.2.2"
echo ""
echo "Pour tester localement (sur h_lan):"
echo "  ssh -p 2222 -i $KEY_PATH root@127.0.0.1"
echo ""