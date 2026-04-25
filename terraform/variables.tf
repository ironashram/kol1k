variable "remote_state_s3_endpoint" {
  description = "url for s3 backend"
}

variable "storage_pool" {
  type        = string
  default     = "k8storage"
  description = "Name of the storage pool in Synology VMM"
}

variable "mgmt_network_name" {
  type        = string
  default     = "openstack-mgmt"
  description = "Name of the management network in Synology VMM"
}

variable "provider_network_name" {
  type        = string
  default     = "openstack-provider"
  description = "Name of the provider network to attach VMs to"
}

variable "tenant_network_name" {
  type        = string
  default     = "openstack-tenant"
  description = "Name of the tenant/internal network to attach VMs to"
}

variable "shared_folder_path" {
  type        = string
  default     = "/NAS/terraform"
  description = "Path to the shared folder on Synology NAS for images"
}

variable "mgmt_ip_base" {
  type        = string
  default     = "10.128.0"
  description = "Base IP for management network (e.g., 192.168.100)"
}

variable "provider_ip_base" {
  type        = string
  default     = "10.178.0"
  description = "Base IP for provider network (e.g., 10.0.0)"
}

variable "tenant_ip_base" {
  type        = string
  default     = "10.228.0"
  description = "Base IP for tenant/internal network (e.g., 172.16.0)"
}

variable "control_count" {
  type        = number
  default     = 1
  description = "Number of control nodes to create"
}

variable "compute_count" {
  type        = number
  default     = 1
  description = "Number of compute nodes to create"
}

variable "compute_memory_mb" {
  type        = number
  default     = 4096
  description = "Amount of memory (in MB) for each compute node"
}

variable "compute_vcpu_count" {
  type        = number
  default     = 2
  description = "Number of vCPUs for each compute node"
}

variable "control_memory_mb" {
  type        = number
  default     = 10240
  description = "Amount of memory (in MB) for each control node"
}

variable "control_vcpu_count" {
  type        = number
  default     = 4
  description = "Number of vCPUs for each control node"
}

variable "compute_disk_mb" {
  type        = number
  default     = 102400
  description = "Disk size (in MB) for each compute node"
}

variable "control_disk_mb" {
  type        = number
  default     = 81920
  description = "Disk size (in MB) for each control node"
}

variable "dns1" {
  type    = string
  default = "1.1.1.1"
}

variable "dns2" {
  type    = string
  default = "8.8.8.8"
}
