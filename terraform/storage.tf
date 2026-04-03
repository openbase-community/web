resource "aws_s3_bucket" "app" {
  bucket = local.bucket_name

  tags = merge(local.default_tags, { Name = local.bucket_name })
}

data "aws_iam_policy_document" "app_public_read" {
  statement {
    sid    = "CloudflareReadOnly"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]

    resources = [
      "${aws_s3_bucket.app.arn}/*",
    ]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = var.cloudflare_ipv4_cidrs
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  index_document {
    suffix = var.frontend_bucket_index_document
  }

  error_document {
    key = var.frontend_bucket_error_document
  }
}

resource "aws_s3_bucket_cors_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = local.frontend_cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_policy" "app_public_read" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.app_public_read.json
}
