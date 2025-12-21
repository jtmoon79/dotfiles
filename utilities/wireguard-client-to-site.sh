#!/usr/bin/env bash
#
# https://gist.github.com/jtmoon79/217e55272c55631ba6025c9f890b3dde
#
# Script to generate a client-to-site Wireguard IPv4 VPN tunnel
# configuration files, and commands for systemd services.
# This script only covers a narrow scope of possible networking arrangements.
# It may not perfectly fit the user's needs, but it may provide the user with
# a working example that they can modify for their needs.
#
# Site is the Wireguard server. Presumed to use systemd services.
# Client is the Wireguard client.
#
# This Wireguard configuration allows:
# - site host access the client
# - site host network hosts access to the client *if* the site host is a
#   known router for the VPN IP network
# - client to access site host network
#
# Pieced together from:
# https://gist.github.com/insdavm/b1034635ab23b8839bf957aa406b5e39
# https://wiki.archlinux.org/title/WireGuard#Additional_routes
# https://www.cyberciti.biz/faq/how-to-set-up-wireguard-firewall-rules-in-linux/
# https://www.ivpn.net/knowledgebase/linux/linux-autostart-wireguard-in-systemd/
#
# BUG: power loss or other unexpected events may result in duplicate iptables
#      rules on the site Wireguard server.
#      the duplicate rules must be manually deleted.
#      Also, duplicate iptables rules will occur if the user manually adjusts
#      wireguard interfaces using "wg" or "wg-quick" then later uses systemd
#      service calls.
#
# XXX: User can unset DNS entry as desired. It is commented by default.
#
# Also see `wireguard-site-to-site.sh`
# https://gist.github.com/jtmoon79/c951f81f621bb87ddb60836245aca4ff
#

set -euo pipefail

SCRIPT=$(basename -- "${0}")

function usage_exit() {
    echo "\
Generate Wireguard IPv4 VPN client-to-site configuration files and commands.

This script does not modify files. The user must selectively copy+paste+run the
highlighted output.

Usage:

    ${SCRIPT} OFFSET FQDN_SITE CLIENT_NAME SITE_NET SITE_DNS

For example:

    ${SCRIPT} 55 my-wireguard-server.domain.org MySmartPhone 192.168.1.0/24 192.168.1.1

OFFSET is an arbitrary numeric offset to disambiguate potentially multiple
Wireguard interfaces and VLAN networks. Value must be [1, 255].

The firewall at FQDN_SITE probably needs to allow incoming UDP traffic. The
port will shown in the output, or can be overridden via SITE_PORT, e.g.

    SITE_PORT=12345 ${SCRIPT} …

SITE_DNS is added but commented.

Review the script for other optional environment variable settings.

To allow other hosts on the site network to connect to the client through
the VPN tunnel, the user must push additional routes to the other network hosts.
That is beyond the scope of this script.
" >&2
    exit 1
}

