resource "aws_cloudtrail" "main" {
  name                          = local.trail_name
  s3_bucket_name                = module.audit_logs.id
  kms_key_id                    = aws_kms_key.main.arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [module.audit_logs]
}

resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project}-analyzer"
  type          = "ACCOUNT"
}