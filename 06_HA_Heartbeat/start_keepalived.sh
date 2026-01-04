#!/bin/bash
# Script de démarrage Keepalived pour HA

ROLE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$ROLE" != "master" ] && [ "$ROLE" != "backup" ]; then
    echo "Usage: $0 [master|backup]"
    exit 1
fi

# Installer Keepalived si nécessaire
if ! command -v keepalived &> /dev/null; then
    echo "[INFO] Installation de Keepalived..."
    apt-get update -qq
    apt-get install -y keepalived 2>/dev/null
fi

# Sélectionner la config
if [ "$ROLE" = "master" ]; then
    CONFIG="$SCRIPT_DIR/keepalived_master.conf"
    echo "[HA] Démarrage en mode MASTER"
else
    CONFIG="$SCRIPT_DIR/keepalived_backup.conf"
    echo "[HA] Démarrage en mode BACKUP"
fi

# Démarrer Keepalived
keepalived -f $CONFIG -D -l

echo "[OK] Keepalived démarré"
echo "[INFO] VIP: 10.0.1.100"
