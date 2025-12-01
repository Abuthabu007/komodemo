module "storage" {
source          = "./modules/storage"
project_id      = var.project_id
region          = var.region
bucket_name     = var.bucket_name
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
}

module "cloud_run" {
  source           = "./modules/cloudrun"
  project_id       = var.project_id
  region           = var.region
  service_name     = var.service_name
  image            = var.cloud_run_image
 
   depends_on = [google_project_service.enabled_apis]  # VERY IMPORTANT
} 
