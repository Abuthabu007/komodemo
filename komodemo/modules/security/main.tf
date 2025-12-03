# Enterprise-grade security module for the video platform

# VPC Network with custom configuration
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
  description             = "Enterprise VPC for video platform"

  # Enable flow logs for all subnets
}

# Private subnet for Cloud Run and backend services
resource "google_compute_subnetwork" "private_subnet" {
  name          = "${var.project_id}-private-subnet"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  depends_on = [google_compute_network.vpc]
}

# Cloud NAT for outbound traffic
resource "google_compute_router" "router" {
  name    = "${var.project_id}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_id}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  project                            = var.project_id

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# VPC Connector already created in GCP - importing not needed for now
# Uncomment below if you need to manage it via Terraform
# resource "google_vpc_access_connector" "connector" {
#   name          = "vpc-connector"
#   ip_cidr_range = var.vpc_connector_cidr
#   network       = google_compute_network.vpc.name
#   region        = var.region
#   project       = var.project_id
#   min_instances = 2
#   max_instances = 10
#
#   depends_on = [google_compute_network.vpc]
# }

# Cloud Armor - DDoS and WAF protection
# NOTE: Disabled due to project quota limit (0 security policies available)
# To enable: Request quota increase for SECURITY_POLICIES_PER_PROJECT at console.cloud.google.com/iam-admin/quotas
# resource "google_compute_security_policy" "cloud_armor_policy" {
#   name        = "cloud-armor-policy"
#   description = "Example Cloud Armor policy"
#
#   # Custom rule
#   rule {
#     description = "Allow traffic from specific IPs"
#     priority    = 1000
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["1.2.3.4/32", "5.6.7.8/32"]
#       }
#     }
#     action = "allow"
#   }
#
#   # Required default rule
#   rule {
#     description = "Default catch-all"
#     priority    = 2147483647
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["*"]
#       }
#     }
#     action = "deny(403)" # or "allow"
#   }
# }

# Cloud KMS Keyring for encryption
resource "google_kms_key_ring" "keyring" {
  name       = "${var.project_id}-keyring"
  location   = var.region
  project    = var.project_id
}

# KMS Key for Cloud Storage encryption
resource "google_kms_crypto_key" "storage_key" {
  name            = "${var.project_id}-storage-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = "7776000s"
}

# KMS Key for database encryption
resource "google_kms_crypto_key" "database_key" {
  name            = "${var.project_id}-database-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = "7776000s"
}

# Note: Cloud Storage service account is auto-created when bucket encryption is configured
# The service account 'service-[PROJECT_NUMBER]@gcp-sa-cloud-storage.iam.gserviceaccount.com' 
# gets KMS permissions automatically through the bucket encryption process

# Secret Manager for API keys and credentials
resource "google_secret_manager_secret" "api_keys" {
  secret_id = "${var.project_id}-api-keys"
  project   = var.project_id

  replication {
    auto {}
  }
}

# Secret version placeholder
resource "google_secret_manager_secret_version" "api_keys_version" {
  secret      = google_secret_manager_secret.api_keys.id
  secret_data = "placeholder"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Cloud Logging sink for audit logs - using Cloud Logging bucket in same project
resource "google_logging_project_sink" "audit_sink" {
  name        = "${var.project_id}-audit-sink"
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/_Default"
  project     = var.project_id
  filter      = "resource.type=\"api\" OR resource.type=\"cloud_run_revision\" AND severity >= \"WARNING\""
}

# Firewall rules - deny all by default
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "${var.project_id}-deny-all-ingress"
  network   = google_compute_network.vpc.name
  project   = var.project_id
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow Cloud Run health checks
resource "google_compute_firewall" "allow_health_checks" {
  name      = "${var.project_id}-allow-health-checks"
  network   = google_compute_network.vpc.name
  project   = var.project_id
  direction = "INGRESS"
  priority  = 100

  allow {
    protocol = "tcp"
    ports    = ["8080", "8443"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["health-check"]
}

# Reserved IP range for Service Networking (Cloud SQL private IP)
resource "google_compute_global_address" "service_networking" {
  name          = "${var.project_id}-service-networking"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# VPC peering connection for Service Networking (Cloud SQL)
resource "google_service_networking_connection" "cloud_sql_peering" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.service_networking.name]

  depends_on = [google_compute_global_address.service_networking]
}

# Identity-Aware Proxy (IAP) Configuration
# Enable OAuth 2.0 consent screen and brand configuration for IAP

# Get current project
data "google_project" "current" {
  project_id = var.project_id
}

# IAP brand for OAuth consent
resource "google_iap_brand" "project_brand" {
  support_email     = var.admin_email != "" ? var.admin_email : "admin@${var.project_id}.iam.gserviceaccount.com"
  application_title = "Komo Video Platform - IAP"
  project           = var.project_id
}

# OAuth2 Client for IAP
resource "google_iap_client" "project_client" {
  display_name = "Cloud Run IAP Client"
  brand        = google_iap_brand.project_brand.name
}
