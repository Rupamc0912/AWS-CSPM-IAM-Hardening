resource "aws_s3_bucket" "bad" {
  bucket = "cspm-demo-insecure-${local.account_id}"
}

resource "aws_s3_bucket_acl" "bad" {
  bucket = aws_s3_bucket.bad.id
  acl    = "public-read"
}

resource "aws_iam_policy" "bad" {
  name = "admin-everything"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_security_group" "bad" {
  name        = "open-ssh"
  description = "SSH open to the world"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}