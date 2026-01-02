import http.server
import ssl
import socketserver
import threading
import os

# Configuration
HTTP_PORT = 80
HTTPS_PORT = 443
CERT_FILE = 'certs/server.crt'
KEY_FILE = 'certs/server.key'

# Handler pour la redirection HTTP -> HTTPS
class RedirectHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(301)
        new_location = f"https://{self.headers.get('Host', '10.0.1.2')}{self.path}"
        self.send_header('Location', new_location)
        self.end_headers()
        print(f"[HTTP] 301 → {new_location}")
    
    def do_HEAD(self):
        self.do_GET()

# Fonction pour lancer le serveur HTTP (Redirection)
def run_http():
    print(f"[*] Démarrage serveur HTTP sur le port {HTTP_PORT} (Redirection seule)")
    httpd = socketserver.TCPServer(("", HTTP_PORT), RedirectHandler)
    httpd.serve_forever()

# Fonction pour lancer le serveur HTTPS (Contenu sécurisé)
def run_https():
    print(f"[*] Démarrage serveur HTTPS sur le port {HTTPS_PORT}")
    
    # Création du contexte SSL
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    
    server_address = ('', HTTPS_PORT)
    # SimpleHTTPRequestHandler sert les fichiers du dossier courant (index.html)
    httpd = http.server.HTTPServer(server_address, http.server.SimpleHTTPRequestHandler)
    
    # On enveloppe le socket avec SSL
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    httpd.serve_forever()

if __name__ == '__main__':
    # Vérification des fichiers
    if not os.path.exists(CERT_FILE) or not os.path.exists(KEY_FILE):
        print("ERREUR: Certificats manquants. Lancez d'abord generate_ssl.sh")
        exit(1)

    # Création d'un fichier index.html de test si absent
    if not os.path.exists("index.html"):
        with open("index.html", "w") as f:
            f.write("<h1>Bienvenue dans la DMZ Securisee (HTTPS)</h1><p>Projet LSI3 Zero Trust</p>")

    # Lancement des threads
    t1 = threading.Thread(target=run_http)
    t2 = threading.Thread(target=run_https)
    
    t1.start()
    t2.start()