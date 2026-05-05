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
AGGREGATE_HOSTS="${AGGREGATE_HOSTS:-$(openstack hypervisor list -f value -c 'Hypervisor Hostname' | tr '\n' ' ')}"

NETWORK_NAME="${NETWORK_NAME:-lab-net}"
SUBNET_NAME="${SUBNET_NAME:-lab-subnet}"
PHYSNET="${PHYSNET:-physnet1}"
SUBNET_CIDR="${SUBNET_CIDR:-10.178.0.0/24}"
SUBNET_POOL_START="${SUBNET_POOL_START:-10.178.0.100}"
SUBNET_POOL_END="${SUBNET_POOL_END:-10.178.0.199}"
SUBNET_GATEWAY="${SUBNET_GATEWAY:-10.178.0.1}"

TENANT_NETWORK_NAME="${TENANT_NETWORK_NAME:-lab-tenant}"
TENANT_SUBNET_NAME="${TENANT_SUBNET_NAME:-lab-tenant-subnet}"
TENANT_SUBNET_CIDR="${TENANT_SUBNET_CIDR:-192.168.50.0/24}"
TENANT_SUBNET_GATEWAY="${TENANT_SUBNET_GATEWAY:-192.168.50.1}"
TENANT_POOL_START="${TENANT_POOL_START:-192.168.50.100}"
TENANT_POOL_END="${TENANT_POOL_END:-192.168.50.199}"
TENANT_DNS="${TENANT_DNS:-1.1.1.1}"

ROUTER_NAME="${ROUTER_NAME:-lab-router}"

SECGROUP_NAME="${SECGROUP_NAME:-lab-sg}"

KEYPAIR_NAME="${KEYPAIR_NAME:-lab-key}"
KEYPAIR_PUBKEY_FILE="${KEYPAIR_PUBKEY_FILE:-$HOME/.ssh/id_ed25519.pub}"

TENANT_VM_NAME="${TENANT_VM_NAME:-lab-tenant-test}"

FLAVOR_NAME="${FLAVOR_NAME:-lab.tiny}"
FLAVOR_VCPUS="${FLAVOR_VCPUS:-1}"
FLAVOR_RAM="${FLAVOR_RAM:-128}"
FLAVOR_DISK="${FLAVOR_DISK:-1}"

VM_COUNT="${VM_COUNT:-20}"
VM_PREFIX="${VM_PREFIX:-kronos-vm}"
VM_TARGET_HOST="${VM_TARGET_HOST:-$(openstack hypervisor list -f value -c 'Hypervisor Hostname' | head -n1)}"
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
      --external \
      --share \
      "$NETWORK_NAME" >/dev/null
    log "network $NETWORK_NAME created (flat on $PHYSNET, external)"
  else
    local is_external
    is_external=$(openstack network show "$NETWORK_NAME" -f value -c "router:external")
    if [ "$is_external" != "True" ]; then
      openstack network set --external "$NETWORK_NAME" >/dev/null
      log "network $NETWORK_NAME flagged external"
    fi
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

ensure_tenant_network() {
  if ! openstack network show "$TENANT_NETWORK_NAME" >/dev/null 2>&1; then
    openstack network create \
      --provider-network-type geneve \
      "$TENANT_NETWORK_NAME" >/dev/null
    log "network $TENANT_NETWORK_NAME created (geneve)"
  fi
  if ! openstack subnet show "$TENANT_SUBNET_NAME" >/dev/null 2>&1; then
    openstack subnet create \
      --network "$TENANT_NETWORK_NAME" \
      --subnet-range "$TENANT_SUBNET_CIDR" \
      --allocation-pool "start=$TENANT_POOL_START,end=$TENANT_POOL_END" \
      --gateway "$TENANT_SUBNET_GATEWAY" \
      --dns-nameserver "$TENANT_DNS" \
      "$TENANT_SUBNET_NAME" >/dev/null
    log "subnet $TENANT_SUBNET_NAME created ($TENANT_SUBNET_CIDR)"
  fi
}

