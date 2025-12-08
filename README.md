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

2.  Create a `terraform.tfvars` file to store your secrets (DO NOT COMMIT THIS FILE):
    ```hcl
    synology_host     = "https://192.168.1.100:5001"
    synology_user     = "admin_user"
    synology_password = "your_secure_password"
    ssh_public_key    = "ssh-rsa AAAAB3..."
    storage_pool      = "default" # Check your VMM storage name
    network_name      = "Default" # Check your VMM network name
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
