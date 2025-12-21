#!/usr/bin/env bash
#
# https://gist.github.com/jtmoon79/c951f81f621bb87ddb60836245aca4ff
#
# Script to generate a site-to-site Wireguard IPv4 VPN tunnel
# configuration files, and commands for systemd services.
# This script only prints commands for the user to run manually. It does not
# modify any files.
# This script only covers a narrow scope of possible networking arrangements.
# It may not perfectly fit the user's needs, but it may provide the user with
# a working example that they can modify for their needs.
#
# Site 1 is the Wireguard server.
# Site 2 is the Wireguard client.
# Both are presumed to use systemd services.
#
# As is, the each site host may access the network of the other site.
# For other hosts on the network to access a host on the other side of the
# tunnel, the user must configure each site host to be a designated router.
#
# Pieced together from:
# https://gist.github.com/insdavm/b1034635ab23b8839bf957aa406b5e39
# https://wiki.archlinux.org/title/WireGuard#Additional_routes
# https://www.cyberciti.biz/faq/how-to-set-up-wireguard-firewall-rules-in-linux/
# https://www.ivpn.net/knowledgebase/linux/linux-autostart-wireguard-in-systemd/
#
# BUG: Also, duplicate iptables rules will occur if the user manually adjusts
#      wireguard interfaces using "wg" or "wg-quick" then later uses systemd
#      service calls.
#
# XXX: User can unset DNS entry as desired. It is commented by default.
#
# Also see `wireguard-client-to-site.sh`
# https://gist.github.com/jtmoon79/217e55272c55631ba6025c9f890b3dde
#
# TODO: add `ip route del` in `PreUp` for routes not removed due to
#       power loss
#          (ip -4 -N route; ip -4 route del $NET) || true
#

# defaults
SITE1_DEV_LAN_DEFAULT=eth0
SITE1_MTU_DEFAULT=1420
SITE2_DEV_LAN_DEFAULT=eth0
SITE2_MTU_DEFAULT=1420
SITE12_VLAN_FIRST2_DEFAULT=10.12
SITE12_PORT_DEFAULT=51000

set -euo pipefail

SCRIPT=$(basename -- "${0}")

function usage_exit() {
    echo "\
Generate Wireguard IPv4 VPN site-to-site configuration files and commands.

This script does not modify files. It only prints commands for the user to run manually.
The user must selectively copy+paste+run the highlighted output.

Usage:

    ${SCRIPT} OFFSET FQDN_SITE1 SITE1_NET SITE1_DNS FQDN_SITE2 SITE2_NET

For example:

    ${SCRIPT} 55 my-site1.this-domain.org 192.168.1.0/24 192.168.1.1 my-site2.that-domain.org 192.168.2.0/24

OFFSET is an arbitrary numeric offset to disambiguate potentially multiple
Wireguard interfaces and VLAN networks. Value must be [1, 255].

FQDN_SITE1 acts as the Wireguard server, listening for incoming connections.

FQDN_SITE2 acts as the Wireguard client.

SITE1_NET and SITE2_NET can not be the same network.

The firewall at FQDN_SITE1 must allow incoming UDP traffic. The
port will be shown in the output of the script, or can be overridden via
SITE12_PORT, e.g.

    SITE12_PORT=12345 ${SCRIPT} …

SITE_DNS is added but commented.

Environment variables that can be set to override defaults:

    SITE1_DEV_LAN - default: ${SITE1_DEV_LAN_DEFAULT}
    SITE1_MTU     - default: ${SITE1_MTU_DEFAULT}
    SITE2_DEV_LAN - default: ${SITE2_DEV_LAN_DEFAULT}
    SITE2_MTU     - default: ${SITE2_MTU_DEFAULT}
    SITE12_VLAN_FIRST3 - default: ${SITE12_VLAN_FIRST2_DEFAULT}.OFFSET
                         first 3 octets of the virtual LAN network for both sites
    SITE12_PORT        - default: ${SITE12_PORT_DEFAULT} + OFFSET
                         UDP port for Wireguard server to listen on for incoming connections
                         and Wireguard client to send on

To allow other hosts at each network to connect to hosts on the other side of
the VPN tunnel, the user must push additional routes to the other network hosts.
That is beyond the scope of this script.
But here is a hint: route distributions are often pushed by a DHCP Server.
For example, using the DNSMasq DHCP server, an additional route might look like:

    # add route to site2 network 192.168.2.0/24 via site1 wireguard server gateway at 192.168.1.101
    # due to odd DNSMasq DHCP behavior, must also distribute the default route 0.0.0.0 (presuming gateway 192.168.1.1) (https://ral-arturo.org/2018/09/12/dhcp-static-route.html)
    dhcp-option=121,192.168.2.0/24,192.168.1.101,0.0.0.0/0,192.168.1.1

Good luck‼️
" >&2
    exit 1
}

