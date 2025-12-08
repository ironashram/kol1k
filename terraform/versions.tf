terraform {
  required_providers {
    synology = {
      source  = "synology-community/synology"
      version = "0.6.4"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}
