# OpenStack on Synology NAS

This project bootstraps an OpenStack cluster on a Synology NAS using Terraform for VM provisioning and Kolla Ansible for OpenStack deployment.

## Prerequisites

```
modprobe -r kvm_amd
modprobe kvm_amd nested=1
```

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

1.  **Get IP Addresses:** Check your Synology VMM console or router to find the IP addresses assigned to the new VMs.
2.  **Update Inventory:** Edit `kolla/inventory/multinode` and replace the placeholder IPs (`192.168.1.x`) with the actual IPs.
3.  **SSH Connectivity:** Ensure you can SSH into all nodes from your deployment machine using the key you provided in Terraform:
    ```bash
    ssh ubuntu@<control-node-ip>
    ```

## Step 3: Deploy OpenStack
1.  Create Kolla virtual env
    ```bash
    sudo mkdir -p /etc/kolla
    sudo chown -R ${USER}:${USER} /etc/kolla
    python -m venv .kolla-venv
    source .kolla-venv/bin/activate
    ```

2.  Install Kolla Ansible (ensure you use a version compatible with Ubuntu 24.04, likely master or a recent release):
    ```bash
    pip install git+https://opendev.org/openstack/kolla-ansible@stable/2025.2
    kolla-ansible install-deps
    ```

3.  Copy the configuration:
    ```bash
    cp kolla/globals.yml /etc/kolla/globals.yml
    cp kolla/inventory/multinode .
    ```

4.  Generate passwords:
    ```bash
    kolla-genpwd
    ```

5.  Bootstrap and Deploy:
    ```bash
    cd /etc/kolla
    kolla-ansible bootstrap-servers -i multinode
    kolla-ansible prechecks -i multinode
    kolla-ansible deploy -i multinode
    kolla-ansible post-deploy
    ```

## Notes

*   **Storage:** Cinder is disabled. Compute nodes use their local 100GB disks for VM storage.
*   **Virtualization:** `nova_compute_virt_type` is set to `qemu` in `globals.yml` for compatibility. If your NAS supports nested virtualization, you can try changing this to `kvm`.
