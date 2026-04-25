terraform {
  required_providers {
    synology = {
      source  = "ironashram/synology"
      version = "0.7.0-ironashram"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}
