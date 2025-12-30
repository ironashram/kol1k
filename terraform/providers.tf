provider "synology" {
  host     = data.vault_generic_secret.openstack.data.synology_host
  user     = data.vault_generic_secret.openstack.data.synology_user
  password = data.vault_generic_secret.openstack.data.synology_password
}

provider "vault" {}


