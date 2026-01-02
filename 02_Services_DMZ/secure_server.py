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

# Handler pour la redirection STRICTE HTTP -> HTTPS
class RedirectHandler(http.server.BaseHTTPRequestHandler):
    def do_redirect(self):
        self.send_response(301)
        # On récupère l'hôte sans le port si présent
        host = self.headers.get('Host', '10.0.1.2').split(':')[0]
        new_location = f"https://{host}{self.path}"
        self.send_header('Location', new_location)
        self.end_headers()
        print(f"[HTTP] Redirection de {self.path} vers {new_location}")

    def do_GET(self):
        self.do_redirect()

    def do_HEAD(self):
        self.do_redirect()

# Fonction pour lancer le serveur HTTP (Redirection seule)
def run_http():
    print(f"[*] Démarrage serveur HTTP sur le port {HTTP_PORT} (Redirection forcée)")
    # On utilise allow_reuse_address pour éviter les erreurs "Address already in use"
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("", HTTP_PORT), RedirectHandler)
    httpd.serve_forever()

# Fonction pour lancer le serveur HTTPS (Contenu sécurisé)
def run_https():
    print(f"[*] Démarrage serveur HTTPS sur le port {HTTPS_PORT}")
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    
    server_address = ('', HTTPS_PORT)
    # Ici on garde SimpleHTTPRequestHandler car on VEUT servir index.html
    httpd = http.server.HTTPServer(server_address, http.server.SimpleHTTPRequestHandler)
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    httpd.serve_forever()

if __name__ == '__main__':
    if not os.path.exists(CERT_FILE) or not os.path.exists(KEY_FILE):
        print("ERREUR: Certificats manquants.")
        exit(1)

    if not os.path.exists("index.html"):
        with open("index.html", "w") as f:
            f.write("<h1>Bienvenue dans la DMZ Securisee (HTTPS)</h1><p>Projet LSI3 Zero Trust</p>")

    threading.Thread(target=run_http, daemon=True).start()
    run_https() # On lance le HTTPS dans le thread principal