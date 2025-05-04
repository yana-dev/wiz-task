#set up terraform to work with my GCP project and region via variables

terraform {
    required_providers {
        google = {
            source = "hashicorp/google"
            version = "~> 5.0"
        }
    }
}

provider "google" {
    project = var.project_id
    region = var.region
}

#GCS storage bucket for DB backups
#reqs: public read access 
#TODO validate that the backup is accessible via an external URL 
resource "google_storage_bucket" "db_backups" {
    name = "yanas_db_backups"
    location = var.region

    uniform_bucket_access_level = true #IAM policies apply at bucket lvl
    force_destroy = true #allows the bucket to be deleted even if it contains objects
}

#updates the IAM policy to grant a role to a new member, while preserving other members
resource "google_storage_bucket_iam_member" "public_access" {
    bucket = google_storage_bucket.db_backups.name
    #read-only access to objects in the bucket to all users
    role = "roles/storage.objectViewer" 
    member = "allUsers"
} 

#database VM
#reqs: VM with outdated Linux version, allow SSH inbound from the Internet, overly permissive
#DB: outdated server, allow inbound from apps in the k8s cluster, local auth
resource "google_compute_instance" "mongo_db"{
    name = "mongo_db_vm"
    machine-type = "e2-medium"
    zone = "${var.region}-a" #use variable for flexibility, append -a to specify particular avaiability zone
    #primary disc used by the VM
    boot_disk {
        initialize_params {
            image = "debian-8" #outdated Linux version, latest is 12
        }
    }
    #how the VM connects to the network
    network_interface {
        network = "default"
        access_config {} #allow SSH access from the Internet
    }

    service_account {
        email = google_service_account.high_priv_sa.email
        scopes = ["https://www.googleapis.com/auth/cloud-platform"] #provide full access to the cloud platform: VM can interact with all resources   
    }

    tags = ["db-server"] #so that firewall rule below applies only to this VM
}

#allow only k8s cluster to connect to mongoDB port 27017
resource "google_compute_firewall" "allow_k8s_to_db" {
    name = "allow-k8s-db-access"
    network = "default"

    allow {
        protocol = "tcp"
        ports = ["27017"] #MongoDB port
    }

    source_ranges = [var.cluster_cidr_block]
    target_tags = ["db-server"]
}

#create k8s cluster
#reqs: the container employes database auth (connection string format)
#built container image includes a file wizexercise.txt with content
#public access & runs with cluster-admin privileges
resource "google_container_cluster" "primary" {
    name = "web-app-cluster"
    location = var.region

    ip_allocation_policy {
        cluster_ipv4_cidr_block = var.cluster_ipv4_cidr_block #IP range for worker nodes (where the pods run)
        services_ipv4_cidr_block = var.service_cidr_block #IP range for network endpoints for pods & external access (loadbalancer etc.)
    }

    initial_node_count = 3 #default pool with 3 nodes

    node_config {
        machine_type = "e2-medium"
    }
}

