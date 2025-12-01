output "bucket_name" { value = module.storage.bucket_name }
output "cloud_run_url" { value = module.cloud_run.service_url }
output "eventarc_trigger_name" { value = module.eventarc_trigger.trigger_name } 