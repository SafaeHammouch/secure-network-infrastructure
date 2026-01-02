#!/bin/bash
# setup_ssh.sh - Configure un serveur SSH sécurisé (Clé uniquement)

echo "[SSH] Génération des clés pour l'admin..."
# Génère une paire de clés si elle n'existe pas (sans passphrase pour le test)
if [ ! -f ./id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -f ./id_rsa -q -N ""
fi

echo "[SSH] Configuration du serveur SSH..."
# Création du dossier .ssh pour l'utilisateur root de la machine cible
mkdir -p /root/.ssh
cat ./id_rsa.pub > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Création du fichier de config sécurisé (Port 2222, Pas de mot de passe)
cat > /etc/ssh/sshd_config_secure <<EOF
Port 2222
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
AuthorizedKeysFile /root/.ssh/authorized_keys
PidFile /var/run/sshd_custom.pid
EOF

echo "[SSH] Démarrage du service SSH sur le port 2222..."
# On lance sshd avec notre config
/usr/sbin/sshd -f /etc/ssh/sshd_config_secure

echo "[SSH] Serveur prêt. Connectez-vous avec : ssh -p 2222 -i ./id_rsa root@<IP>"
