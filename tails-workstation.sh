#!/bin/sh

# Script for tails-workstation

#################
### Variables ###
#################

ext_interface=eth0
ext_interface_ip=192.168.199.2
tails_gateway_ip=192.168.199.1
tails_useraccount=amnesia
user_js=/home/amnesia/.tor-browser/profile.default/user.js
tor_torrc=/etc/tor/torrc
torbirdy_dir=/usr/share/xul-ext/torbirdy
sysctl_file=/etc/sysctl.d/sysctl-hardening.conf

#####################
### System checks ###
#####################

# Only run as root
if [ $(id -u) != "0" ]; then
  echo "ERROR: Must be run as root...exiting script"
  exit 0
fi

# Check if Tails-workstation/Tails-gateway connection is available
if [ -z "${ext_interface}" ]; then
  echo "Error: Tails-workstation/Tails-gateway interface is not available."
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

# Configure proxy settings
echo "user_pref(\"extensions.torbutton.custom.socks_host\", \"${tails_gateway_ip}\");" >> "${user_js}"
#echo "user_pref(\"extensions.torbutton.socks_host\", \"${tails_gateway_ip}\");" >> "${user_js}"
#echo "user_pref(\"network.proxy.socks\", \"${tails_gateway_ip}\");" >> "${user_js}"

# Configure proxy in environment variables in tor-browser script
sed -i "s/TOR_SOCKS_HOST='127.0.0.1'/TOR_SOCKS_HOST='${tails_gateway_ip}'/" /usr/local/bin/tor-browser

# Set correct permissions and owner for user.js file
chmod 600 "${user_js}"
chown "${tails_useraccount}" "${user_js}"

##########################
### Torsocks utilities ###
##########################

# Configure torsocks.conf
sed -i "s/TorAddress 127.0.0.1/TorAddress ${tails_gateway_ip}/" /etc/tor/torsocks.conf

# Configure tor-tsocks.conf
sed -i "s/server = 127.0.0.1/server = ${tails_gateway_ip}/" /etc/tor/tor-tsocks.conf

# Configure tor-tsocks-git.conf
sed -i "s/server = 127.0.0.1/server = ${tails_gateway_ip}/" /etc/tor/tor-tsocks-git.conf

############################
### General applications ###
############################

# Configure Bash environment variables
echo >> /home/"${tails_useraccount}"/.bashrc
echo "export SOCKS_SERVER=${tails_gateway_ip}" >> /home/"${tails_useraccount}"/.bashrc
echo "export SOCKS5_SERVER=${tails_gateway_ip}" >> /home/"${tails_useraccount}"/.bashrc

# Configure Electrum bitcoin client
sed -i "s/socks5:localhost/socks5:${tails_gateway_ip}/" /home/"${tails_useraccount}"/.electrum/config

# Configure Gnupg PGP client
sed -i "s#socks5-hostname://127.0.0.1#socks5-hostname://${tails_gateway_ip}#" /home/"${tails_useraccount}"/.gnupg/gpg.conf

# Configure Icedove/Torbirdy mail client - works, but needs more love to make it safer/specific
sed -i "s/127.0.0.1/${tails_gateway_ip}/" "${torbirdy_dir}"/chrome/content/preferences.js
sed -i "s/127.0.0.1/${tails_gateway_ip}/" "${torbirdy_dir}"/components/torbirdy.js
sed -i "s/\"mail.smtpserver.default.hello_argument\": \"${tails_gateway_ip}\"/\"mail.smtpserver.default.hello_argument\": \"127.0.0.1\"/" "${torbirdy_dir}"/components/torbirdy.js

# Configure Pidgin chat client - works, but needs more love to make it safer/specific
sed -i "s/127.0.0.1/${tails_gateway_ip}/" /home/"${tails_useraccount}"/.purple/prefs.xml

################
### Firewall ###
################

# Disable tor process user from accessing the web
sed -i "s/debian-tor ACCEPT;/debian-tor REJECT;/" /etc/ferm/ferm.conf

# Allow DNS to Tails-gateway
sed -i "s/ daddr 127.0.0.1 proto udp dport 53 REDIRECT to-ports 5353;/#daddr 127.0.0.1 proto udp dport 53 REDIRECT to-ports 5353;/" /etc/ferm/ferm.conf

# Allow DNS to Tails-gateway from tails useraccount
#sed -i "s/ proto udp dport domain REJECT;/#proto udp dport domain REJECT;/" /etc/ferm/ferm.conf
#sed -i "s/proto udp dport domain REJECT;/proto udp dport domain mod owner uid-owner ${tails_useraccount} ACCEPT;/" /etc/ferm/ferm.conf
sed -i "/ @subchain \"lan\" {/a \                # CUSTOM RULE - Allow outbound UDP/DNS traffic for Tails useraccount\n                proto udp mod state state NEW dport 53 mod owner uid-owner ${tails_useraccount} ACCEPT;" /etc/ferm/ferm.conf

# Reload iptables/ferm rules
service ferm restart

###############
### Network ###
###############

# Connection to Tails-gateway
nmcli con add con-name "${ext_interface}" ifname "${ext_interface}" type ethernet ip4 "${ext_interface_ip}"/30
nmcli con mod "${ext_interface}" ipv4.dns "${tails_gateway_ip}"
nmcli con mod "${ext_interface}" ipv6.method ignore
nmcli con up "${ext_interface}"

# Set DNS server to Tails-gateway
sed -i "s/nameserver 127.0.0.1/nameserver ${tails_gateway_ip}/" /etc/resolv.conf

# Apply sysctl changes - applied here to disable ipv6
sysctl -p "${sysctl_file}"

###########
### Tor ###
###########

# Disable Tor
echo > "${tor_torrc}"
echo "DisableNetwork 1" >> "${tor_torrc}"
echo "SocksPort 0" >> "${tor_torrc}"
service tor stop
