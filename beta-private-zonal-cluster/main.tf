// ----------------------------------------------------------------------------
// Enforce Terraform version
//
// Using pessemistic version locking for all versions 
// ----------------------------------------------------------------------------
terraform {
  required_version = ">= 0.12.0"
}

// ----------------------------------------------------------------------------
// Configure providers
// ----------------------------------------------------------------------------
provider "google" {
  project = var.gcp_project
  zone    = var.zone
}

provider "google-beta" {
  project = var.gcp_project
  zone    = var.zone
}

provider "random" {}

provider "local" {}

provider "null" {}

provider "template" {}

data "google_client_config" "default" {}

provider "kubernetes" {
  # no longer supported by provider
  #load_config_file = false

  host  = "https://${module.cluster.cluster_endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    module.cluster.cluster_ca_certificate,
  )
}

resource "random_id" "random" {
  byte_length = 6
}

resource "random_pet" "current" {
  prefix    = "tf-jx"
  separator = "-"
  keepers = {
    # Keep the name consistent on executions
    cluster_name = var.cluster_name
  }
}

locals {
  cluster_name = var.cluster_name != "" ? var.cluster_name : random_pet.current.id
}

// ----------------------------------------------------------------------------
// Enable all required GCloud APIs
//
// https://www.terraform.io/docs/providers/google/r/google_project_service.html
// ----------------------------------------------------------------------------
resource "google_project_service" "cloudresourcemanager_api" {
  provider           = google
  project            = var.gcp_project
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  provider           = google
  project            = var.gcp_project
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
  provider           = google
  project            = var.gcp_project
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild_api" {
  provider           = google
  project            = var.gcp_project
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "containerregistry_api" {
  provider           = google
  project            = var.gcp_project
  service            = "containerregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "containeranalysis_api" {
  provider           = google
  project            = var.gcp_project
  service            = "containeranalysis.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "serviceusage_api" {
  provider           = google
  project            = var.gcp_project
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

// ----------------------------------------------------------------------------
// Create Kubernetes cluster
// ----------------------------------------------------------------------------
module "cluster" {
  source = "../modules/beta-private-zonal-cluster"

  gcp_project         = var.gcp_project
  zone                = var.zone
  cluster_name        = local.cluster_name
  cluster_id          = random_id.random.hex
  jenkins_x_namespace = var.jenkins_x_namespace
  force_destroy       = var.force_destroy

  node_machine_type = var.node_machine_type
  node_disk_size    = var.node_disk_size
  min_node_count    = var.min_node_count
  max_node_count    = var.max_node_count
  resource_labels   = var.resource_labels

  region              = var.region
  network                = var.network
  subnetwork             = var.subnetwork
  ip_range_pods          = var.ip_range_pods
  ip_range_services      = var.ip_range_services
  master_authorized_networks = var.master_authorized_networks
  master_global_access_enabled  = var.master_global_access_enabled
  node_pools                = var.node_pools
  node_pools_taints         = var.node_pools_taints
  node_pools_labels         = var.node_pools_labels
  kubernetes_version        = var.kubernetes_version

  network_policy = var.network_policy
}

// ----------------------------------------------------------------------------
// Setup all required resources for using the  bank-vaults operator
// See https://github.com/banzaicloud/bank-vaults
// ----------------------------------------------------------------------------
module "vault" {
  source = "./modules/vault"

  gcp_project         = var.gcp_project
  zone                = var.zone
  cluster_name        = local.cluster_name
  cluster_id          = random_id.random.hex
  jenkins_x_namespace = module.cluster.jenkins_x_namespace
  force_destroy       = var.force_destroy
}

// ----------------------------------------------------------------------------
// Setup all required resources for using Velero for cluster backups
// ----------------------------------------------------------------------------
module "backup" {
  source = "./modules/backup"

  gcp_project         = var.gcp_project
  zone                = var.zone
  cluster_name        = local.cluster_name
  cluster_id          = random_id.random.hex
  jenkins_x_namespace = module.cluster.jenkins_x_namespace
  force_destroy       = var.force_destroy
}

// ----------------------------------------------------------------------------
// Setup ExternalDNS
// ----------------------------------------------------------------------------
module "dns" {
  source = "./modules/dns"

  gcp_project         = var.gcp_project
  cluster_name        = local.cluster_name
  parent_domain       = var.parent_domain
  jenkins_x_namespace = module.cluster.jenkins_x_namespace
}

// ----------------------------------------------------------------------------
// Let's generate jx-requirements.yml 
// ----------------------------------------------------------------------------
resource "local_file" "jx-requirements" {
  content = templatefile("${path.module}/modules/jx-requirements.yml.tpl", {
    gcp_project                 = var.gcp_project
    zone                        = var.zone
    cluster_name                = local.cluster_name
    git_owner_requirement_repos = var.git_owner_requirement_repos
    dev_env_approvers           = var.dev_env_approvers
    lets_encrypt_production     = var.lets_encrypt_production
    // Storage buckets
    log_storage_url        = module.cluster.log_storage_url
    report_storage_url     = module.cluster.report_storage_url
    repository_storage_url = module.cluster.repository_storage_url
    backup_bucket_url      = module.backup.backup_bucket_url
    // Vault
    vault_bucket  = module.vault.vault_bucket_name
    vault_key     = module.vault.vault_key
    vault_keyring = module.vault.vault_keyring
    vault_name    = module.vault.vault_name
    vault_sa      = module.vault.vault_sa
    // Velero
    velero_sa        = module.backup.velero_sa
    velero_namespace = module.backup.backup_bucket_url != "" ? var.velero_namespace : ""
    velero_schedule  = var.velero_schedule
    velero_ttl       = var.velero_ttl
    // DNS
    domain_enabled = var.parent_domain != "" ? true : false
    parent_domain  = var.parent_domain
    tls_email      = var.tls_email

    version_stream_ref = var.version_stream_ref
    version_stream_url = var.version_stream_url
    webhook            = var.webhook
    environments       = var.environments
  })
  filename = "${path.cwd}/jx-requirements.yml"
}

// ----------------------------------------------------------------------------
// Create Cloud Armor Security Policy
// Will be attached to nginx-ingress LB
// Policy only allows traffic from Cloudfront
// toggled by `deny_external_traffic` variable
// ----------------------------------------------------------------------------
resource "google_compute_security_policy" "cloudflare_policy" {
  count = var.deny_external_traffic ? 1 : 0

  name = "deny-external-to-${var.cluster_name}"

  rule {
    action   = "allow"
    preview  = false
    priority = "750"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sourceiplist-cloudflare')"
      }
    }
  }

  rule {
    action   = "deny(403)"
    preview  = false
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, higher priority overrides it"
  }
}