#!/bin/bash

set -e

# TODO: we need to
# PREBOOTSTRAP
# - issue temporary nebula credentials with limited access
# BOOTSTRAP
# - copy over files(nebula stuff??)
# - get nebula running for first highstate
# 

hostname=$1
role=$2

# We actually only validate role to make sure the correct
# thing ends up in the grains.
if [[ "$role" == "nebula-lighthouse" ]]
then
  echo "allocating lighthouse"
elif [[ "$role" == "nebula-client" ]]
then
  echo 'allocating client'
else
  echo "unknown role: ${role}"
  exit 1
fi

if ! command -v hostnamectl &> /dev/null
then
  echo "hostnamectl missing, skipping hostname configuration"
else
  hostnamectl set-hostname $hostname

  echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
fi

mkdir -p /etc/salt/

echo 'writing grains'
cat <<EOF > /etc/salt/grains
roles:
  - $role
EOF

echo 'writing minion'
cat <<EOF > /etc/salt/minion
##### Primary configuration settings #####
##########################################
# This configuration file is used to manage the behavior of the Salt Minion.
# With the exception of the location of the Salt Master Server, values that are
# commented out but have an empty line after the comment are defaults that need
# not be set in the config. If there is no blank line after the comment, the
# value is presented as an example and is not the default.

# Set the location of the salt master server. If the master server cannot be
# resolved, then the minion will fail to start.
master: 172.16.91.1 # Nebula overlay address

# TODO: include whatever settings we may require in the future.
EOF

echo 'writing temporary nebula config'
cat <<EOF > config.yml
# PKI defines the location of credentials for this node. Each of these can also be inlined by using the yaml ": |" syntax.
pki:
  # The CAs that are accepted by this node. Must contain one or more certificates created by 'nebula-cert ca'
  ca: ./ca.crt
  cert: ./self.crt
  key: ./self.key

# The static host map defines a set of hosts with fixed IP addresses on the internet (or any network).
# A host can have multiple fixed IP addresses defined here, and nebula will try each when establishing a tunnel.
# The syntax is:
#   "{nebula ip}": ["{routable ip/dns name}:{routable port}"]
# Example, if your lighthouse has the nebula IP of 192.168.100.1 and has the real ip address of 100.64.22.11 and runs on port 4242:
static_host_map:
  "172.16.91.250": ["192.168.100.4:4242"]

lighthouse:
  # am_lighthouse is used to enable lighthouse functionality for a node. This should ONLY be true on nodes
  # you have configured to be lighthouses in your network
  am_lighthouse: false
  # serve_dns optionally starts a dns listener that responds to various queries and can even be
  # delegated to for resolution
  #serve_dns: false
  #dns:
    # The DNS host defines the IP to bind the dns listener to. This also allows binding to the nebula node IP.
    #host: 0.0.0.0
    #port: 53
  # interval is the number of seconds between updates from this node to a lighthouse.
  # during updates, a node sends information about its current IP addresses to each node.
  interval: 60
  # hosts is a list of lighthouse hosts this node should report to and query from
  hosts:
    - "172.16.91.250" # Hardcoded lighthouse

# Port Nebula will be listening on. The default here is 4242. For a lighthouse node, the port should be defined,
# however using port 0 will dynamically assign a port and is recommended for roaming nodes.
listen:
  # To listen on both any ipv4 and ipv6 use "[::]"
  host: 0.0.0.0
  port: 0

punchy:
  # Continues to punch inbound/outbound at a regular interval to avoid expiration of firewall nat mappings
  punch: true

  # respond means that a node you are trying to reach will connect back out to you if your hole punching fails
  # this is extremely useful if one node is behind a difficult nat, such as a symmetric NAT
  # Default is false
  respond: true

  # delays a punch response for misbehaving NATs, default is 1 second, respond must be true to take effect
  delay: 1s

# Configure the private interface. Note: addr is baked into the nebula certificate
tun:
  # When tun is disabled, a lighthouse can be started without a local tun interface (and therefore without root)
  disabled: false
  # Name of the device
  dev: nebula-boot1
  # Toggles forwarding of local broadcast packets, the address of which depends on the ip/mask encoded in pki.cert
  drop_local_broadcast: false
  # Toggles forwarding of multicast packets
  drop_multicast: false
  # Sets the transmit queue length, if you notice lots of transmit drops on the tun it may help to raise this number. Default is 500
  tx_queue: 500
  # Default MTU for every packet, safe setting is (and the default) 1300 for internet based traffic
  mtu: 1300
  # Route based MTU overrides, you have known vpn ip paths that can support larger MTUs you can increase/decrease them here
  routes:

  # Unsafe routes allows you to route traffic over nebula to non-nebula nodes
  # Unsafe routes should be avoided unless you have hosts/services that cannot run nebula
  # NOTE: The nebula certificate of the "via" node *MUST* have the "route" defined as a subnet in its certificate
  unsafe_routes:

# Nebula security group configuration
firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    # Allow all outbound traffic from this node
    - port: any
      proto: any
      host: any

  inbound:
    # TODO: lock down protocols/ports/hosts?
    - port: any
      proto: any
      host: any
EOF

echo 'apt init'
apt update -q  && apt upgrade -y -q

echo 'getting killall'
apt install -y psmisc

# Booting temporary nebula
echo 'starting temporary nebula'
./nebula -config config.yml &

echo 'install salt minion'
apt install -y -q -o Dpkg::Options::="--force-confold" salt-minion

echo 'restarting minion with nebula up'
systemctl restart salt-minion.service

echo 'Go accept the key on the master, I will wait'
read -rsp $'Press any key to continue...\n' -n1 key

echo 'Go install the permanent cert and encrypted key in master'
read -rsp $'Press any key to continue...\n' -n1 key

salt-call state.highstate

# TODO: highstate

# Wait a beat before we kill nebula.
# 
# TODO: we should check to ensure another
# nebula instance is running to avoid killing the only connection
# the minion has to the master.
sleep 2

echo 'killing temporary nebula'
killall nebula