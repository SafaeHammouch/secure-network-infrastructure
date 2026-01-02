#!/bin/bash
# start_snort.sh
# Lance Snort en mode console pour voir les alertes en direct

IFACE=$1
if [ -z "$IFACE" ]; then
    echo "Usage: ./start_snort.sh <interface>"
    echo "Exemple: ./start_snort.sh r-eth1"
    exit 1
fi

echo "[*] Démarrage de Snort sur l'interface $IFACE..."
# -A console : affiche les alertes à l'écran
# -q : mode silencieux (pas de bannière de démarrage)
# -c : fichier de config
# -l : dossier de logs (crée le s'il n'existe pas)

mkdir -p /var/log/snort
snort -A console -q -c snort.conf -i $IFACE
