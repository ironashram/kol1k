provider "synology" {
  host     = ephemeral.vault_kv_secret_v2.openstack.data.synology_host
  user     = ephemeral.vault_kv_secret_v2.openstack.data.synology_user
  password = ephemeral.vault_kv_secret_v2.openstack.data.synology_password
}

provider "vault" {}


