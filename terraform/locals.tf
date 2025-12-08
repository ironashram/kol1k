locals {
  control_mgmt_macs     = [for i in range(var.control_count) : format("02:00:00:01:00:%02x", i + 1)]
  control_provider_macs = [for i in range(var.control_count) : format("02:00:00:01:10:%02x", i + 1)]
  control_tenant_macs   = [for i in range(var.control_count) : format("02:00:00:01:02:%02x", i + 1)]
  compute_mgmt_macs     = [for i in range(var.compute_count) : format("02:00:00:01:11:%02x", i + 1)]
  compute_provider_macs = [for i in range(var.compute_count) : format("02:00:00:01:12:%02x", i + 1)]
  compute_tenant_macs   = [for i in range(var.compute_count) : format("02:00:00:01:20:%02x", i + 1)]
  domain_name           = data.vault_kv_secret_v2.openstack.data.domain_name
  ssh_public_key        = data.vault_kv_secret_v2.openstack.data.ssh_public_key
}
