#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info

# On définit une classe pour le routeur/pare-feu
class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        # Activer le routage IP
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def setup_network():
    # controller=None est parfait ici
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Création du Pare-feu central (Router)\n')
    # On l'appelle 'fw' pour coller au rapport, IP initiale sur l'interface par défaut
    fw = net.addHost('fw', cls=LinuxRouter, ip='10.0.0.1/24')
    
    info('*** Création des Hôtes par zone\n')
    # WAN (Internet simulé)
    h_wan = net.addHost('h_wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    # DMZ (Serveurs Web)
    h_dmz = net.addHost('h_dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    # LAN (Interne)
    h_lan = net.addHost('h_lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    # VPN (Accès distant) - AJOUTÉ SELON LE PROJET
    h_vpn = net.addHost('h_vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    # ADMIN (Gestion)
    h_adm = net.addHost('h_admin', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    info('*** Création des switches (Zones)\n')
    # failMode='standalone' est crucial ici
    s_wan = net.addSwitch('s1', cls=OVSSwitch, failMode='standalone')
    s_dmz = net.addSwitch('s2', cls=OVSSwitch, failMode='standalone')
    s_lan = net.addSwitch('s3', cls=OVSSwitch, failMode='standalone')
    s_vpn = net.addSwitch('s4', cls=OVSSwitch, failMode='standalone')
    s_adm = net.addSwitch('s5', cls=OVSSwitch, failMode='standalone')

    info('*** Création des liens physiques\n')
    # Connexion du FW aux 5 zones
    # Note: L'ordre de création détermine souvent les noms eth0, eth1, etc.
    net.addLink(fw, s_wan, intfName1='fw-eth0') # Vers WAN
    net.addLink(fw, s_dmz, intfName1='fw-eth1') # Vers DMZ
    net.addLink(fw, s_lan, intfName1='fw-eth2') # Vers LAN
    net.addLink(fw, s_vpn, intfName1='fw-eth3') # Vers VPN
    net.addLink(fw, s_adm, intfName1='fw-eth4') # Vers ADMIN

    # Connexion des hôtes aux switches
    net.addLink(h_wan, s_wan)
    net.addLink(h_dmz, s_dmz)
    net.addLink(h_lan, s_lan)
    net.addLink(h_vpn, s_vpn)
    net.addLink(h_adm, s_adm)

    info('*** Démarrage du réseau\n')
    net.build()
    net.start()

    info('*** Configuration des IPs sur le Pare-feu\n')
    # L'IP 10.0.0.1 est déjà sur fw-eth0 grâce au constructeur, on configure les autres
    fw.cmd('ip addr add 10.0.1.1/24 dev fw-eth1') # DMZ GW
    fw.cmd('ip addr add 10.0.2.1/24 dev fw-eth2') # LAN GW
    fw.cmd('ip addr add 10.0.3.1/24 dev fw-eth3') # VPN GW
    fw.cmd('ip addr add 10.0.4.1/24 dev fw-eth4') # ADMIN GW
    
    # Activation des interfaces
    for i in range(5):
        fw.cmd(f'ip link set fw-eth{i} up')

    #--- ACTIVATION ROUTAGE SERVEUR VPN ---
    h_vpn.cmd('sysctl -w net.ipv4.ip_forward=1')

    # Désactivation IPv6 (Optionnel mais propre)
    for host in net.hosts:
        host.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")

    info('*** TEST: Ping du LAN vers le FW ***\n')
    print(h_lan.cmd('ping -c 2 10.0.2.1'))

    info('*** Lancement de la console Mininet ***\n')
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()