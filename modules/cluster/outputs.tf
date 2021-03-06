output "cluster_name" {
    value = google_container_cluster.jx_cluster.name
}

output "cluster_location" {
    value = google_container_cluster.jx_cluster.location
}

output "cluster_endpoint" {
    value = google_container_cluster.jx_cluster.endpoint
    sensitive = true
}

output "cluster_ca_certificate" {
    value = google_container_cluster.jx_cluster.master_auth[0].cluster_ca_certificate
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
