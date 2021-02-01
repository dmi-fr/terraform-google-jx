output "cluster_name" {
    value = module.jx_cluster.name
}

output "cluster_location" {
    value = var.zone
}

output "cluster_endpoint" {
    value = module.jx_cluster.endpoint
    sensitive = true
}

output "cluster_ca_certificate" {
    value = module.jx_cluster.ca_certificate
    sensitive = true
}

output "log_storage_url" {
    value = google_storage_bucket.log_bucket[0].url
}

output "report_storage_url" {
    value = google_storage_bucket.report_bucket[0].url
}

output "repository_storage_url" {
    value = google_storage_bucket.repository_bucket[0].url
}

output "jenkins_x_namespace" {
    value = kubernetes_namespace.jenkins_x_namespace.metadata[0].name
}