ensure_router() {
  if ! openstack router show "$ROUTER_NAME" >/dev/null 2>&1; then
    openstack router create "$ROUTER_NAME" >/dev/null
    log "router $ROUTER_NAME created"
  fi
  if ! openstack router show "$ROUTER_NAME" -f value -c external_gateway_info \
       | grep -q network_id; then
    openstack router set --external-gateway "$NETWORK_NAME" "$ROUTER_NAME" >/dev/null
    log "router $ROUTER_NAME gateway -> $NETWORK_NAME"
  fi
  local tenant_subnet_id
  tenant_subnet_id=$(openstack subnet show "$TENANT_SUBNET_NAME" -f value -c id)
  if ! openstack port list --router "$ROUTER_NAME" -f value -c "Fixed IP Addresses" \
       | grep -q "$tenant_subnet_id"; then
    openstack router add subnet "$ROUTER_NAME" "$TENANT_SUBNET_NAME" >/dev/null
    log "router $ROUTER_NAME interface -> $TENANT_SUBNET_NAME"
  fi
}

ensure_keypair() {
  if openstack keypair show "$KEYPAIR_NAME" >/dev/null 2>&1; then return; fi
  if [ ! -f "$KEYPAIR_PUBKEY_FILE" ]; then
    echo "error: $KEYPAIR_PUBKEY_FILE not found (set KEYPAIR_PUBKEY_FILE)" >&2
    exit 1
  fi
  openstack keypair create --public-key "$KEYPAIR_PUBKEY_FILE" "$KEYPAIR_NAME" >/dev/null
  log "keypair $KEYPAIR_NAME created from $KEYPAIR_PUBKEY_FILE"
}

ensure_secgroup() {
  if openstack security group show "$SECGROUP_NAME" >/dev/null 2>&1; then return; fi
  openstack security group create "$SECGROUP_NAME" >/dev/null
  openstack security group rule create --proto icmp "$SECGROUP_NAME" >/dev/null
  openstack security group rule create --proto tcp --dst-port 22 "$SECGROUP_NAME" >/dev/null
  log "security group $SECGROUP_NAME (icmp + ssh)"
}

ensure_quota() {
  local project="${OS_PROJECT_NAME:-admin}"
  local instances="${QUOTA_INSTANCES:-$(( VM_COUNT > 100 ? VM_COUNT : 100 ))}"
  local cores="${QUOTA_CORES:-$(( instances * FLAVOR_VCPUS ))}"
  local ram="${QUOTA_RAM:-$(( instances * FLAVOR_RAM ))}"
  openstack quota set \
    --instances "$instances" \
    --cores "$cores" \
    --ram "$ram" \
    "$project" >/dev/null
  log "quota: $project instances=$instances cores=$cores ram=${ram}MiB"
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
      --key-name "$KEYPAIR_NAME" \
      "${host_arg[@]}" \
      "$name" >/dev/null
    log "vm $name created${VM_TARGET_HOST:+ on $VM_TARGET_HOST}"
    created=$((created + 1))
    sleep "$VM_CREATE_DELAY"
  done
  log "vms: ${created} created this run"
}

ensure_tenant_test_vm() {
  if ! openstack server show "$TENANT_VM_NAME" >/dev/null 2>&1; then
    openstack server create \
      --flavor "$FLAVOR_NAME" \
      --image "$CIRROS_IMAGE_NAME" \
      --network "$TENANT_NETWORK_NAME" \
      --security-group "$SECGROUP_NAME" \
      --key-name "$KEYPAIR_NAME" \
      "$TENANT_VM_NAME" >/dev/null
    log "vm $TENANT_VM_NAME created on $TENANT_NETWORK_NAME"
  fi
  local vm_port=""
  local i
  for i in $(seq 1 20); do
    vm_port=$(openstack port list --server "$TENANT_VM_NAME" --network "$TENANT_NETWORK_NAME" -f value -c id | head -n1)
    [ -n "$vm_port" ] && break
    sleep 2
  done
  if [ -z "$vm_port" ]; then
    log "warn: no port for $TENANT_VM_NAME on $TENANT_NETWORK_NAME after wait"
    return
  fi
  local existing_fip
  existing_fip=$(openstack floating ip list --port "$vm_port" -f value -c "Floating IP Address" | head -n1)
  if [ -z "$existing_fip" ]; then
    local new_fip
    new_fip=$(openstack floating ip create "$NETWORK_NAME" -f value -c floating_ip_address)
    openstack server add floating ip "$TENANT_VM_NAME" "$new_fip" >/dev/null
    log "fip $new_fip -> $TENANT_VM_NAME"
  fi
}

ensure_aggregate
ensure_image
ensure_flavor
ensure_network
ensure_tenant_network
ensure_router
ensure_secgroup
ensure_keypair
ensure_quota
ensure_vms
ensure_tenant_test_vm

log "current servers:"
openstack server list -c Name -c Status -c Host -c Networks
