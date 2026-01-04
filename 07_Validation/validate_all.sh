#!/bin/bash
# =============================================================
# Script de Validation Globale - Infrastructure Zero Trust
# T10, T11, T12 - Tests automatisés
# =============================================================

# Détection du chemin du projet (dynamique)
PROJECT_DIR="/home/zakariae-azn/secure-network-infrastructure"
REPORT_FILE="/tmp/validation_report_$(date +%Y%m%d_%H%M%S).txt"
JSON_REPORT="/tmp/validation_report_$(date +%Y%m%d_%H%M%S).json"
PASSED=0
FAILED=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Vérification des droits root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERREUR] Ce script doit être exécuté en root (sudo)${NC}"
  exit 1
fi

# Vérification des dépendances
if ! command -v nmap &> /dev/null; then
    echo -e "${YELLOW}[INFO] Installation de nmap...${NC}"
    apt-get update && apt-get install -y nmap
fi

log() { echo -e "$1" | tee -a "$REPORT_FILE"; }
pass() { log "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
fail() { log "${RED}[FAIL]${NC} $1"; ((FAILED++)); }
info() { log "${BLUE}[INFO]${NC} $1"; }

# =============================================================
# HEADER
# =============================================================
log "============================================================="
log "   VALIDATION GLOBALE - Infrastructure Zero Trust"
log "   Date: $(date)"
log "============================================================="
log ""

# =============================================================
# T10.1 - Résistance aux scans
# =============================================================
info ">>> T10.1 - Résistance aux scans (Target: DMZ 10.0.1.2)"

# Test: Scan des ports ouverts vers DMZ
# On s'attend à 80 et 443 uniquement (parfois 22 si admin, mais bloqué depuis WAN)
OPEN_PORTS=$(timeout 30 nmap -sS -p 1-1024 10.0.1.2 2>/dev/null | grep "open" | wc -l)

if [ "$OPEN_PORTS" -le 3 ]; then
    pass "Exposition minimale respectée: $OPEN_PORTS ports ouverts"
else
    fail "Trop de ports exposés: $OPEN_PORTS (Attendu: <=3)"
fi

# Test: Scan vers LAN (doit échouer totalement - Zero Trust)
LAN_SCAN=$(timeout 5 nmap -sS -p 80,443 10.0.2.2 -Pn 2>/dev/null | grep "open" | wc -l)

if [ "$LAN_SCAN" -eq 0 ]; then
    pass "Isolation LAN confirmée (0 ports accessibles)"
else
    fail "LAN exposé ! ($LAN_SCAN ports ouverts)"
fi

# =============================================================
# T10.2 - Reproductibilité (vérification config)
# =============================================================
log ""
info ">>> T10.2 - Reproductibilité et Fichiers"

CONFIGS=(
    "$PROJECT_DIR/01_Firewall/rules.sh"
    "$PROJECT_DIR/05_IDS_Suricata/suricata.yaml"
    "$PROJECT_DIR/06_HA_Heartbeat/keepalived_master.conf"
)

CONFIG_OK=true
for cfg in "${CONFIGS[@]}"; do
    if [ -f "$cfg" ]; then
        log "  [OK] Found: $(basename $cfg)"
    else
        log "  ${RED}[MISSING]${NC} $cfg"
        CONFIG_OK=false
    fi
done

if $CONFIG_OK; then
    pass "Intégrité des fichiers de configuration"
else
    fail "Fichiers de configuration manquants"
fi

# =============================================================
# T11.1 - Logs pare-feu
# =============================================================
log ""
info ">>> T11.1 - Vérification des Logs Pare-feu"

# On génère un trafic interdit pour être sûr d'avoir un log
ping -c 1 -W 1 10.0.2.2 > /dev/null 2>&1

FW_LOGS=$(dmesg | grep -c "FW-DROP" 2>/dev/null || echo "0")

if [ "$FW_LOGS" -gt 0 ]; then
    pass "Logs pare-feu actifs ($FW_LOGS entrées trouvées)"
    log "  Dernier log: $(dmesg | grep "FW-DROP" | tail -1 | cut -c 1-80)..."
else
    fail "Aucun log pare-feu trouvé (Vérifiez les règles de log)"
fi

# =============================================================
# T11.2 - Logs Suricata
# =============================================================
log ""
info ">>> T11.2 - Vérification des Logs Suricata"

SURICATA_LOG="/var/log/suricata/fast.log"

if [ -f "$SURICATA_LOG" ]; then
    ALERT_COUNT=$(wc -l < "$SURICATA_LOG" 2>/dev/null || echo "0")
    if [ "$ALERT_COUNT" -gt 0 ]; then
        pass "Logs Suricata actifs ($ALERT_COUNT alertes)"
        log "  Dernière alerte: $(tail -1 "$SURICATA_LOG")"
    else
        log "${YELLOW}[WARN]${NC} Fichier Suricata vide (Aucune attaque détectée récemment)"
        pass "Fichier de log présent (vide)"
    fi
else
    fail "Fichier $SURICATA_LOG introuvable"
fi

# =============================================================
# Tests de connectivité (validation fonctionnelle)
# =============================================================
log ""
info ">>> Tests de Connectivité Services"

# DMZ HTTPS
if curl -k -s --connect-timeout 3 https://10.0.1.2 > /dev/null 2>&1; then
    pass "Service Web DMZ (HTTPS) accessible"
else
    fail "Service Web DMZ injoignable"
fi

# VIP HA
if ping -c 1 -W 2 10.0.0.1 > /dev/null 2>&1; then
    pass "Cluster HA (VIP 10.0.0.1) répond"
else
    fail "Cluster HA (VIP) ne répond pas"
fi

# =============================================================
# RAPPORT FINAL
# =============================================================
log ""
log "============================================================="
log "   RÉSULTATS FINAUX"
log "============================================================="
log "Tests réussis:  $PASSED"
log "Tests échoués:  $FAILED"
log "Total:          $((PASSED + FAILED))"

if [ "$FAILED" -eq 0 ]; then
    log "${GREEN}>>> SUCCÈS GLOBAL DU DÉPLOIEMENT <<<${NC}"
    RESULT="SUCCESS"
else
    log "${RED}>>> ÉCHEC DU DÉPLOIEMENT ($FAILED erreurs) <<<${NC}"
    RESULT="FAILURE"
fi

log ""
log "Rapport texte: $REPORT_FILE"
log "Rapport JSON:  $JSON_REPORT"

# Génération JSON
cat > "$JSON_REPORT" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "result": "$RESULT",
  "stats": {
    "passed": $PASSED,
    "failed": $FAILED,
    "total": $((PASSED + FAILED))
  },
  "details": {
    "T10.1_scan_resistance": "$([ "$OPEN_PORTS" -le 3 ] && echo "PASS" || echo "FAIL")",
    "T10.2_reproducibility": "$([ "$CONFIG_OK" = true ] && echo "PASS" || echo "FAIL")",
    "T11.1_firewall_logs": "$([ "$FW_LOGS" -gt 0 ] && echo "PASS" || echo "FAIL")",
    "T11.2_suricata_logs": "$([ -f "$SURICATA_LOG" ] && echo "PASS" || echo "FAIL")"
  }
}
EOF
