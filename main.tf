data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  prefix      = "${var.project}-${local.account_id}"
  trail_name  = "${var.project}-trail"
  trail_arn   = "arn:aws:cloudtrail:${var.region}:${local.account_id}:trail/${local.trail_name}"
  logs_bucket = "${local.prefix}-audit-logs"
  data_bucket = "${local.prefix}-app-data"
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "EnableAccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }
  statement {
    sid       = "AllowCloudTrailEncrypt"
    actions   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
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
}

resource "aws_kms_key" "main" {
  description             = "CMK for audit logs and app data"
  enable_key_rotation     = true
  deletion_window_in_days = 7 # the minimum allowed
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-main"
  target_key_id = aws_kms_key.main.key_id
}