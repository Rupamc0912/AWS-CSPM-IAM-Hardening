# Account-wide guardrail: no bucket in this account can be made public
resource "aws_s3_account_public_access_block" "account" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "cloudtrail_write" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.logs_bucket}"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
  statement {
    sid       = "AWSCloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.logs_bucket}/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

module "audit_logs" {
  source                  = "./modules/secure_bucket"
  bucket_name             = local.logs_bucket
  kms_key_arn             = aws_kms_key.main.arn
  additional_policy_jsons = [data.aws_iam_policy_document.cloudtrail_write.json]
}

module "app_data" {
  source      = "./modules/secure_bucket"
  bucket_name = local.data_bucket
  kms_key_arn = aws_kms_key.main.arn
}