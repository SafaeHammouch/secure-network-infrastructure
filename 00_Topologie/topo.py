#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.link import TCLink
from mininet.cli import CLI
from mininet.log import setLogLevel, info
import time

class LinuxRouter(Node):
    """Un noeud qui agit comme un routeur Linux (IP Forwarding activé)"""
    def config(self, **params):
        super().config(**params)
        # Activation du forwarding IPv4
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super().terminate()

def create_topology():
    # On retire le controleur pour laisser les switchs en mode standalone
    net = Mininet(controller=None, link=TCLink, switch=OVSSwitch)

    info("[*] Ajout des commutateurs (Zones)\n")
    s_wan   = net.addSwitch('s1')
    s_dmz   = net.addSwitch('s2')
    s_lan   = net.addSwitch('s3')
    s_vpn   = net.addSwitch('s4')
    s_admin = net.addSwitch('s5')

    info("[*] Ajout du Pare-feu central (Router)\n")
    # On ne donne pas d'IP globale ici, on configurera les interfaces apres
    fw = net.addHost('fw', cls=LinuxRouter, ip=None)

    info("[*] Ajout des Hotes\n")
    wan = net.addHost('wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    dmz = net.addHost('dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    lan = net.addHost('lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    vpn = net.addHost('vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    adm = net.addHost('admin', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    info("[*] Creation des liens et adressage des interfaces du FW\n")
    
    # Zone WAN (10.0.0.0/24)
    net.addLink(wan, s_wan)
    net.addLink(fw, s_wan, intfName2='fw-wan', params2={'ip': '10.0.0.1/24'})

    # Zone DMZ (10.0.1.0/24)
    net.addLink(dmz, s_dmz)
    net.addLink(fw, s_dmz, intfName2='fw-dmz', params2={'ip': '10.0.1.1/24'})

    # Zone LAN (10.0.2.0/24)
    net.addLink(lan, s_lan)
    net.addLink(fw, s_lan, intfName2='fw-lan', params2={'ip': '10.0.2.1/24'})

    # Zone VPN (10.0.3.0/24)
    net.addLink(vpn, s_vpn)
    net.addLink(fw, s_vpn, intfName2='fw-vpn', params2={'ip': '10.0.3.1/24'})

    # Zone ADMIN (10.0.4.0/24)
    net.addLink(adm, s_admin)
    net.addLink(fw, s_admin, intfName2='fw-admin', params2={'ip': '10.0.4.1/24'})

    info("[*] Demarrage du reseau\n")
    net.start()
    
    # Configuration manuelle de sécurité pour forcer les IPs (parfois capricieux avec params2)
    fw.cmd('ifconfig fw-wan 10.0.0.1 netmask 255.255.255.0 up')
    fw.cmd('ifconfig fw-dmz 10.0.1.1 netmask 255.255.255.0 up')
    fw.cmd('ifconfig fw-lan 10.0.2.1 netmask 255.255.255.0 up')
    fw.cmd('ifconfig fw-vpn 10.0.3.1 netmask 255.255.255.0 up')
    fw.cmd('ifconfig fw-admin 10.0.4.1 netmask 255.255.255.0 up')

    # Désactiver IPv6 pour éviter le bruit dans Wireshark/Logs
    info("[*] Desactivation IPv6\n")
    for host in net.hosts:
        host.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        host.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")
        host.cmd("sysctl -w net.ipv6.conf.lo.disable_ipv6=1")

    info("[*] Topologie prete. Test de connectivite initial...\n")
    # Un petit test pour verifier que le WAN voit sa passerelle
    print("Test ping WAN -> Firewall (Gateway): ", end="")
    print(wan.cmd('ping -c 1 10.0.0.1 | grep "1 received"'))

    CLI(net)

    info("[*] Arret du reseau\n")
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    create_topology()