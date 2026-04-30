resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-noble-kol1k.qcow2"
  pool = var.storage_pool

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = var.ubuntu_image_url
    }
  }
}

resource "libvirt_volume" "control_disk" {
  count    = var.control_count
  name     = "kol1k-control-${count.index + 1}.qcow2"
  pool     = var.storage_pool
  capacity = var.control_disk_mb * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "compute_disk" {
  count    = var.compute_count
  name     = "kol1k-compute-${count.index + 1}.qcow2"
  pool     = var.storage_pool
  capacity = var.compute_disk_mb * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "control_init_iso" {
  count = var.control_count
  name  = "kol1k-control-${count.index + 1}-init.iso"
  pool  = var.storage_pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.control_init[count.index].path
    }
  }
}

resource "libvirt_volume" "compute_init_iso" {
  count = var.compute_count
  name  = "kol1k-compute-${count.index + 1}-init.iso"
  pool  = var.storage_pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.compute_init[count.index].path
    }
  }
}
