ephemeral "vault_kv_secret_v2" "openstack" {
  mount = "kv"
  name  = "openstack"
}

data "vault_kv_secret_v2" "openstack" {
  mount = "kv"
  name  = "openstack"
}
