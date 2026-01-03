#!/bin/bash
# ========================================
# Corrélation IDS/Firewall - Blocage automatique
# ========================================

LOG_FILE="/var/log/snort/alerts.txt"
BLOCKED_IPS="/tmp/blocked_ips.txt"

touch $BLOCKED_IPS

echo "[INFO] Surveillance des alertes Snort..."
echo "[INFO] Blocage automatique des IPs malveillantes"

# Surveiller les logs en temps réel
tail -F $LOG_FILE 2>/dev/null | while read line; do
    # Extraire l'IP source de l'alerte
    SRC_IP=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
    
    if [ ! -z "$SRC_IP" ]; then
        # Vérifier si l'IP n'est pas déjà bloquée
        if ! grep -q "$SRC_IP" $BLOCKED_IPS; then
            echo "[ALERTE] Détection d'activité malveillante depuis $SRC_IP"
            echo "[ACTION] Blocage de $SRC_IP dans le pare-feu"
            
            # Bloquer l'IP avec iptables
            iptables -I INPUT 1 -s $SRC_IP -j DROP
            iptables -I FORWARD 1 -s $SRC_IP -j DROP
            
            # Enregistrer l'IP bloquée
            echo "$SRC_IP" >> $BLOCKED_IPS
            echo "[OK] IP $SRC_IP bloquée avec succès"
        fi
    fi
done
