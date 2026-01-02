#!/bin/bash

# Création du dossier pour stocker les clés
mkdir -p certs

echo "[*] Génération de la clé privée du serveur..."
openssl genrsa -out certs/server.key 2048

echo "[*] Génération du certificat auto-signé (Valide 365 jours)..."
# On remplit les infos automatiquement (-subj) pour éviter les questions interactives
openssl req -new -x509 -key certs/server.key -out certs/server.crt -days 365 \
    -nodes -subj "/C=FR/ST=Tunis/L=Tunis/O=LSI3_Project/CN=www.dmz.lab"

echo "[*] Permissions restrictives sur la clé privée..."
chmod 600 certs/server.key

echo "[OK] Certificats générés dans le dossier ./certs/"