if [[ ${#} -ne 6 ]]; then
    usage_exit
fi

# check for non-default Linux commands
for prog in wg; do
    if ! which "${prog}" &>/dev/null; then
        echo "command \"${prog}\" not found, is 'wireguard-tools' installed?" >&2
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

declare -i OFFSET=${1}
if [[ ${OFFSET} -eq 0 ]] || [[ ${OFFSET} -gt 255 ]]; then
    echo "Offset must be more than 0 and less than 255" >&2
    exit 1
fi

#
# site 1 variables
#

# first 3 IPv4 network octets of the virtual LAN, make it unique and obvious
SITE12_VLAN_FIRST3=${SITE12_VLAN_FIRST3-"${SITE12_VLAN_FIRST2_DEFAULT}.${OFFSET}"}
SITE12_PORT=${SITE12_PORT-$((${SITE12_PORT_DEFAULT} + ${OFFSET}))}

# e.g. "my-host.domainhost.org"
SITE1_FQDN=${2}
# from "my-host.domain.org" extract "my-host"
SITE1_NAME=${SITE1_FQDN%%.*}
# site 1 LAN network device
SITE1_DEV_LAN=${SITE1_DEV_LAN-eth0}
# site 1 Wireguard network device
SITE1_DEV_WG=wg${OFFSET}
# site 1 wireguard configuration
SITE1_WG_CONF=/etc/wireguard/${SITE1_DEV_WG}.conf
# unique VLAN address
SITE1_ADDR=${SITE12_VLAN_FIRST3}.1
SITE1_ADDR_CIDR=${SITE1_ADDR}/24
SITE1_PORT=${SITE1_PORT-${SITE12_PORT}}
# Internet-accessible Endpoint
SITE1_ENDPOINT=${SITE1_FQDN}:${SITE1_PORT}
# CIDR network of site 1, must match actual network!
SITE1_NET=${3}
SITE1_MTU=${SITE1_MTU-1420}
# DNS Server at site 1
SITE1_DNS=${4}

# site 1 and site 2 virtual network
# must not overlap with $SITE1_NET or $SITE2_NET
# must agree with $SITE1_ADDR and $SITE2_ADDR
SITE12_VNET=${SITE12_VLAN_FIRST3}.0/24

#
# site 2 variables
#

# e.g. "my-other-host.other-domain.org"
SITE2_FQDN=${5}
# from "my-other-host.other-domain.org" extract "my-other-host"
SITE2_NAME=${SITE2_FQDN%%.*}
# site 2 LAN network device
SITE2_DEV_LAN=${SITE2_DEV_LAN-eth0}
# site 2 Wireguard network device
SITE2_DEV_WG=wg${OFFSET}
# presume Debian location of wireguard configuration
SITE2_WG_CONF=/etc/wireguard/${SITE2_DEV_WG}.conf
# unique VLAN address
SITE2_ADDR=${SITE12_VLAN_FIRST3}.2
SITE2_ADDR_CIDR=${SITE2_ADDR}/24
SITE2_PORT=${SITE2_PORT-${SITE12_PORT}}
# Internet-accessible Endpoint, not used
SITE2_ENDPOINT=${SITE2_FQDN}:${SITE2_PORT}
# CIDR network of site 2, must match actual network!
SITE2_NET=${6}
#SITE2_VNET=${SITE12_VLAN_FIRST3}.1/24
SITE2_MTU=${SITE2_MTU-1420}

# minimal sanity check for an easy mistake
if [[ "${SITE1_NET}" = "${SITE2_NET}" ]]; then
    echo "ERROR cannot have the same network for both sites ${SITE1_NET}" >&2
    exit 1
fi

TEMPD=$(umask 0077; mktemp -d -t "${SCRIPT}.XXX")

PEER1_KEY=${TEMPD}/site1-${SITE1_NAME}.key
PEER1_PUB=${TEMPD}/site1-${SITE1_NAME}.pub
PEER2_KEY=${TEMPD}/site2-${SITE2_NAME}.key
PEER2_PUB=${TEMPD}/site2-${SITE2_NAME}.pub
PEER1_PEER2_PSK=${TEMPD}/peer-${SITE1_NAME}-${SITE2_NAME}.psk

# remind user how to check iptables rules and fix bad/duplicate rules.
COMMENT_LIST_RULES="\
# This WireGuard configuration should create 5 iptables rules.
# To list the rules by line number:
#    iptables --list --line-numbers
#    iptables --list --table nat --line-numbers
# In case of duplicate or bad rules, delete each rule individually. For example:
#    iptables --delete FORWARD 10
#    iptables --delete --table nat POSTROUTING 10
# Rules added by this configuration are denoted by the comment sequence \"wireguard\"."

function exit_ () {
    rm -rf -- "${TEMPD}"
}
trap exit_ EXIT

# generate various keys
(
    umask 0077
    wg genkey | tee ${PEER1_KEY} | wg pubkey > ${PEER1_PUB}
    wg genkey | tee ${PEER2_KEY} | wg pubkey > ${PEER2_PUB}
    wg genpsk > "${PEER1_PEER2_PSK}"
)

# enable forwarding, enable debug logging if available
SITE12_PREUP="set -x; sysctl -w net.ipv4.ip_forward=1; ([[ -e /sys/kernel/debug/dynamic_debug/control ]] && (modprobe wireguard && echo module wireguard +p > /sys/kernel/debug/dynamic_debug/control)) || true; ip -4 -N route list;"

# create iptables rules to forward and masquerade between the different networks
# comments added to clarify the rule source and help debugging/fixing rules
#
# the `ip route` comamnds are informational only

# on up: delete leftover iptables rules (if any), create iptables
SITE1_CONF_POSTUP="\
 echo 'Remove any prior iptables rules (this may print errors)';\
 set -x;\
 ip -4 -N route list;\
 iptables -v -t nat -D POSTROUTING -o ${SITE1_DEV_LAN} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE1_DEV_WG}' || true;\
 iptables -v -D INPUT -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE1_DEV_WG}' || true;\
 iptables -v -D FORWARD -i ${SITE1_DEV_LAN} -o ${SITE1_DEV_WG} -j ACCEPT -m comment --comment 'wireguard-c-${SITE1_DEV_WG}' || true;\
 iptables -v -D FORWARD -i %i -o ${SITE1_DEV_LAN} -j ACCEPT -m comment --comment 'wireguard-d-${SITE1_DEV_WG}' || true;\
 iptables -v -D INPUT -i ${SITE1_DEV_LAN} -p udp --dport ${SITE1_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE1_DEV_WG}' || true;\
 echo 'Create iptables rules';\
 iptables -v -t nat -I POSTROUTING 1 -o ${SITE1_DEV_LAN} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE1_DEV_WG}'\
 && iptables -v -I INPUT 1 -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE1_DEV_WG}'\
 && iptables -v -I FORWARD 1 -i ${SITE1_DEV_LAN} -o ${SITE1_DEV_WG} -j ACCEPT -m comment --comment 'wireguard-c-${SITE1_DEV_WG}'\
 && iptables -v -I FORWARD 1 -i %i -o ${SITE1_DEV_LAN} -j ACCEPT -m comment --comment 'wireguard-d-${SITE1_DEV_WG}'\
 && iptables -v -I INPUT 1 -i ${SITE1_DEV_LAN} -p udp --dport ${SITE1_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE1_DEV_WG}'"

# on down: delete iptables rules, `iptables -D` requires many explicit parameters
SITE1_CONF_POSTDOWN="set -x;\
 ip -4 -N route list;\
 iptables -v -t nat -D POSTROUTING -o ${SITE1_DEV_LAN} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE1_DEV_WG}' || true;\
 iptables -v -D INPUT -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE1_DEV_WG}' ;\
 iptables -v -D FORWARD -i ${SITE1_DEV_LAN} -o ${SITE1_DEV_WG} -j ACCEPT -m comment --comment 'wireguard-c-${SITE1_DEV_WG}' || true;\
 iptables -v -D FORWARD -i %i -o ${SITE1_DEV_LAN} -j ACCEPT -m comment --comment 'wireguard-d-${SITE1_DEV_WG}' || true;\
 iptables -v -D INPUT -i ${SITE1_DEV_LAN} -p udp --dport ${SITE1_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE1_DEV_WG}'"

# on up: delete leftover iptables rules (if any), create iptables
SITE2_CONF_POSTUP="\
 echo 'Remove any prior iptables rules (this may print errors)';\
 set -x;\
 ip -4 -N route list;\
 iptables -v -t nat -D POSTROUTING -o ${SITE2_DEV_LAN} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE2_DEV_WG}' || true;\
 iptables -v -D INPUT -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE2_DEV_WG}' || true;\
 iptables -v -D FORWARD -i ${SITE2_DEV_LAN} -o ${SITE2_DEV_WG} -j ACCEPT -m comment --comment 'wireguard-c-${SITE2_DEV_WG}' || true;\
 iptables -v -D FORWARD -i %i -o ${SITE2_DEV_LAN} -j ACCEPT -m comment --comment 'wireguard-d-${SITE2_DEV_WG}' || true;\
 iptables -v -D INPUT -i ${SITE2_DEV_LAN} -p udp --dport ${SITE2_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE2_DEV_WG}' || true;\
 echo 'Create iptables rules';\
 iptables -v -t nat -I POSTROUTING 1 -o ${SITE2_DEV_LAN} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE2_DEV_WG}'\
 && iptables -v -I INPUT 1 -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE2_DEV_WG}'\
 && iptables -v -I FORWARD 1 -i ${SITE2_DEV_LAN} -o ${SITE2_DEV_WG} -j ACCEPT -m comment --comment 'wireguard-c-${SITE2_DEV_WG}'\
 && iptables -v -I FORWARD 1 -i %i -o ${SITE2_DEV_LAN} -j ACCEPT -m comment --comment 'wireguard-d-${SITE2_DEV_WG}'\
 && iptables -v -I INPUT 1 -i ${SITE2_DEV_LAN} -p udp --dport ${SITE2_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE2_DEV_WG}'"

# on down: delete iptables rules, `iptables -D` requires many explicit parameters
SITE2_CONF_POSTDOWN="set -x;\
 ip -4 -N route list;\
 iptables -v -t nat -D POSTROUTING -o ${SITE2_DEV_LAN} -j MASQUERADE -m comment --comment 'wireguard-a-${SITE2_DEV_WG}' || true;\
 iptables -v -D INPUT -i %i -j ACCEPT -m comment --comment 'wireguard-b-${SITE2_DEV_WG}' || true;\
 iptables -v -D FORWARD -i ${SITE2_DEV_LAN} -o ${SITE2_DEV_WG} -j ACCEPT -m comment --comment 'wireguard-c-${SITE2_DEV_WG}' || true;\
 iptables -v -D FORWARD -i %i -o ${SITE2_DEV_LAN} -j ACCEPT -m comment --comment 'wireguard-d-${SITE2_DEV_WG}' || true;\
 iptables -v -D INPUT -i ${SITE2_DEV_LAN} -p udp --dport ${SITE2_PORT} -j ACCEPT -m comment --comment 'wireguard-e-${SITE2_DEV_WG}'"

DATE=$(date)

n
echo "# Manually copy+pasta+run this on site 1 host:
"
hl
echo "
# Remove any prior device with the same name.
"
b
echo "
(wg-quick down ${SITE1_DEV_WG}; ip link delete ${SITE1_DEV_WG}) || true
"
n
hl
b

cat <<HEREDOC1a
cat <<HEREDOC1 > ${SITE1_WG_CONF}
# ${SITE1_WG_CONF}
#
# site-to-site tunnel for
# endpoint ${SITE1_FQDN}:${SITE1_PORT} (Wireguard server) (you are here)
# endpoint ${SITE2_FQDN}:${SITE2_PORT} (Wireguard client)
#
# Manually generated by ${SCRIPT} on ${DATE}

[Interface]
Address = ${SITE1_ADDR_CIDR}
ListenPort = ${SITE1_PORT}
MTU = ${SITE1_MTU}
PrivateKey = $(cat ${PEER1_KEY})

PreUp = ${SITE12_PREUP}

PostUp = ${SITE1_CONF_POSTUP}

PostDown = ${SITE1_CONF_POSTDOWN}

# ${SITE2_NAME} (site 2 client)
[Peer]
PublicKey = $(cat ${PEER2_PUB})
PresharedKey = $(cat ${PEER1_PEER2_PSK})
AllowedIPs = ${SITE12_VNET}
# this network is implied
#AllowedIPs = ${SITE1_NET}
AllowedIPs = ${SITE2_NET}
# unsetting Endpoint treats the peer as a client (and this host as a server)
#Endpoint = ${SITE2_ENDPOINT}
PersistentKeepalive = 59

# test connection:
#     ping ${SITE2_ADDR}

${COMMENT_LIST_RULES}
HEREDOC1

chmod -v 0400 -- "${SITE1_WG_CONF}"

HEREDOC1a
n
echo "
# Create the systemd service and start it
"
b
echo "
systemctl enable wg-quick@${SITE1_DEV_WG}.service
systemctl daemon-reload
systemctl start wg-quick@${SITE1_DEV_WG}
systemctl status wg-quick@${SITE1_DEV_WG}
"
n

echo "
# Or skip systemd

"
b
echo "
wg-quick up ${SITE1_DEV_WG}
sleep 1
wg
"
n
hl
echo "# Manually copy+pasta+run this on site 2 host:"
hl

echo "# Delete any prior device with the same name."
b
echo "
(wg-quick down ${SITE2_DEV_WG}; ip link delete ${SITE2_DEV_WG}) || true
"
n
echo "# Create the configuration file
"

b

cat <<HEREDOC2b
cat <<HEREDOC2 > ${SITE2_WG_CONF}
# ${SITE2_WG_CONF}
#
# site-to-site tunnel for
# endpoint ${SITE1_FQDN}:${SITE1_PORT} (Wireguard server)
# endpoint ${SITE2_FQDN}:${SITE2_PORT} (Wireguard client) (you are here)
#
# Manually generated by ${SCRIPT} on ${DATE}

[Interface]
Address = ${SITE2_ADDR_CIDR}
ListenPort = ${SITE2_PORT}
MTU = ${SITE2_MTU}
PrivateKey = $(cat ${PEER2_KEY})
# enabling DNS means you absolutely know what you are doing!
#DNS = ${SITE1_DNS}

PreUp = ${SITE12_PREUP}

PostUp = ${SITE2_CONF_POSTUP}

PostDown = ${SITE2_CONF_POSTDOWN}

# ${SITE1_NAME} (site 1 server)
[Peer]
PublicKey = $(cat ${PEER1_PUB})
PresharedKey = $(cat ${PEER1_PEER2_PSK})
AllowedIPs = ${SITE12_VNET}
AllowedIPs = ${SITE1_NET}
# this network is implied
#AllowedIPs = ${SITE2_NET}
# setting Endpoint treats the peer as a server (and this host as a client)
Endpoint = ${SITE1_ENDPOINT}
PersistentKeepalive = 59

# test connection:
#     ping ${SITE1_ADDR}

${COMMENT_LIST_RULES}
HEREDOC2

chmod -v 0400 -- "${SITE2_WG_CONF}"
systemctl enable wg-quick@${SITE2_DEV_WG}.service
systemctl daemon-reload
systemctl start wg-quick@${SITE2_DEV_WG}
systemctl status wg-quick@${SITE2_DEV_WG}

HEREDOC2b

n
hl

echo "
# from site 1, to test MTU size using 'ping' from package 'iputils-ping':
"
b
echo "for mtu in \$(seq 1000 2 1600); do (set -x; ping -c 1 -v -M do -d -O -s \${mtu} ${SITE2_ADDR}) || break; echo; echo; done"
n

echo "
# to remove wireguard interface and systemd service from a site:"
b
echo "
systemctl stop wg-quick@${SITE1_DEV_WG}.service
systemctl disable wg-quick@${SITE1_DEV_WG}.service
rm -vi /etc/systemd/system/wg-quick@${SITE1_DEV_WG}* ${SITE1_WG_CONF}
systemctl daemon-reload
systemctl reset-failed"
n
echo "
# to only remove the interface not using systemd:"
b
echo "
wg-quick down ${SITE1_DEV_WG}
ip link delete ${SITE1_DEV_WG}
"
n
echo "
# to review iptables:"
b
echo "
iptables --list && iptables --list -t nat
(iptables --list && iptables --list -t nat) | grep -Fe 'wireguard-'
"
n
