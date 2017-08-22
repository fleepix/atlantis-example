provider "aws" {
  region = "${var.region}"
}

resource "aws_s3_bucket" "default" {
  bucket = "terraform-state-bucket-test"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "statelock" {
  name = "terraform-lock"
  read_capacity = 20
  write_capacity = 20
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}