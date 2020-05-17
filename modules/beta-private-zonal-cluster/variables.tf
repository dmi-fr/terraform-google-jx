// ----------------------------------------------------------------------------
// Required Variables
// ----------------------------------------------------------------------------
variable "gcp_project" {
  description = "The name of the GCP project"
  type = string
}

variable "region" {
    description = "GCP region, e.g. us-west3"
}

variable "zone" {
    description = "GCP zone, e.g. us-west3-a"
}

variable "master_authorized_networks" {
    description = "Input in the form [{\"cidr_block\":\"<your CIDR>\",\"display_name\":\"<your location>\"}]"
    type = list(object({
        cidr_block = string
        display_name = string
    }))
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type = string
}

variable "jenkins_x_namespace" {
  description = "Kubernetes namespace to install Jenkins X in"
  type = string
}

variable "cluster_id" {
  description = "A random generated to uniqly name cluster resources"
  type = string
}

variable "network" {
    description = "VPC network"
    type = string
}

variable "subnetwork" {
    description = "VPC subnetwork"
    type = string
}

variable "ip_range_pods" {
    description = "Pod IP range"
    type = string
}

variable "ip_range_services" {
    description = "Services IP range"
    type = string
}


// ----------------------------------------------------------------------------
// Optional Variables
// ----------------------------------------------------------------------------
// storage
variable "enable_log_storage" {
  description = "Flag to enable or disable storage of build logs in a cloud bucket"
  type        = bool
  default     = true
}

variable "enable_report_storage" {
  description = "Flag to enable or disable storage of build reports in a cloud bucket"
  type        = bool
  default     = true
}

variable "enable_repository_storage" {
  description = "Flag to enable or disable storage of artifacts in a cloud bucket"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Flag to determine whether storage buckets get forcefully destroyed"
  type        = bool
  default     = false
}

// cluster configuration
variable "node_machine_type" {
  description = "Node type foe the Kubernetes cluster"
  type = string
}

variable "min_node_count" {
  description = "Minimum number of cluster nodes"
  type        = number
  default     = 3
}

variable "max_node_count" {
  description = "Maximum number of cluster nodes"
  type        = number
  default     = 5
}

variable "resource_labels" {
  description = "Set of labels to be applied to the cluster"
  type        = map
  default     = {}
}

variable "node_preemptible" {
  description = "Use preemptible nodes"
  type        = bool
  default     = false
}

variable "node_disk_size" {
  description = "Node disk size in GB"
  type        = string
  default     = "100"
}

variable "enable_kubernetes_alpha" {
  type    = bool
  default = false
}

variable "enable_legacy_abac" {
  type    = bool
  default = true
}

variable "auto_repair" {
  type    = bool
  default = false
}

variable "auto_upgrade" {
  type    = bool
  default = false
}

variable "monitoring_service" {
  description = "The monitoring service to use. Can be monitoring.googleapis.com, monitoring.googleapis.com/kubernetes (beta) and none"
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
}

variable "logging_service" {
  description = "The logging service to use. Can be logging.googleapis.com, logging.googleapis.com/kubernetes (beta) and none"
  type        = string  
  default     = "logging.googleapis.com/kubernetes"
}

variable "node_pools" {
    description = "Node pool definitions as per https://github.com/terraform-google-modules/terraform-google-kubernetes-engine"
    type = object
    default = [
    {
      name               = "autoscale-node-pool"

      machine_type       = var.node_machine_type
      disk_size_gb       = var.node_disk_size
      min_count          = var.min_node_count
      max_count          = var.max_node_count

      auto_repair        = true
      auto_upgrade       = true
    }
  ]
}
