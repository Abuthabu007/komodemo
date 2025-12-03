module "security" {
  source             = "./modules/security"
  project_id         = var.project_id
  project_number     = var.project_number
  region             = var.region
  api_dependencies   = [for svc in google_project_service.enabled_apis : svc.service]

  depends_on = [google_project_service.enabled_apis]
}

module "identity" {
  source             = "./modules/identity"
  project_id         = var.project_id
  api_dependencies   = [for svc in google_project_service.enabled_apis : svc.service]

  depends_on = [google_project_service.enabled_apis]
}

module "storage" {
  source                      = "./modules/storage"
  project_id                  = var.project_id
  region                      = var.region
  bucket_name                 = var.bucket_name
  kms_key                     = module.security.storage_key_name
  project_number              = var.project_number
  video_processor_sa_email    = module.identity.video_processor_sa_email
  cors_origins                = var.cors_origins
}

module "cloud_run" {
  source                      = "./modules/cloudrun"
  project_id                  = var.project_id
  region                      = var.region
  service_name                = var.service_name
  image                       = var.cloud_run_image
  bucket_name                 = module.storage.bucket_name
  vpc_connector_name          = module.security.vpc_connector_id
  api_gateway_sa_email        = module.identity.api_gateway_sa_email
  storage_encryption_key      = module.security.storage_key_name

  depends_on = [google_project_service.enabled_apis, module.security, module.identity]
}

module "eventarc_trigger" {
  source                      = "./modules/eventarc"
  project_id                  = var.project_id
  project_number              = var.project_number
  region                      = var.region
  bucket_name                 = module.storage.bucket_name
  cloud_run_service           = module.cloud_run.service_name
  cloud_run_service_account   = module.cloud_run.service_account_email
  cloud_run_location          = module.cloud_run.location
  cloud_run_service_name      = module.cloud_run.service_name
  cloud_run_service_region    = module.cloud_run.location

  depends_on = [module.cloud_run, module.security]
}

module "cloud_sql" {
  source                        = "./modules/cloudsql"
  project_id                    = var.project_id
  region                        = var.region
  vpc_id                        = module.security.vpc_id
  cloud_run_sa_email            = module.cloud_run.service_account_email
  db_password                   = var.db_password
  api_dependencies              = [for svc in google_project_service.enabled_apis : svc.service]
  service_networking_connection = module.security.service_networking_connection

  depends_on = [google_project_service.enabled_apis, module.security, module.cloud_run]
}

module "vertex_ai_search" {
  source                    = "./modules/vertexai-search"
  project_id                = var.project_id
  region                    = var.region
  cloud_sql_instance_name   = module.cloud_sql.instance_name
  bucket_name               = module.storage.bucket_name
  api_dependencies          = [for svc in google_project_service.enabled_apis : svc.service]

  depends_on = [google_project_service.enabled_apis, module.cloud_sql, module.storage]
}

module "artifact_registry" {
  source              = "./modules/ArtifactRegistry"
  project_id          = var.project_id
  service_account     = module.identity.api_gateway_sa_email
}
