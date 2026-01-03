#!/bin/bash
# ========================================
# Script de lancement Snort IDS
# ========================================

INTERFACE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/snort.conf"
LOG_DIR="/var/log/snort"

if [ -z "$INTERFACE" ]; then
    echo "Usage: $0 <interface>"
    echo "Exemple: $0 r-eth1"
    exit 1
fi

# Créer le répertoire de logs
mkdir -p $LOG_DIR 2>/dev/null

# Vérifier si Snort est installé
if ! command -v snort &> /dev/null; then
    echo "[INFO] Installation de Snort..."
    apt-get update -qq
    apt-get install -y snort 2>/dev/null || {
        echo "[ERREUR] Impossible d'installer Snort"
        exit 1
    }
fi

echo "[INFO] Démarrage de Snort sur l'interface $INTERFACE"
echo "[INFO] Configuration: $CONF_FILE"
echo "[INFO] Logs: $LOG_DIR"

# Lancer Snort en mode IDS
snort -i $INTERFACE -c $CONF_FILE -l $LOG_DIR -A fast -q &

SNORT_PID=$!
echo "[OK] Snort démarré (PID: $SNORT_PID)"
echo "[INFO] Alertes: tail -f $LOG_DIR/alerts.txt"
