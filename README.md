# OpenStack on libvirt

Bootstraps a small OpenStack cluster on a single libvirt host using OpenTofu for VM provisioning and Kolla Ansible for OpenStack deployment. Sized as a test bed for [kronos-openstack](https://github.com/kronos-openstack/kronos), a Prometheus-driven workload rebalancer for OpenStack.

## Prerequisites

1.  **libvirt host** with KVM and a working `default` storage pool. Nested KVM enabled on the hypervisor.
2.  **OpenTofu** on your local machine.
3.  **HashiCorp Vault** (or compatible) reachable, with a `kv/openstack-vars` entry containing `domain_name` and `ssh_public_key`.
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
    *   1 control + 2 compute VMs with three virtio NICs each, cloud-init from a generated cidata ISO.

2.  Override defaults via `terraform/terraform.tfvars` if needed:

    ```hcl
    libvirt_uri        = "qemu:///system"
    storage_pool       = "default"
    mgmt_ip_base       = "192.168.130"
    tenant_ip_base     = "192.168.132"
    control_count      = 1
    compute_count      = 2
    control_vcpu_count = 8
    control_memory_mb  = 16384
    compute_vcpu_count = 4
    compute_memory_mb  = 8192
    ```

    Static IPs assigned by cloud-init: control-N at `<mgmt>.${10+N}`, compute-N at `<mgmt>.${20+N}`. Tenant IPs follow the same offsets on `tenant_ip_base`.

3.  State lives in S3 (`tfdata-v2/openstack/terraform.tfstate`); set `TF_VAR_remote_state_s3_endpoint` and AWS creds in your env. The Makefile uses `tofu state` underneath; `make list`, `make rm '<addr>'`, `make show` etc. all work.

## Step 2: Prepare for Kolla Ansible

SSH connectivity: bare hostnames `kol1k-control-1`, `kol1k-compute-{1,2}` need to resolve to the mgmt IPs from your deployment host (e.g. via `~/.ssh/config.d/kol1k`). Cloud-init installs the `ubuntu` user with the SSH key from Vault and grants passwordless sudo.

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

## Notes

*   **Topology:** 1 control (kolla `control` + `network` + `monitoring`) + 2 compute. Control is control-only; nova-compute runs on the compute nodes only.
*   **Networking plugin:** OVN (`neutron_plugin_agent: ovn` in `globals.yml`). Three NICs per node - eth0 mgmt with static IP + default route, eth1 provider (no IP, plumbed into `br-ex`), eth2 tenant.
*   **Storage:** Cinder disabled. Compute nodes use local disk for instance storage. Live migration is block-migration only.
*   **Virtualization:** `nova_compute_virt_type` is `qemu` (TCG) in `globals.yml`. If your hypervisor exposes nested KVM, flip to `kvm` for ~10x guest speed:
    ```bash
    modprobe -r kvm_amd && modprobe kvm_amd nested=1   # or kvm_intel
    ```
*   **Machine type:** the kolla VMs use `pc` (i440fx). q35 + the libvirt provider's auto-generated `pcie-root-port` controllers triggers a Linux 6.8 PCI-PM bug where virtio devices initialize stuck in D3cold and the kernel never sees `/dev/vda` - boot hangs in initramfs.
*   **Cloud-init:** `unattended-upgrades` and `snapd` are purged on first boot (`apt purge` in runcmd) and snapd is pinned to priority `-10` via `/etc/apt/preferences.d/no-snapd` so it can never be reinstalled.
*   **Prometheus:** trimmed to `node` and `libvirt` exporters (cadvisor, alertmanager, openstack-exporter, etc. disabled). Enough for kronos-style imbalance detection; minimizes container count and CPU footprint.
