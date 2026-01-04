#!/bin/bash
# ========================================
# Script de lancement Suricata IDS
# ========================================

INTERFACE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/suricata.yaml"
LOG_DIR="/var/log/suricata"

if [ -z "$INTERFACE" ]; then
    echo "Usage: $0 <interface>"
    echo "Exemple: $0 fw-eth1"
    exit 1
fi

# Créer le répertoire de logs
mkdir -p $LOG_DIR 2>/dev/null

# Vérifier si Suricata est installé
if ! command -v suricata &> /dev/null; then
    echo "[INFO] Installation de Suricata..."
    apt-get update -qq
    apt-get install -y suricata 2>/dev/null || {
        echo "[ERREUR] Impossible d'installer Suricata"
        exit 1
    }
fi

echo "[INFO] Démarrage de Suricata sur l'interface $INTERFACE"
echo "[INFO] Configuration: $CONF_FILE"
echo "[INFO] Logs: $LOG_DIR"

# Lancer Suricata en mode IDS
suricata -c $CONF_FILE -i $INTERFACE -l $LOG_DIR -D

sleep 2
SURICATA_PID=$(pgrep -f "suricata.*$INTERFACE")

if [ ! -z "$SURICATA_PID" ]; then
    echo "[OK] Suricata démarré (PID: $SURICATA_PID)"
    echo "[INFO] Alertes: tail -f $LOG_DIR/fast.log"
else
    echo "[ERREUR] Échec du démarrage de Suricata"
    exit 1
fi
