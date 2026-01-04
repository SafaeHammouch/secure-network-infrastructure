#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info

# Classe pour les routeurs (Pare-feux)
class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        # Activer le routage IP (Forwarding)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def setup_network():
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Création du Cluster de Pare-feu (Haute Disponibilité)\n')
    # Les hôtes utilisent 10.0.x.1 comme passerelle.
    # fw1 possède les IPs réelles .11 et fw2 possède .12
    fw1 = net.addHost('fw1', cls=LinuxRouter, ip='10.0.0.11/24')
    fw2 = net.addHost('fw2', cls=LinuxRouter, ip='10.0.0.12/24')
    
    info('*** Création des Hôtes par zone\n')
    # Tous les hôtes pointent vers l'IP virtuelle .1 (Gateway)
    h_wan = net.addHost('h_wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    h_dmz = net.addHost('h_dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    h_lan = net.addHost('h_lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    h_vpn = net.addHost('h_vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    h_adm = net.addHost('h_admin', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    info('*** Création des switches de zones\n')
    s_wan = net.addSwitch('s1', cls=OVSSwitch, failMode='standalone')
    s_dmz = net.addSwitch('s2', cls=OVSSwitch, failMode='standalone')
    s_lan = net.addSwitch('s3', cls=OVSSwitch, failMode='standalone')
    s_vpn = net.addSwitch('s4', cls=OVSSwitch, failMode='standalone')
    s_adm = net.addSwitch('s5', cls=OVSSwitch, failMode='standalone')

    info('*** Connexion redondante (HA) des Pare-feux aux zones\n')
    # On connecte CHAQUE pare-feu à CHAQUE switch
    zones = [s_wan, s_dmz, s_lan, s_vpn, s_adm]
    for i, sw in enumerate(zones):
        net.addLink(fw1, sw, intfName1=f'fw1-eth{i}')
        net.addLink(fw2, sw, intfName1=f'fw2-eth{i}')

    info('*** Connexion des hôtes aux switches\n')
    net.addLink(h_wan, s_wan)
    net.addLink(h_dmz, s_dmz)
    net.addLink(h_lan, s_lan)
    net.addLink(h_vpn, s_vpn)
    net.addLink(h_adm, s_adm)

    info('*** Démarrage du réseau\n')
    net.build()
    net.start()

    info('*** Configuration des IPs sur le Cluster FW\n')
    for i in range(5):
        # Configuration FW1 (Actif par défaut - possède les IPs .1 et .11)
        fw1.cmd(f'ip addr add 10.0.{i}.1/24 dev fw1-eth{i}') # IP Virtuelle (VIP)
        fw1.cmd(f'ip addr add 10.0.{i}.11/24 dev fw1-eth{i}') # IP Réelle
        fw1.cmd(f'ip link set fw1-eth{i} up')

        # Configuration FW2 (Passif par défaut - possède uniquement .12)
        fw2.cmd(f'ip addr add 10.0.{i}.12/24 dev fw2-eth{i}') # IP Réelle
        fw2.cmd(f'ip link set fw2-eth{i} up')

    info('*** Configuration du Routage spécifique (VPN & Inter-zones)\n')
    # Le serveur VPN doit pouvoir router le trafic
    h_vpn.cmd('sysctl -w net.ipv4.ip_forward=1')

    # Les deux pare-feux doivent savoir que le réseau VPN est derrière h_vpn (10.0.3.2)
    fw1.cmd('ip route add 10.8.0.0/24 via 10.0.3.2')
    fw2.cmd('ip route add 10.8.0.0/24 via 10.0.3.2')

    # Désactivation IPv6
    for host in net.hosts:
        host.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")

    info('\n*** SYNTHÈSE DES PASSERELLES (VIP) ***\n')
    info('Gateway Virtuelle: 10.0.x.1\n')
    info('Pare-feu Primaire (fw1): 10.0.x.11 (Actif)\n')
    info('Pare-feu Secondaire (fw2): 10.0.x.12 (Backup)\n')

    info('\n*** TEST INITIAL: Ping Gateway depuis LAN ***\n')
    print(h_lan.cmd('ping -c 2 10.0.2.1'))

    info('*** Lancement de la console Mininet ***\n')
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()