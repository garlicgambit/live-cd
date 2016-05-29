#!/bin/sh

# Script for tails-gateway

#################
### Variables ###
#################

int_interface="$(ls /sys/class/net/ | grep -E vif[0-9]+[.][0-9]+)"
ext_interface=eth0
int_interface_ip=192.168.199.1
ext_interface_ip=10.137.2.11
default_gateway=10.137.2.1
tails_workstation_ip=192.168.199.2
tor_torrc=/etc/tor/torrc
sysctl_file=/etc/sysctl.d/sysctl-hardening.conf
controlport_proxy=/usr/local/lib/tor-controlport-filter

#####################
### System checks ###
#####################

# Only run as root
if [ $(id -u) != "0" ]; then
  echo "ERROR: Must be run as root...exiting script"
  exit 0
fi

# Check if Tails-workstation/Tails-gateway connection is available
if [ -z "${int_interface}" ]; then
  echo "Error: Tails-workstation/Tails-gateway vif interface is not available."
  exit 0
fi

########################
### System hardening ###
########################

# Disable cups
service cups stop

# Disable ipv6
echo "# Disable ipv6" >> "${sysctl_file}"
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> "${sysctl_file}"
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> "${sysctl_file}"
echo "net.ipv6.conf.${ext_interface}.disable_ipv6 = 1" >> "${sysctl_file}"

################
### Firewall ###
################

# Permit TCP traffic from Tails-workstation
sed -i "/interface lo ACCEPT;/a \ \n            # CUSTOM RULE - Allow TCP traffic from Tails-workstation\n            interface vif+ saddr ${tails_workstation_ip} daddr ${int_interface_ip} proto tcp mod state state NEW syn mod multiport destination-ports (9050 9051 9052 9061 9062 9150) ACCEPT;" /etc/ferm/ferm.conf

# Permit UDP/DNS traffic from Tails-workstation
sed -i "/interface lo ACCEPT;/a \ \n            # CUSTOM RULE - Allow UDP/DNS traffic from Tails-workstation\n            interface vif+ saddr ${tails_workstation_ip} daddr ${int_interface_ip} proto udp mod state state NEW dport 53 ACCEPT;" /etc/ferm/ferm.conf

# Reload iptables/ferm rules
service ferm restart

###############
### Network ###
###############

# Connection to tails-workstation
nmcli con add con-name "${int_interface}" ifname "${int_interface}" type ethernet ip4 "${int_interface_ip}"/30
nmcli con mod "${int_interface}" ipv6.method ignore
nmcli con up "${int_interface}"

# Connection to Qubes sys-firewall
nmcli con add con-name "${ext_interface}" ifname "${ext_interface}" type ethernet ip4 "${ext_interface_ip}"/24 gw4 "${default_gateway}"
nmcli con mod "${ext_interface}" ipv6.method ignore
nmcli con up "${ext_interface}"

# Apply sysctl changes - applied here to disable ipv6
sysctl -p "${sysctl_file}"

###########
### Tor ###
###########

# Listen on internal IP address
sed -i "s/127.0.0.1/${int_interface_ip}/" "${tor_torrc}"

# Listen for DNS on internal IP address
# Set to port 53 to allow drop in replacements for Tails-gateway
sed -i "s/DNSPort 5353/DNSPort ${int_interface_ip}:53/" "${tor_torrc}"
service tor restart

# Tor ControlPort filter proxy
sed -i "s/127.0.0.1/${int_interface_ip}/" "${controlport_proxy}"
service tor-controlport-filter restart
