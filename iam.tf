resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  password_reuse_prevention      = 24
  max_password_age               = 90
  allow_users_to_change_password = true
}

# Only principals in this account WITH MFA can assume these roles
data "aws_iam_policy_document" "assume_with_mfa" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

# Role 1: app role limited to ONE bucket and ONE key
data "aws_iam_policy_document" "app_access" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [module.app_data.arn]
  }
  statement {
    sid       = "ObjectRW"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${module.app_data.arn}/*"]
  }
  statement {
    sid       = "UseKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_role" "app" {
  name                 = "${var.project}-app-role"
  assume_role_policy   = data.aws_iam_policy_document.assume_with_mfa.json
  max_session_duration = 3600
}

resource "aws_iam_policy" "app" {
  name   = "${var.project}-app-s3-access"
  policy = data.aws_iam_policy_document.app_access.json
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app.arn
}

# Role 2: read-only security auditor
resource "aws_iam_role" "auditor" {
  name                 = "${var.project}-auditor-role"
  assume_role_policy   = data.aws_iam_policy_document.assume_with_mfa.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "auditor" {
  role       = aws_iam_role.auditor.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}