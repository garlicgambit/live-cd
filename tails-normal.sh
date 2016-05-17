#!/bin/sh

# Script for normal tails setup

#################
### Variables ###
#################

ext_interface=eth0
ext_interface_ip=10.137.2.11
default_gateway=10.137.2.1
tails_useraccount=amnesia
user_js=/home/amnesia/.tor-browser/profile.default/user.js
tor_torrc=/etc/tor/torrc
sysctl_file=/etc/sysctl.d/sysctl-hardening.conf

#####################
### System checks ###
#####################

# Only run as root
if [ $(id -u) != "0" ]; then
  echo "ERROR: Must be run as root...exiting script"
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

###################
### Tor Browser ###
###################

# Set Tor-Browser security slider to high. Note: not recommended by Tor-Browser developers
echo 'user_pref("extensions.torbutton.security_slider", 1);' >> "${user_js}"

# Set correct permissions and owner for user.js file
chmod 600 "${user_js}"
chown "${tails_useraccount}" "${user_js}"

###############
### Network ###
###############

# Connection to Qubes sys-firewall
nmcli con add con-name "${ext_interface}" ifname "${ext_interface}" type ethernet ip4 "${ext_interface_ip}"/24 gw4 "${default_gateway}"
nmcli con mod "${ext_interface}" ipv6.method ignore
nmcli con up "${ext_interface}"

# Apply sysctl changes - applied here to disable ipv6
sysctl -p "${sysctl_file}"
