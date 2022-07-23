provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "tfsandbox-state-xyvre"
  lifecycle {
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_acl" "example_bucket_acl" {
  bucket = aws_s3_bucket.tf_state.id
  acl    = "private"
}

resource "aws_dynamodb_table" "tf_locks" {
  name = "tfs_sandbox_locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}