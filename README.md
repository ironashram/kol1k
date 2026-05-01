# OpenStack on libvirt

Bootstraps a small OpenStack cluster on a single libvirt host using OpenTofu for VM provisioning and Kolla Ansible for OpenStack deployment. Sized as a test bed for [kronos-openstack](https://github.com/kronos-openstack/kronos), a Prometheus-driven workload rebalancer for OpenStack.

## Prerequisites

1.  **libvirt host** with KVM and a working `default` storage pool. Nested KVM enabled on the hypervisor.
2.  **OpenTofu** on your local machine.
3.  **OpenBao** (or compatible) reachable, with a `kv/openstack-vars` entry containing `domain_name` and `ssh_public_key`.
4.  **Python/Pip** for Kolla Ansible.

## Step 1: Provision VMs with OpenTofu

1.  From the repo root:
    ```bash
    make plan
    make apply
    ```

    This creates:
    *   3 libvirt networks: `kol1k-mgmt` (NAT, host on `.1`), `kol1k-provider` and `kol1k-tenant` (isolated, no IP, no DHCP - L2-only for Neutron).
    *   1 base volume (Ubuntu Noble cloud image) and per-VM backing-store overlays in the default pool.
    *   `control_count` control + `compute_count` compute VMs with three virtio NICs each, cloud-init from a generated cidata ISO.

2.  Override defaults via `terraform/terraform.tfvars` if needed:

    Static IPs assigned by cloud-init: control-N at `<mgmt>.${10+N}`, compute-N at `<mgmt>.${20+N}`. Tenant IPs follow the same offsets on `tenant_ip_base`.

3.  State lives in S3; set `TF_VAR_remote_state_s3_endpoint` and AWS creds in your env. The Makefile uses `tofu state` underneath; `make list`, `make rm '<addr>'`, `make show` etc. all work.

## Step 2: Prepare for Kolla Ansible

SSH connectivity: bare hostnames `kol1k-control-N` and `kol1k-compute-N` need to resolve to the mgmt IPs from your deployment host (e.g. via `~/.ssh/config.d/kol1k`). Cloud-init installs the `ubuntu` user with the SSH key from Vault and grants passwordless sudo.

## Step 3: Deploy OpenStack

The repo's `kolla/` directory is symlinked to `/etc/kolla` so kolla-ansible config (globals, inventory, passwords, certificates) lives in-tree. Set up once:

```bash
sudo ln -s "$PWD/kolla" /etc/kolla
python -m venv .kolla-venv
source .kolla-venv/bin/activate
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2025.2
kolla-ansible install-deps
kolla-genpwd
```

Then bootstrap and deploy:

```bash
kolla-ansible bootstrap-servers -i /etc/kolla/multinode
kolla-ansible prechecks       -i /etc/kolla/multinode
kolla-ansible deploy          -i /etc/kolla/multinode
kolla-ansible post-deploy
```

Everything under `kolla/` is gitignored except `globals.yml` and `multinode` (allowlist in `.gitignore`).

## Topology

Control nodes run the API/DB/messaging plane plus the OVN databases. Compute nodes run nova-compute, openvswitch, and ovn-controller, and act as OVN gateway chassis (`enable-chassis-as-gw` via `[network]` membership).

Inventory `kolla/multinode` splits the over-loaded default `[network]` group: `[loadbalancer:children]` and `[neutron:children]` are pointed at `control` (kolla's stock template ties them to `network`, which would drag haproxy and neutron-server onto every gateway chassis), while `[network]` itself stays on the compute hosts.

Scale by adjusting `control_count` / `compute_count` in `terraform/variables.tf` and the corresponding host lists in `kolla/multinode`.

## Networking

ML2/OVN (`neutron_plugin_agent: ovn`). Three NICs per node:

- `eth0` mgmt - static IP, default route
- `eth1` provider - no host IP, plumbed into `br-ex`
- `eth2` tenant

## Storage

Cinder is disabled; instance disks live on the compute node's local filesystem. Live migration is block-migration only.

## Virtualization

`nova_compute_virt_type` is `qemu` (TCG) by default. If the hypervisor exposes nested KVM, flip to `kvm` for ~10x guest speed:

```bash
modprobe -r kvm_amd && modprobe kvm_amd nested=1   # or kvm_intel
```

The kolla VMs are pinned to `pc` (i440fx). q35 plus the libvirt provider's auto-generated `pcie-root-port` controllers triggers a Linux 6.8 PCI-PM bug where virtio devices initialize stuck in D3cold and the kernel never sees `/dev/vda` - boot hangs in initramfs.

## Cloud-init

- `unattended-upgrades` and `snapd` are purged on first boot via `apt purge` in `runcmd`.
- snapd is pinned to apt priority `-10` (`/etc/apt/preferences.d/no-snapd`) so it can't be reinstalled.
- `eth1`/`eth2` are flagged `optional: true` in netplan so `systemd-networkd-wait-online` doesn't stall on them.

## Observability

Prometheus and Grafana are enabled in `globals.yml`. Trimmed to `node` + `libvirt` + the host-level `ovs-exporter`/`ovn-exporter` set; other kolla exporters disabled.

**Host exporters** (`roles/ovs-ovn-exporter/`): self-contained Ansible role that installs the two exporters as systemd units (`9475` ovs, `9476` ovn). Run from the repo root:

```bash
ansible-playbook -i /etc/kolla/multinode ovn-exporter.yaml
```

The role dispatches by inventory group: `ovs-exporter` on `[openvswitch]`, `ovn-exporter` on `[ovn-database]`.

**Prometheus scrape config**: `kolla/config/prometheus/prometheus.yml.d/ovs-ovn-exporter.yml`.

**Grafana dashboards**: `kolla/config/grafana/dashboards/openstack/` is a symlink to `roles/ovs-ovn-exporter/files/` (4 dashboards). `kolla/config/grafana/provisioning.yaml` enables `foldersFromFilesStructure: true` so the subdir surfaces as a Grafana folder.

**OVN socket exposure**: `ovn_{controller,nb_db,sb_db,northd}_extra_volumes` in `globals.yml` mount `/run/ovn` into the matching kolla containers so the exporters can read sockets/PIDs from the host.
