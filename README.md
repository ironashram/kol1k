# OpenStack on Synology NAS

This project bootstraps an OpenStack cluster on a Synology NAS using Terraform for VM provisioning and Kolla Ansible for OpenStack deployment. The cluster is sized and configured as a test bed for [kronos-openstack](https://github.com/kronos-openstack/kronos), a Prometheus-driven workload rebalancer for OpenStack.

## Prerequisites

1.  **Synology NAS** with "Virtual Machine Manager" installed.
2.  **Terraform** installed on your local machine.
3.  **Python/Pip** installed for Kolla Ansible.
4.  **SSH Access** enabled on your Synology NAS.


## Step 1: Provision VMs with Terraform

1.  Navigate to the `terraform` directory:
    ```bash
    cd terraform
    ```

2.  Create a `terraform.tfvars` file to configure your environment:

    > **Note:** Sensitive secrets (like Synology credentials) are assumed to be retrieved from your Vault/Bao server or a separate secure mechanism.

    ```hcl
    # Storage & Paths
    storage_pool          = "default"            # Your VMM Storage Pool name
    shared_folder_path    = "/volume1/terraform" # Path on NAS to store cloud images

    # Network Mapping (Match these to your Synology VMM Network names)
    mgmt_network_name     = "Default"            # Management/API network
    provider_network_name = "Default"            # External/Provider network
    tenant_network_name   = "Default"            # Internal/Tenant network

    # IP Configuration (First 3 octets)
    mgmt_ip_base          = "192.168.1"          # Subnet for management (e.g., 192.168.1.x)
    provider_ip_base      = "10.0.1"             # Subnet for provider network
    tenant_ip_base        = "10.0.2"             # Subnet for tenant network

    # Cluster Size
    control_count         = 3
    compute_count         = 2
    ```

3.  Initialize and Apply:
    ```bash
    terraform init
    terraform apply
    ```
    *This will download the Ubuntu Noble image to your NAS, create 5 VMs (3 control, 2 compute), and start them.*

## Step 2: Prepare for Kolla Ansible

1.  **SSH Connectivity:** Ensure your deployment host can SSH to all nodes by hostname using the key you provided in Terraform. Hostnames are static-assigned via cloud-init network config (see `terraform/nodes.tf`); add /etc/hosts entries if your DNS does not cover them.

## Step 3: Deploy OpenStack

The repo's `kolla/` directory is symlinked to `/etc/kolla` so all kolla-ansible config (globals, inventory, passwords, certificates) lives in-tree. Set up once:

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

Everything under `kolla/` is gitignored except `globals.yml` and `multinode` (allowlist in `.gitignore`), so generated state (`passwords.yml`, `certificates/`, `admin-openrc.sh`, etc.) stays local.

## Notes

*   **Synology provider fork:** `terraform/versions.tf` pins `ironashram/synology@0.7.0-ironashram`, which adds the `guest.set` hardware-config path plus `machine_type`, virtio NIC `model`, and disk `controller`/`unmap` schema. Upstream `synology-community/synology` lacks these and forces manual VMM tweaks per VM.
*   **Default size is minimal:** 1 control + 1 compute (control also runs `nova-compute`). Bump `control_count` / `compute_count` for HA.
*   **Networking:** ML2/OpenVSwitch with three NICs per node (mgmt / provider / tenant). The provider NIC is left without a host IP so Neutron can plumb it into `br-ex`.
*   **Storage:** Cinder is disabled. Compute nodes use their local disk for VM storage. Live migration is block-migration (no shared storage).
*   **Virtualization:** `nova_compute_virt_type` is set to `qemu` in `globals.yml` for compatibility. If your NAS supports nested virtualization, switch to `kvm` and enable nested mode on the host before creating the VMs (substitute `kvm_intel` on Intel hardware):

    ```bash
    modprobe -r kvm_amd
    modprobe kvm_amd nested=1
    ```

    Without this, guests run TCG-only — fine for cirros functional testing but ~10x slower than near-native.
*   **Prometheus:** Trimmed to `node` + `libvirt` exporters (cadvisor, alertmanager, openstack-exporter, etc. disabled). Sufficient for kronos-style imbalance detection; cuts containers and CPU footprint.
