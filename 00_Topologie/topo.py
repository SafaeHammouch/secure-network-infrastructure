#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info

# On définit une classe pour le routeur
class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        # Activer le routage IP
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def setup_network():
    # On met controller=None pour éviter l'erreur que vous avez eue
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Création des nœuds (Routeur et Hôtes)\n')
    # Routeur R1
    r1 = net.addHost('r1', cls=LinuxRouter, ip='10.0.1.1/24')
    
    # Hôtes
    h_wan = net.addHost('h_wan', ip='10.0.1.10/24', defaultRoute='via 10.0.1.1')
    h_web = net.addHost('h_web', ip='10.0.2.10/24', defaultRoute='via 10.0.2.1')
    h_lan = net.addHost('h_lan', ip='10.0.3.10/24', defaultRoute='via 10.0.3.1')
    h_admin = net.addHost('h_admin', ip='10.0.4.10/24', defaultRoute='via 10.0.4.1')

    info('*** Création des switches en mode standalone\n')
    # failMode='standalone' permet au switch de fonctionner comme un switch normal sans contrôleur
    s1 = net.addSwitch('s1', cls=OVSSwitch, failMode='standalone')
    s2 = net.addSwitch('s2', cls=OVSSwitch, failMode='standalone')
    s3 = net.addSwitch('s3', cls=OVSSwitch, failMode='standalone')
    s4 = net.addSwitch('s4', cls=OVSSwitch, failMode='standalone')

    info('*** Création des liens\n')
    # R1 connecté aux 4 switches
    net.addLink(r1, s1, intfName1='r1-eth0') # WAN
    net.addLink(r1, s2, intfName1='r1-eth1') # DMZ
    net.addLink(r1, s3, intfName1='r1-eth2') # LAN
    net.addLink(r1, s4, intfName1='r1-eth3') # ADMIN

    # Hôtes connectés à leurs zones respectives
    net.addLink(h_wan, s1)
    net.addLink(h_web, s2)
    net.addLink(h_lan, s3)
    net.addLink(h_admin, s4)

    info('*** Démarrage du réseau\n')
    net.build()
    net.start()

    info('*** Configuration des IPs additionnelles sur R1\n')
    r1.cmd('ip addr add 10.0.2.1/24 dev r1-eth1')
    r1.cmd('ip addr add 10.0.3.1/24 dev r1-eth2')
    r1.cmd('ip addr add 10.0.4.1/24 dev r1-eth3')
    
    # On s'assure que toutes les interfaces sont activées
    for i in range(4):
        r1.cmd(f'ip link set r1-eth{i} up')

    info('*** TEST DE CONNECTIVITÉ INITIALE ***\n')
    # Test ping h_lan vers sa passerelle r1
    print("Test Ping LAN -> R1 (Passerelle):")
    print(net.get('h_lan').cmd('ping -c 2 10.0.3.1'))

    info('*** Lancement de la console Mininet\n')
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()   