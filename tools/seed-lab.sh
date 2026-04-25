#!/bin/bash
# Seed the lab: aggregate, cirros image, flavor, network/subnet, secgroup, VMs.
# Idempotent. Run after kolla-ansible deploy + post-deploy.

set -euo pipefail

source /etc/kolla/admin-openrc.sh

CIRROS_VERSION="${CIRROS_VERSION:-0.6.3}"
CIRROS_FILE="cirros-${CIRROS_VERSION}-x86_64-disk.img"
CIRROS_URL="https://download.cirros-cloud.net/${CIRROS_VERSION}/${CIRROS_FILE}"
CIRROS_IMAGE_NAME="${CIRROS_IMAGE_NAME:-cirros}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/tmp}"

AGGREGATE_NAME="${AGGREGATE_NAME:-test-agg}"
AGGREGATE_HOSTS="${AGGREGATE_HOSTS:-kol1k-control-1 kol1k-compute-1}"

NETWORK_NAME="${NETWORK_NAME:-lab-net}"
SUBNET_NAME="${SUBNET_NAME:-lab-subnet}"
PHYSNET="${PHYSNET:-physnet1}"
SUBNET_CIDR="${SUBNET_CIDR:-10.178.0.0/24}"
SUBNET_POOL_START="${SUBNET_POOL_START:-10.178.0.100}"
SUBNET_POOL_END="${SUBNET_POOL_END:-10.178.0.199}"
SUBNET_GATEWAY="${SUBNET_GATEWAY:-10.178.0.1}"

SECGROUP_NAME="${SECGROUP_NAME:-lab-sg}"

FLAVOR_NAME="${FLAVOR_NAME:-lab.tiny}"
FLAVOR_VCPUS="${FLAVOR_VCPUS:-1}"
FLAVOR_RAM="${FLAVOR_RAM:-256}"
FLAVOR_DISK="${FLAVOR_DISK:-1}"

VM_COUNT="${VM_COUNT:-10}"
VM_PREFIX="${VM_PREFIX:-kronos-vm}"
VM_TARGET_HOST="${VM_TARGET_HOST:-kol1k-compute-1}"
VM_CREATE_DELAY="${VM_CREATE_DELAY:-5}"

log() { printf '[seed] %s\n' "$*"; }

ensure_aggregate() {
  if ! openstack aggregate show "$AGGREGATE_NAME" >/dev/null 2>&1; then
    openstack aggregate create "$AGGREGATE_NAME" >/dev/null
    log "aggregate $AGGREGATE_NAME created"
  fi
  local current
  current=$(openstack aggregate show "$AGGREGATE_NAME" -f json | python3 -c 'import sys,json; print(" ".join(json.load(sys.stdin).get("hosts") or []))')
  for h in $AGGREGATE_HOSTS; do
    if [[ " $current " == *" $h "* ]]; then continue; fi
    openstack aggregate add host "$AGGREGATE_NAME" "$h" >/dev/null
    log "aggregate $AGGREGATE_NAME += $h"
  done
}

ensure_image() {
  if openstack image show "$CIRROS_IMAGE_NAME" >/dev/null 2>&1; then return; fi
  if [ ! -f "$DOWNLOAD_DIR/$CIRROS_FILE" ]; then
    log "downloading $CIRROS_FILE"
    curl -fL -o "$DOWNLOAD_DIR/$CIRROS_FILE" "$CIRROS_URL"
  fi
  openstack image create --disk-format qcow2 --container-format bare \
    --file "$DOWNLOAD_DIR/$CIRROS_FILE" --public "$CIRROS_IMAGE_NAME" >/dev/null
  log "image $CIRROS_IMAGE_NAME created"
}

ensure_flavor() {
  if openstack flavor show "$FLAVOR_NAME" >/dev/null 2>&1; then return; fi
  openstack flavor create --vcpus "$FLAVOR_VCPUS" --ram "$FLAVOR_RAM" \
    --disk "$FLAVOR_DISK" "$FLAVOR_NAME" >/dev/null
  log "flavor $FLAVOR_NAME created (${FLAVOR_VCPUS}vcpu/${FLAVOR_RAM}M/${FLAVOR_DISK}G)"
}

ensure_network() {
  if ! openstack network show "$NETWORK_NAME" >/dev/null 2>&1; then
    openstack network create \
      --provider-network-type flat \
      --provider-physical-network "$PHYSNET" \
      --share \
      "$NETWORK_NAME" >/dev/null
    log "network $NETWORK_NAME created (flat on $PHYSNET)"
  fi
  if ! openstack subnet show "$SUBNET_NAME" >/dev/null 2>&1; then
    openstack subnet create \
      --network "$NETWORK_NAME" \
      --subnet-range "$SUBNET_CIDR" \
      --allocation-pool "start=$SUBNET_POOL_START,end=$SUBNET_POOL_END" \
      --gateway "$SUBNET_GATEWAY" \
      "$SUBNET_NAME" >/dev/null
    log "subnet $SUBNET_NAME created ($SUBNET_CIDR pool $SUBNET_POOL_START-$SUBNET_POOL_END)"
  fi
}

ensure_secgroup() {
  if openstack security group show "$SECGROUP_NAME" >/dev/null 2>&1; then return; fi
  openstack security group create "$SECGROUP_NAME" >/dev/null
  openstack security group rule create --proto icmp "$SECGROUP_NAME" >/dev/null
  openstack security group rule create --proto tcp --dst-port 22 "$SECGROUP_NAME" >/dev/null
  log "security group $SECGROUP_NAME (icmp + ssh)"
}

ensure_vms() {
  local net_id
  net_id=$(openstack network show "$NETWORK_NAME" -f value -c id)
  local i name created=0
  local host_arg=()
  if [ -n "$VM_TARGET_HOST" ]; then host_arg=(--host "$VM_TARGET_HOST"); fi
  for i in $(seq -f '%02g' 1 "$VM_COUNT"); do
    name="${VM_PREFIX}-${i}"
    if openstack server show "$name" >/dev/null 2>&1; then continue; fi
    openstack server create \
      --flavor "$FLAVOR_NAME" \
      --image "$CIRROS_IMAGE_NAME" \
      --network "$net_id" \
      --security-group "$SECGROUP_NAME" \
      "${host_arg[@]}" \
      "$name" >/dev/null
    log "vm $name created${VM_TARGET_HOST:+ on $VM_TARGET_HOST}"
    created=$((created + 1))
    sleep "$VM_CREATE_DELAY"
  done
  log "vms: ${created} created this run"
}

ensure_aggregate
ensure_image
ensure_flavor
ensure_network
ensure_secgroup
ensure_vms

log "current servers:"
openstack server list -c Name -c Status -c Host -c Networks
