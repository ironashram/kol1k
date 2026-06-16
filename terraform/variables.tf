variable "remote_state_s3_endpoint" {
  description = "url for s3 backend"
  default     = "s3.m1k.cloud"
}

variable "libvirt_uri" {
  type        = string
  default     = "qemu:///system"
  description = "libvirt connection URI"
}

variable "storage_pool" {
  type        = string
  default     = "default"
  description = "Name of the libvirt storage pool"
}

variable "ubuntu_image_url" {
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  description = "URL of the Ubuntu cloud image to fetch as the base volume"
}

variable "mgmt_bridge_name" {
  type        = string
  default     = "kol1kmgmt0"
  description = "Linux bridge name for the libvirt mgmt network"
}

variable "provider_bridge_name" {
  type        = string
  default     = "kol1kprov0"
  description = "Linux bridge name for the libvirt provider network"
}

variable "tenant_bridge_name" {
  type        = string
  default     = "kol1ktnt0"
  description = "Linux bridge name for the libvirt tenant network"
}

variable "mgmt_ip_base" {
  type        = string
  default     = "192.168.130"
  description = "Base IP /24 for the management network"
}

variable "tenant_ip_base" {
  type        = string
  default     = "192.168.132"
  description = "Base IP /24 for the tenant network"
}

variable "control_count" {
  type        = number
  default     = 1
  description = "Number of control nodes to create"
}

variable "compute_count" {
  type        = number
  default     = 2
  description = "Number of compute nodes to create"
}

variable "compute_memory_mb" {
  type        = number
  default     = 8192
  description = "Memory (MiB) for each compute node"
}

variable "compute_vcpu_count" {
  type        = number
  default     = 4
  description = "vCPUs for each compute node"
}

variable "control_memory_mb" {
  type        = number
  default     = 16384
  description = "Memory (MiB) for each control node"
}

variable "control_vcpu_count" {
  type        = number
  default     = 8
  description = "vCPUs for each control node"
}

variable "compute_disk_mb" {
  type        = number
  default     = 102400
  description = "Disk size (MiB) for each compute node"
}

variable "control_disk_mb" {
  type        = number
  default     = 81920
  description = "Disk size (MiB) for each control node"
}

variable "dns1" {
  type    = string
  default = "1.1.1.1"
}

variable "dns2" {
  type    = string
  default = "8.8.8.8"
}
