module "jx_cluster" {
  source                 = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  name                   = var.cluster_name
  project_id             = var.gcp_project
  regional               = false
  region                 = var.region
  zones                  = [var.zone]
  network                = var.network
  subnetwork             = var.subnetwork
  ip_range_pods          = var.ip_range_pods
  ip_range_services      = var.ip_range_services
  create_service_account = false
  enable_private_endpoint = false
  enable_private_nodes    = true
  master_ipv4_cidr_block  = "172.16.0.0/28"
  master_authorized_networks = var.master_authorized_networks
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  identity_namespace = "${var.gcp_project}.svc.id.goog"
  maintenance_start_time = "03:00"

  node_metadata = "GKE_METADATA_SERVER"

  node_pools = [
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

  node_pools_oauth_scopes = {
    all = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/devstorage.full_control",
        "https://www.googleapis.com/auth/service.management",
        "https://www.googleapis.com/auth/servicecontrol",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring"
    ]
  }
}

// ----------------------------------------------------------------------------
// Add main Jenkins X Kubernetes namespace
// 
// https://www.terraform.io/docs/providers/kubernetes/r/namespace.html
// ----------------------------------------------------------------------------
resource "kubernetes_namespace" "jenkins_x_namespace" {
  metadata {
    name = var.jenkins_x_namespace
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }

  depends_on = [
    module.jx_cluster
  ]
}