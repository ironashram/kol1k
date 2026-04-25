resource "synology_filestation_file" "ubuntu_image" {
  path           = "${var.shared_folder_path}/ubuntu-24.04-server-cloudimg-amd64.img"
  url            = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  create_parents = true
}

resource "synology_virtualization_image" "ubuntu_noble" {
  name         = "ubuntu-noble-cloud-kol1k"
  path         = synology_filestation_file.ubuntu_image.path
  storage_name = var.storage_pool
  image_type   = "disk"
  depends_on   = [synology_filestation_file.ubuntu_image]
}

resource "synology_filestation_cloud_init" "control_init" {
  count          = var.control_count
  path           = "${var.shared_folder_path}/kol1k-control-${count.index + 1}-init.iso"
  create_parents = true
  overwrite      = true
  user_data      = <<EOF
#cloud-config
hostname: kol1k-control-${count.index + 1}.${local.domain_name}
users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${local.ssh_public_key}
package_update: true
packages:
  - qemu-guest-agent
runcmd:
  - systemctl start qemu-guest-agent
EOF
  network_config = <<EOF
version: 2
ethernets:
  eth0:
    match:
      macaddress: "${local.control_mgmt_macs[count.index]}"
    set-name: eth0
    addresses:
      - "${var.mgmt_ip_base}.${count.index + 11}/24"
    gateway4: "${var.mgmt_ip_base}.1"
    nameservers:
      addresses:
        - ${var.dns1}
        - ${var.dns2}
    dhcp4: false
    dhcp6: false
  eth1:
    match:
      macaddress: "${local.control_provider_macs[count.index]}"
    set-name: eth1
    addresses:
      - "${var.provider_ip_base}.${count.index + 11}/24"
    dhcp4: false
    dhcp6: false
  eth2:
    match:
      macaddress: "${local.control_tenant_macs[count.index]}"
    set-name: eth2
    addresses:
      - "${var.tenant_ip_base}.${count.index + 11}/24"
    dhcp4: false
    dhcp6: false
EOF
}

resource "synology_virtualization_image" "control_init_img" {
  count        = var.control_count
  name         = "kol1k-control-${count.index + 1}-init"
  path         = synology_filestation_cloud_init.control_init[count.index].path
  storage_name = var.storage_pool
  image_type   = "iso"
  depends_on   = [synology_filestation_cloud_init.control_init]
}

resource "synology_virtualization_guest" "control_nodes" {
  count        = var.control_count
  name         = "kol1k-control-${count.index + 1}"
  storage_name = var.storage_pool
  vcpu_num     = var.control_vcpu_count
  vram_size    = var.control_memory_mb
  machine_type = "q35"

  network {
    name  = var.mgmt_network_name
    mac   = local.control_mgmt_macs[count.index]
    model = 1
  }

  network {
    name  = var.provider_network_name
    mac   = local.control_provider_macs[count.index]
    model = 1
  }

  network {
    name  = var.tenant_network_name
    mac   = local.control_tenant_macs[count.index]
    model = 1
  }

  disk {
    image_id   = synology_virtualization_image.ubuntu_noble.id
    size       = var.control_disk_mb
    controller = 64
    unmap      = true
  }

  iso {
    image_id = synology_virtualization_image.control_init_img[count.index].id
    boot     = false
  }

  run = false
}

resource "synology_filestation_cloud_init" "compute_init" {
  count          = var.compute_count
  path           = "${var.shared_folder_path}/kol1k-compute-${count.index + 1}-init.iso"
  create_parents = true
  overwrite      = true
  user_data      = <<EOF
#cloud-config
hostname: kol1k-compute-${count.index + 1}.${local.domain_name}
users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${local.ssh_public_key}
package_update: true
packages:
  - qemu-guest-agent
runcmd:
  - systemctl start qemu-guest-agent
EOF
  network_config = <<EOF
version: 2
ethernets:
  eth0:
    match:
      macaddress: "${local.compute_mgmt_macs[count.index]}"
    set-name: eth0
    addresses:
      - "${var.mgmt_ip_base}.${count.index + 21}/24"
    gateway4: "${var.mgmt_ip_base}.1"
    nameservers:
      addresses:
        - ${var.dns1}
        - ${var.dns2}
    dhcp4: false
    dhcp6: false
  eth1:
    match:
      macaddress: "${local.compute_provider_macs[count.index]}"
    set-name: eth1
    addresses:
      - "${var.provider_ip_base}.${count.index + 21}/24"
    dhcp4: false
    dhcp6: false
  eth2:
    match:
      macaddress: "${local.compute_tenant_macs[count.index]}"
    set-name: eth2
    addresses:
      - "${var.tenant_ip_base}.${count.index + 21}/24"
    dhcp4: false
    dhcp6: false
EOF
}

resource "synology_virtualization_image" "compute_init_img" {
  count        = var.compute_count
  name         = "kol1k-compute-${count.index + 1}-init"
  path         = synology_filestation_cloud_init.compute_init[count.index].path
  storage_name = var.storage_pool
  image_type   = "iso"
  depends_on   = [synology_filestation_cloud_init.compute_init]
}

resource "synology_virtualization_guest" "compute_nodes" {
  count        = var.compute_count
  name         = "kol1k-compute-${count.index + 1}"
  storage_name = var.storage_pool
  vcpu_num     = var.compute_vcpu_count
  vram_size    = var.compute_memory_mb
  machine_type = "q35"

  network {
    name  = var.mgmt_network_name
    mac   = local.compute_mgmt_macs[count.index]
    model = 1
  }

  network {
    name  = var.provider_network_name
    mac   = local.compute_provider_macs[count.index]
    model = 1
  }

  network {
    name  = var.tenant_network_name
    mac   = local.compute_tenant_macs[count.index]
    model = 1
  }

  disk {
    image_id   = synology_virtualization_image.ubuntu_noble.id
    size       = var.compute_disk_mb
    controller = 64
    unmap      = true
  }

  iso {
    image_id = synology_virtualization_image.compute_init_img[count.index].id
    boot     = false
  }

  run = false
}
