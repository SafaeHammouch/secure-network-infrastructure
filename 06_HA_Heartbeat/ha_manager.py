#!/usr/bin/python3
import time
import sys
import os
import subprocess

# Configuration
VIRTUAL_IP = "10.0.1.100/24"
INTERFACE = "h_dmz-eth0" # A adapter selon la machine
CHECK_INTERVAL = 2
ROLE = sys.argv[1] if len(sys.argv) > 1 else "backup" # 'master' ou 'backup'

def add_vip():
    print(f"[*] Prise de controle de l'IP virtuelle {VIRTUAL_IP}")
    os.system(f"ip addr add {VIRTUAL_IP} dev {INTERFACE}")

def remove_vip():
    print(f"[*] Libération de l'IP virtuelle {VIRTUAL_IP}")
    os.system(f"ip addr del {VIRTUAL_IP} dev {INTERFACE}")

def am_i_master():
    # Vérifie si l'IP virtuelle est déjà sur cette machine
    res = subprocess.getoutput(f"ip addr show {INTERFACE}")
    return VIRTUAL_IP.split('/')[0] in res

print(f"--- Démarrage HA Heartbeat (Mode: {ROLE}) ---")

if ROLE == "master":
    add_vip()
    try:
        while True:
            print("[MASTER] Je suis vivant... (CTRL+C pour simuler panne)")
            time.sleep(CHECK_INTERVAL)
    except KeyboardInterrupt:
        print("\n[!] Panne simulée ! Arrêt du service.")
        remove_vip()

elif ROLE == "backup":
    print("[BACKUP] En attente...")
    # Simulation simplifiée: on attend que le maître disparaisse
    # Dans un vrai cas, on écouterait des paquets UDP "Heartbeat"
    # Ici, pour la démo, on suppose qu'on prend le relais manuellement
    # ou on ping l'IP du master.
    
    TARGET_MASTER_IP = "10.0.1.2" # IP réelle du master
    while True:
        response = os.system(f"ping -c 1 -W 1 {TARGET_MASTER_IP} > /dev/null")
        if response != 0:
            print("[BACKUP] ALERTE: Le Master ne répond plus ! Basculement...")
            if not am_i_master():
                add_vip()
            else:
                print("[BACKUP] Je suis déjà le maître actif.")
        else:
            print("[BACKUP] Master en ligne.")
            if am_i_master():
                remove_vip()
        time.sleep(CHECK_INTERVAL)
