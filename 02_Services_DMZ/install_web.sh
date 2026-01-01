#!/bin/bash

echo "[*] Initialisation du Service Web DMZ..."

# 1. Générer les certificats s'ils n'existent pas
if [ ! -f "certs/server.crt" ]; then
    ./generate_ssl.sh
fi

# 2. Lancer le serveur Python en arrière-plan
# nohup permet au serveur de continuer à tourner même si on ferme le terminal
echo "[*] Lancement du serveur Web Sécurisé..."
python3 secure_server.py &

echo "[OK] Serveur Web actif (PID $!)"