variable "project_id" {
    description = "Google Cloud Project ID"
    type = string
}

variable "region" {
    description = "GCP region for resources"
    type = string
    default = "us-central1"
}

variable "cluster_cidr_block" {
    description = "CIDR block for k8s cluster nodes"
    type = string
    default = "10.0.0.0/14" 
}

variable "service_cidr_block" {
    description = "CIDR block for k8s services"
    type = string
    default = "10.0.0.0/20" 
}