if [[ ${#} -ne 5 ]]; then
    usage_exit
fi

# check for non-default Linux commands
for prog in wg wg-quick; do
    if ! which "${prog}" &>/dev/null; then
        echo "command \"${prog}\" not found, is 'wireguard-tools' installed?" >&2
        exit 1
    fi
done
for prog in iptables qrencode; do
    if ! which "${prog}" &>/dev/null; then
        echo "command \"${prog}\" not found" >&2
        exit 1
    fi
done

function hl() {
    # print a horizontal line
    echo -n '# '
    declare i=
    for i in $(seq 1 $((${COLUMNS} - 2))); do echo -n '-'; done
    echo
}

function b() {
    # enable bold + green output
    echo -ne '\033[1m\e[32m'
}

function n() {
    # enable normal + default output
    echo -ne '\033[0m\e[39m'
}

#
# site variables
#

declare -i OFFSET=${1}
if [[ ${OFFSET} -eq 0 ]] || [[ ${OFFSET} -gt 255 ]]; then
    echo "Offset must be more than 0 and less than 255" >&2
    exit 1
fi

TEMPD=$(umask 0077; mktemp -d -t "${SCRIPT}.XXX")

# first 3 IPv4 network octets of the virtual LAN, make it unique and obvious
SITE12_VLAN_FIRST3=${SITE12_VLAN_FIRST3-"10.0.${OFFSET}"}
WG_DEV=wg${OFFSET}
# e.g. "my-host.domainhost.org"
SITE_FQDN=${2}
# from "my-host.domain.org" extract "my-host"
SITE_NAME=${SITE_FQDN%%.*}
# site LAN network device
SITE_LAN_DEV=${SITE_LAN_DEV-eth0}
# site Wireguard network device
SITE_WG_DEV=wg${OFFSET}
# site wireguard configuration
SITE_WG_CONF_NAME=${SITE_WG_DEV}.conf
SITE_WG_CONF=/etc/wireguard/${SITE_WG_CONF_NAME}
# unique VLAN address
SITE_ADDR=${SITE12_VLAN_FIRST3}.1
SITE_ADDR_CIDR=${SITE_ADDR}/24
SITE_PORT=${SITE_PORT-$((51000 + ${OFFSET}))}
# Internet-accessible Endpoint
SITE_ENDPOINT=${SITE_FQDN}:${SITE_PORT}
# CIDR network of site 1, must match actual network!
SITE_NET=${4}
SITE_MTU=${SITE_MTU-1340}
# DNS Server at site 1, must match actual DNS server!
SITE_DNS=${5}

# site and client virtual network
SITE12_VNET=${SITE12_VLAN_FIRST3}.0/24

CLIENT_NAME=${3}
#CLIENT_ETH_DEV=${CLIENT_ETH_DEV-eth0}
# presume Debian location of wireguard configuration
CLIENT_WG_CONF=/etc/wireguard/${WG_DEV}.conf
CLIENT_WG_CONF_TEMP=${TEMPD}/${WG_DEV}.conf
# unique VLAN address
CLIENT_ADDR=${SITE12_VLAN_FIRST3}.2
CLIENT_ADDR_CIDR=${CLIENT_ADDR}/24
CLIENT_WG_PORT=${CLIENT_WG_PORT-$((51000 + ${OFFSET}))}
CLIENT_MTU=${CLIENT_MTU-1340}

SITE_KEY=${TEMPD}/site-${SITE_NAME}.key
SITE_PUB=${TEMPD}/site-${SITE_NAME}.pub
CLIENT_KEY=${TEMPD}/client-${CLIENT_NAME}.key
CLIENT_PUB=${TEMPD}/client-${CLIENT_NAME}.pub
SITE_CLIENT_PSK=${TEMPD}/psk-${SITE_NAME}-${CLIENT_NAME}.psk

# remind user how to check iptables rules and fix bad/duplicate rules.
COMMENT_LIST_RULES="\
# This WireGuard configuration should create 5 iptables rules.
# To list the rules by line number:
#    iptables --list --line-numbers
#    iptables --list --table nat --line-numbers
# In case of duplicate or bad rules, delete each rule individually. For example:
#    iptables --delete FORWARD 10
#    iptables --delete --table nat POSTROUTING 10
# Rules added by this configuration are denoted by the comment."

function exit_ () {
    rm -rf -- "${TEMPD}"
}
trap exit_ EXIT

# generate various keys
(
    umask 0077
    wg genkey | tee ${SITE_KEY} | wg pubkey > ${SITE_PUB}
    wg genkey | tee ${CLIENT_KEY} | wg pubkey > ${CLIENT_PUB}
    wg genpsk > "${SITE_CLIENT_PSK}"
)

# enable forwarding, enable debug logging if available
SITE12_PREUP="set -x; sysctl -w net.ipv4.ip_forward=1; ([[ -e /sys/kernel/debug/dynamic_debug/control ]] && (modprobe wireguard && echo module wireguard +p > /sys/kernel/debug/dynamic_debug/control)) || true; ip -4 -N route list;"

# create iptables rules to forward and masquerade between the different networks
# comments added to clarify the rule source and help debugging/fixing rules
#
# the `ip route` comamnds are informational only

# on up: delete prior rules (if any) then create iptables
SITE_CONF_POSTUP="set -x;\
 ip -4 -N route list;\
 iptables -v -t nat -D POSTROUTING -o ${SITE_LAN_DEV} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE_WG_DEV}' || true;\
 iptables -v -D INPUT -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE_WG_DEV}' || true;\
 iptables -v -D FORWARD -i ${SITE_LAN_DEV} -o ${SITE_WG_DEV} -j ACCEPT -m comment --comment 'wireguard-c-${SITE_WG_DEV}' || true;\
 iptables -v -D FORWARD -i %i -o ${SITE_LAN_DEV} -j ACCEPT -m comment --comment 'wireguard-d-${SITE_WG_DEV}' || true;\
 iptables -v -D INPUT -i ${SITE_LAN_DEV} -p udp --dport ${SITE_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE_WG_DEV}' || true;\
 iptables -v -t nat -I POSTROUTING 1 -o ${SITE_LAN_DEV} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE_WG_DEV}'\
 && iptables -v -I INPUT 1 -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE_WG_DEV}'\
 && iptables -v -I FORWARD 1 -i ${SITE_LAN_DEV} -o ${SITE_WG_DEV} -j ACCEPT -m comment --comment 'wireguard-c-${SITE_WG_DEV}'\
 && iptables -v -I FORWARD 1 -i %i -o ${SITE_LAN_DEV} -j ACCEPT -m comment --comment 'wireguard-d-${SITE_WG_DEV}'\
 && iptables -v -I INPUT 1 -i ${SITE_LAN_DEV} -p udp --dport ${SITE_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE_WG_DEV}'"

# on down: delete iptables rules, `iptables -D` is very picky about rule matching
SITE_CONF_POSTDOWN="set -x;\
 iptables -v -t nat -D POSTROUTING -o ${SITE_LAN_DEV} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE_WG_DEV}'\
 && iptables -v -D INPUT -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE_WG_DEV}'\
 && iptables -v -D FORWARD -i ${SITE_LAN_DEV} -o ${SITE_WG_DEV} -j ACCEPT -m comment --comment 'wireguard-c-${SITE_WG_DEV}'\
 && iptables -v -D FORWARD -i %i -o ${SITE_LAN_DEV} -j ACCEPT -m comment --comment 'wireguard-d-${SITE_WG_DEV}'\
 && iptables -v -D INPUT -i ${SITE_LAN_DEV} -p udp --dport ${SITE_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE_WG_DEV}'"

DATE=$(date)

echo
echo "# Manually copy+pasta+run these commands on the site host:"

hl
echo "# Delete any prior device if needed:
"
b
cat <<HEREDOC1a
(wg-quick down ${SITE_WG_DEV}; ip link delete ${SITE_WG_DEV}) || true

HEREDOC1a
n

echo "# Create the Wireguard configuration file:
"
b
cat <<HEREDOC1b
cat <<HEREDOC > ${SITE_WG_CONF}
# ${SITE_WG_CONF}
#
# site ${SITE_NAME}, client ${CLIENT_NAME}
#
# Manually generated by ${SCRIPT} on ${DATE}

[Interface]
Address = ${SITE_ADDR_CIDR}
ListenPort = ${SITE_PORT}
MTU = ${SITE_MTU}
PrivateKey = $(cat ${SITE_KEY})

PreUp = ${SITE12_PREUP}

PostUp = ${SITE_CONF_POSTUP}

PostDown = ${SITE_CONF_POSTDOWN}

# ${CLIENT_NAME} (client)
[Peer]
PublicKey = $(cat ${CLIENT_PUB})
PresharedKey = $(cat ${SITE_CLIENT_PSK})
AllowedIPs = ${SITE12_VNET}
PersistentKeepalive = 300

# test connection:
#     ping ${CLIENT_ADDR}

${COMMENT_LIST_RULES}
HEREDOC

chmod -v 0400 -- "${SITE_WG_CONF}"
HEREDOC1b

n
hl
echo "# Turn it on!

# If systemd is available then create the service and enable the interface:
"
b
cat <<HEREDOC1c
systemctl enable wg-quick@${WG_DEV}.service
systemctl daemon-reload
systemctl start wg-quick@${WG_DEV}
systemctl status wg-quick@${WG_DEV}

HEREDOC1c

n
echo "# If systemd is not available then enable the interface:
"
b

cat <<HEREDOC1b
wg-quick up ${SITE_WG_DEV}
sleep 1
wg
HEREDOC1b

n
hl
echo
echo "# Manually copy+pasta+run this on the client or scan the QR code:"
hl
b

cat <<HEREDOC2b > "${CLIENT_WG_CONF_TEMP}"
# ${CLIENT_WG_CONF}
#
# client ${CLIENT_NAME}
#
# Manually generated by ${SCRIPT} on ${DATE}

[Interface]
Address = ${CLIENT_ADDR_CIDR}
ListenPort = ${CLIENT_WG_PORT}
MTU = ${CLIENT_MTU}
PrivateKey = $(cat ${CLIENT_KEY})
# enabling DNS means you absolutely know what you are doing!
#DNS = ${SITE_DNS}

# ${SITE_NAME} (site)
[Peer]
PublicKey = $(cat ${SITE_PUB})
PresharedKey = $(cat ${SITE_CLIENT_PSK})
AllowedIPs = ${SITE12_VNET}
AllowedIPs = ${SITE_NET}
# including Endpoint treats the peer as a server and this host as a client
Endpoint = ${SITE_ENDPOINT}
PersistentKeepalive = 300

# test connection by
#   ping ${SITE_ADDR}
HEREDOC2b

echo "cat <<HEREDOC > ${CLIENT_WG_CONF}"
cat "${CLIENT_WG_CONF_TEMP}"
echo "HEREDOC
"
n
hl
echo
# Wireguard mobile phone clients can input a configuration from a QR code
qrencode --margin 2 --type ansiutf8 < "${CLIENT_WG_CONF_TEMP}"
echo
hl
echo "
# to test the connection:
# from the client, attempt to ping site DNS ${SITE_DNS}
"
b
echo "ping ${SITE_DNS}"
n
echo "
# from the site, attempt to ping the client VLAN IP ${CLIENT_ADDR}
"
b
echo "ping ${CLIENT_ADDR}"
n

echo "
# from the site, to test MTU size using 'ping' from package 'iputils':
"
b
echo "for mtu in \$(seq 1000 2 1600); do (set -x; ping -c 1 -v -M do -d -O -s \${mtu} ${CLIENT_ADDR}) || break; echo; echo; done"
n

echo "
# to remove from the site using systemd:"
b
echo "
systemctl stop wg-quick@${WG_DEV}.service
systemctl disable wg-quick@${WG_DEV}.service
rm -vi /etc/systemd/system/wg-quick@${WG_DEV}* ${SITE_WG_CONF}
systemctl daemon-reload
systemctl reset-failed"
n
echo "
# without systemd:
"
b
cat <<HEREDOC3
wg-quick down "${SITE_WG_DEV}"
ip link delete "${SITE_WG_DEV}"
HEREDOC3
n
echo "
# check iptables:"
b
echo "
iptables --list
iptables --list -t nat
"
