#!/bin/bash
# setup_ssh.sh - Configure un serveur SSH sécurisé (Clé uniquement)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[SSH] Génération des clés pour l'admin..."
# Génère une paire de clés si elle n'existe pas
if [ ! -f "$SCRIPT_DIR/id_rsa" ]; then
    ssh-keygen -t rsa -b 2048 -f "$SCRIPT_DIR/id_rsa" -q -N ""
fi

echo "[SSH] Configuration du serveur SSH..."
# Création du dossier .ssh pour l'utilisateur root
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat "$SCRIPT_DIR/id_rsa.pub" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Création du fichier de config sécurisé
cat > /etc/ssh/sshd_config_secure <<EOF
Port 2222
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
AuthorizedKeysFile /root/.ssh/authorized_keys
StrictModes yes
PidFile /var/run/sshd_secure.pid
EOF

echo "[SSH] Démarrage du service SSH sur le port 2222..."
# Arrêter l'instance précédente si elle existe
pkill -f "sshd.*sshd_config_secure" 2>/dev/null

# === MODIFICATION ICI ===
# Création du dossier nécessaire pour la séparation des privilèges SSH
mkdir -p /run/sshd
# ========================

# Lancer sshd avec notre config
/usr/sbin/sshd -f /etc/ssh/sshd_config_secure

if pgrep -f "sshd.*sshd_config_secure" > /dev/null; then
    echo "[SSH] Serveur prêt. Connectez-vous avec : ssh -p 2222 -i $SCRIPT_DIR/id_rsa root@<IP>"
else
    echo "[ERREUR] Échec du démarrage SSH"
    exit 1
fi
