resource "libvirt_network" "mgmt" {
  name      = "kol1k-mgmt"
  autostart = true

  bridge = {
    name = var.mgmt_bridge_name
  }

  domain = {
    name = local.domain_name
  }

  forward = {
    mode = "nat"
  }

  ips = [{
    address = "${var.mgmt_ip_base}.1"
    prefix  = 24
    family  = "ipv4"
  }]
}

resource "libvirt_network" "provider" {
  name      = "kol1k-provider"
  autostart = true

  bridge = {
    name = var.provider_bridge_name
  }
}

resource "libvirt_network" "tenant" {
  name      = "kol1k-tenant"
  autostart = true

  bridge = {
    name = var.tenant_bridge_name
  }
}
