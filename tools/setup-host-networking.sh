#!/bin/bash
# One-shot host networking for the kol1k libvirt host.
# Plumbs a tagged VLAN from the upstream switch into the kol1k-provider bridge
# by enslaving a <parent>.<vlan> sub-interface to it. The OpenStack flat
# provider network (lab-net, physnet1) then has an L2 uplink and VMs on it
# become reachable from that VLAN.
#
# Idempotent. Run once after a fresh host bring-up (or after the libvirt
# bridge is recreated).

set -euo pipefail

CON_NAME="${CON_NAME:-kol1k-vlan101}"
PARENT="${PARENT:-enp10s0}"
VLAN_ID="${VLAN_ID:-101}"
BRIDGE="${BRIDGE:-kol1kprov0}"

log() { printf '[host-net] %s\n' "$*"; }

if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
  echo "error: bridge $BRIDGE does not exist - bring up libvirt net kol1k-provider first" >&2
  exit 1
fi

if nmcli -t -f NAME connection show | grep -qx "$CON_NAME"; then
  log "$CON_NAME already exists"
else
  sudo nmcli connection add type vlan con-name "$CON_NAME" \
    ifname "${PARENT}.${VLAN_ID}" dev "$PARENT" id "$VLAN_ID" \
    master "$BRIDGE" slave-type bridge \
    ipv4.method disabled ipv6.method disabled \
    connection.autoconnect yes
  log "$CON_NAME created (${PARENT}.${VLAN_ID} -> $BRIDGE)"
fi

sudo nmcli connection up "$CON_NAME" >/dev/null
log "$CON_NAME active"
