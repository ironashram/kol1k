resource "libvirt_cloudinit_disk" "control_init" {
  count = var.control_count
  name  = "kol1k-control-${count.index + 1}-cloudinit"

  meta_data = <<EOF
instance-id: kol1k-control-${count.index + 1}
local-hostname: kol1k-control-${count.index + 1}
EOF

  user_data = <<EOF
#cloud-config
hostname: kol1k-control-${count.index + 1}.${local.domain_name}
users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${local.ssh_public_key}
write_files:
  - path: /etc/apt/preferences.d/no-snapd
    content: |
      Package: snapd
      Pin: release a=*
      Pin-Priority: -10
package_update: true
package_upgrade: false
packages:
  - qemu-guest-agent
runcmd:
  - DEBIAN_FRONTEND=noninteractive apt-get -y purge unattended-upgrades snapd
  - DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
  - rm -rf /root/snap /home/ubuntu/snap
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
    dhcp4: false
    dhcp6: false
    optional: true
  eth2:
    match:
      macaddress: "${local.control_tenant_macs[count.index]}"
    set-name: eth2
    addresses:
      - "${var.tenant_ip_base}.${count.index + 11}/24"
    dhcp4: false
    dhcp6: false
    optional: true
EOF
}

resource "libvirt_cloudinit_disk" "compute_init" {
  count = var.compute_count
  name  = "kol1k-compute-${count.index + 1}-cloudinit"

  meta_data = <<EOF
instance-id: kol1k-compute-${count.index + 1}
local-hostname: kol1k-compute-${count.index + 1}
EOF

  user_data = <<EOF
#cloud-config
hostname: kol1k-compute-${count.index + 1}.${local.domain_name}
users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${local.ssh_public_key}
write_files:
  - path: /etc/apt/preferences.d/no-snapd
    content: |
      Package: snapd
      Pin: release a=*
      Pin-Priority: -10
package_update: true
package_upgrade: false
packages:
  - qemu-guest-agent
runcmd:
  - DEBIAN_FRONTEND=noninteractive apt-get -y purge unattended-upgrades snapd
  - DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
  - rm -rf /root/snap /home/ubuntu/snap
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
    dhcp4: false
    dhcp6: false
    optional: true
  eth2:
    match:
      macaddress: "${local.compute_tenant_macs[count.index]}"
    set-name: eth2
    addresses:
      - "${var.tenant_ip_base}.${count.index + 21}/24"
    dhcp4: false
    dhcp6: false
    optional: true
EOF
}

resource "libvirt_domain" "control_nodes" {
  count       = var.control_count
  name        = "kol1k-control-${count.index + 1}"
  type        = "kvm"
  memory      = var.control_memory_mb
  memory_unit = "MiB"
  vcpu        = var.control_vcpu_count
  running     = true

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.control_disk[count.index].pool
            volume = libvirt_volume.control_disk[count.index].name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          type = "qcow2"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.control_init_iso[count.index].pool
            volume = libvirt_volume.control_init_iso[count.index].name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      },
    ]

    interfaces = [
      {
        type  = "network"
        model = { type = "virtio" }
        mac   = { address = local.control_mgmt_macs[count.index] }
        source = {
          network = {
            network = libvirt_network.mgmt.name
          }
        }
      },
      {
        type  = "network"
        model = { type = "virtio" }
        mac   = { address = local.control_provider_macs[count.index] }
        source = {
          network = {
            network = libvirt_network.provider.name
          }
        }
      },
      {
        type  = "network"
        model = { type = "virtio" }
        mac   = { address = local.control_tenant_macs[count.index] }
        source = {
          network = {
            network = libvirt_network.tenant.name
          }
        }
      },
    ]

    rngs = [
      {
        model   = "virtio"
        backend = { random = "/dev/urandom" }
      },
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      },
    ]
  }
}

resource "libvirt_domain" "compute_nodes" {
  count       = var.compute_count
  name        = "kol1k-compute-${count.index + 1}"
  type        = "kvm"
  memory      = var.compute_memory_mb
  memory_unit = "MiB"
  vcpu        = var.compute_vcpu_count
  running     = true

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.compute_disk[count.index].pool
            volume = libvirt_volume.compute_disk[count.index].name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          type = "qcow2"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.compute_init_iso[count.index].pool
            volume = libvirt_volume.compute_init_iso[count.index].name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      },
    ]

    interfaces = [
      {
        type  = "network"
        model = { type = "virtio" }
        mac   = { address = local.compute_mgmt_macs[count.index] }
        source = {
          network = {
            network = libvirt_network.mgmt.name
          }
        }
      },
      {
        type  = "network"
        model = { type = "virtio" }
        mac   = { address = local.compute_provider_macs[count.index] }
        source = {
          network = {
            network = libvirt_network.provider.name
          }
        }
      },
      {
        type  = "network"
        model = { type = "virtio" }
        mac   = { address = local.compute_tenant_macs[count.index] }
        source = {
          network = {
            network = libvirt_network.tenant.name
          }
        }
      },
    ]

    rngs = [
      {
        model   = "virtio"
        backend = { random = "/dev/urandom" }
      },
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      },
    ]
  }
}
