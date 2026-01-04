#!/bin/bash
# =============================================================
# Script de Validation Globale - Infrastructure Zero Trust
# T10, T11, T12 - Tests automatisés
# =============================================================

REPORT_FILE="/tmp/validation_report_$(date +%Y%m%d_%H%M%S).txt"
JSON_REPORT="/tmp/validation_report_$(date +%Y%m%d_%H%M%S).json"
PASSED=0
FAILED=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "$1" | tee -a "$REPORT_FILE"; }
pass() { log "${GREEN}[PASS]${NC} $1"; ((PASSED++)); }
fail() { log "${RED}[FAIL]${NC} $1"; ((FAILED++)); }

# =============================================================
# HEADER
# =============================================================
log "============================================================="
log "   VALIDATION GLOBALE - Infrastructure Zero Trust"
log "   Date: $(date)"
log "============================================================="
log ""

# =============================================================
# T10.1 - Résistance aux scans (depuis WAN)
# =============================================================
log ">>> T10.1 - Résistance aux scans"

# Test: Scan des ports ouverts depuis WAN vers DMZ
OPEN_PORTS=$(timeout 30 nmap -sT -p 1-1024 10.0.1.2 2>/dev/null | grep "open" | wc -l)

if [ "$OPEN_PORTS" -le 2 ]; then
    pass "T10.1 - Exposition minimale: $OPEN_PORTS ports ouverts (attendu: ≤2)"
else
    fail "T10.1 - Trop de ports exposés: $OPEN_PORTS (attendu: ≤2)"
fi

# Test: Scan vers LAN (doit échouer)
LAN_SCAN=$(timeout 10 nmap -sT -p 22,80,443 10.0.2.2 2>/dev/null | grep "open" | wc -l)

if [ "$LAN_SCAN" -eq 0 ]; then
    pass "T10.1 - LAN inaccessible depuis WAN: 0 ports ouverts"
else
    fail "T10.1 - LAN exposé depuis WAN: $LAN_SCAN ports"
fi

# =============================================================
# T10.2 - Reproductibilité (vérification config)
# =============================================================
log ""
log ">>> T10.2 - Reproductibilité"

# Vérifier que les fichiers de config existent
CONFIGS=(
    "/home/zakariae-azn/secure-network-infrastructure/01_Firewall/rules.sh"
    "/home/zakariae-azn/secure-network-infrastructure/05_IDS_Suricata/suricata.yaml"
    "/home/zakariae-azn/secure-network-infrastructure/06_HA_Heartbeat/keepalived_master.conf"
)

CONFIG_OK=true
for cfg in "${CONFIGS[@]}"; do
    if [ -f "$cfg" ]; then
        log "  [OK] $cfg"
    else
        log "  [MISSING] $cfg"
        CONFIG_OK=false
    fi
done

if $CONFIG_OK; then
    pass "T10.2 - Tous les fichiers de configuration présents"
else
    fail "T10.2 - Fichiers de configuration manquants"
fi

# =============================================================
# T11.1 - Logs pare-feu
# =============================================================
log ""
log ">>> T11.1 - Logs pare-feu"

FW_LOGS=$(dmesg | grep -c "FW-DROP" 2>/dev/null || echo "0")

if [ "$FW_LOGS" -gt 0 ]; then
    pass "T11.1 - Logs pare-feu actifs: $FW_LOGS entrées FW-DROP"
    log "  Dernières entrées:"
    dmesg | grep "FW-DROP" | tail -3 | while read line; do log "    $line"; done
else
    fail "T11.1 - Aucun log pare-feu trouvé"
fi

# =============================================================
# T11.2 - Logs Suricata
# =============================================================
log ""
log ">>> T11.2 - Logs Suricata"

SURICATA_LOG="/var/log/suricata/fast.log"

if [ -f "$SURICATA_LOG" ]; then
    ALERT_COUNT=$(wc -l < "$SURICATA_LOG" 2>/dev/null || echo "0")
    if [ "$ALERT_COUNT" -gt 0 ]; then
        pass "T11.2 - Logs Suricata actifs: $ALERT_COUNT alertes"
        log "  Dernières alertes:"
        tail -3 "$SURICATA_LOG" | while read line; do log "    $line"; done
    else
        fail "T11.2 - Fichier Suricata vide"
    fi
else
    fail "T11.2 - Fichier $SURICATA_LOG non trouvé"
fi

# =============================================================
# Tests de connectivité (validation fonctionnelle)
# =============================================================
log ""
log ">>> Tests de connectivité"

# WAN -> DMZ HTTPS
if curl -k -s --connect-timeout 5 https://10.0.1.2 > /dev/null 2>&1; then
    pass "WAN -> DMZ HTTPS: accessible"
else
    fail "WAN -> DMZ HTTPS: inaccessible"
fi

# WAN -> LAN (doit échouer)
if ! ping -c 1 -W 2 10.0.2.2 > /dev/null 2>&1; then
    pass "WAN -> LAN: bloqué (Zero Trust)"
else
    fail "WAN -> LAN: accessible (violation Zero Trust)"
fi

# VIP Gateway
if ping -c 1 -W 2 10.0.0.1 > /dev/null 2>&1; then
    pass "VIP Gateway (10.0.0.1): accessible"
else
    fail "VIP Gateway (10.0.0.1): inaccessible"
fi

# =============================================================
# RAPPORT FINAL
# =============================================================
log ""
log "============================================================="
log "   RAPPORT FINAL"
log "============================================================="
log "Tests réussis:  $PASSED"
log "Tests échoués:  $FAILED"
log "Total:          $((PASSED + FAILED))"
log ""

if [ "$FAILED" -eq 0 ]; then
    log "${GREEN}>>> VALIDATION GLOBALE: SUCCÈS <<<${NC}"
    RESULT="SUCCESS"
else
    log "${RED}>>> VALIDATION GLOBALE: ÉCHEC ($FAILED erreurs) <<<${NC}"
    RESULT="FAILURE"
fi

log ""
log "Rapport texte: $REPORT_FILE"
log "Rapport JSON:  $JSON_REPORT"

# =============================================================
# T12.2 - Génération rapport JSON
# =============================================================
cat > "$JSON_REPORT" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "result": "$RESULT",
  "summary": {
    "passed": $PASSED,
    "failed": $FAILED,
    "total": $((PASSED + FAILED))
  },
  "tests": {
    "T10.1_scan_resistance": "$([ "$OPEN_PORTS" -le 2 ] && echo "PASS" || echo "FAIL")",
    "T10.2_reproducibility": "$([ "$CONFIG_OK" = true ] && echo "PASS" || echo "FAIL")",
    "T11.1_firewall_logs": "$([ "$FW_LOGS" -gt 0 ] && echo "PASS" || echo "FAIL")",
    "T11.2_suricata_logs": "$([ -f "$SURICATA_LOG" ] && [ "$ALERT_COUNT" -gt 0 ] && echo "PASS" || echo "FAIL")"
  }
}
EOF

log ""
log ">>> Rapport JSON généré:"
cat "$JSON_REPORT"
