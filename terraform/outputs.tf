#public IP of my mongo DB instance
output "db_vm_ip" {
    value = google_compute_instance.mongo_db.network_interface[0].access_config[0].nat_ip
}

#name of my GCS bucket that stores logs
output "bucket_name" {
    value = google_storage_bucket.db_backups.name
}
