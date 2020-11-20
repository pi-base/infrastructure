terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }

  backend "s3" {
    region = "us-east-2"
    bucket = "pi-base-tfstate"
    key    = "tfstate"
  }
}

provider "aws" {
  profile = "pi-base-tf"
  region  = "us-east-2"
}

variable "slack_token" {
  description = "Token to use for announcing updates to Slack"
}

variable "acm_certificate_arn" {}

locals {
  lambda_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

////////////////////////////////////////////////////////////////////////////////
///////////// Set up S3 buckets & associated cloudfront deploys ////////////////
////////////////////////////////////////////////////////////////////////////////

module "distribution_dev" {
  source = "./modules/distribution"

  bucket_name         = "pi-base-viewer-dev"
  aliases             = ["topology-dev.pi-base.org"]
  acm_certificate_arn = var.acm_certificate_arn
}

module "distribution_prod" {
  source = "./modules/distribution"

  bucket_name         = "pi-base-viewer-prod"
  aliases             = ["topology-prod.pi-base.org"]
  acm_certificate_arn = var.acm_certificate_arn
}

////////////////////////////////////////////////////////////////////////////////
///////////// Trigger release on uploads to S3 buckets /////////////////////////
////////////////////////////////////////////////////////////////////////////////

data "aws_iam_policy_document" "release_lambda_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.announce.arn]
  }
}

resource "aws_iam_role" "release-lambda" {
  name               = "release-lambda"
  assume_role_policy = local.lambda_role_policy
}

resource "aws_lambda_permission" "allow_bucket_dev" {
  statement_id  = "AllowExecutionFromDevS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.release.arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.distribution_dev.bucket.arn
}

resource "aws_lambda_permission" "allow_bucket_prod" {
  statement_id  = "AllowExecutionFromProdS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.release.arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.distribution_prod.bucket.arn
}

resource "aws_lambda_function" "release" {
  function_name = "release"
  runtime       = "nodejs12.x"
  role          = aws_iam_role.release-lambda.arn
  handler       = "index.handler"

  filename         = "lambdas/release/dst/release.zip"
  source_code_hash = filebase64sha256("lambdas/release/dst/release.zip")

  environment {
    variables = {
      DISTRIBUTIONS = jsonencode([
        {
          name : "dev",
          bucket : module.distribution_dev.bucket.arn,
          distributionId : module.distribution_dev.distribution.id
        },
        {
          name : "prod",
          bucket : module.distribution_prod.bucket.arn,
          distributionId : module.distribution_prod.distribution.id
        }
      ])
    }
  }
}

resource "aws_s3_bucket_notification" "dev_upload" {
  bucket = "pi-base-viewer-dev"

  lambda_function {
    lambda_function_arn = aws_lambda_function.release.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = "bundle.js"
  }
}

////////////////////////////////////////////////////////////////////////////////
///////////// Send notifications to Slack //////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role" "announce-lambda" {
  name               = "announce-lambda"
  assume_role_policy = local.lambda_role_policy
}

resource "aws_lambda_function" "announce" {
  function_name = "announce"
  runtime       = "nodejs12.x"
  role          = aws_iam_role.announce-lambda.arn
  handler       = "index.handler"

  filename         = "lambdas/announce/dst/announce.zip"
  source_code_hash = filebase64sha256("lambdas/announce/dst/announce.zip")

  environment {
    variables = {
      SLACK_TOKEN   = var.slack_token
      INFO_CHANNEL  = "activity"
      DEBUG_CHANNEL = "bots"
    }
  }
}

resource "aws_iam_policy" "allow_announce" {
  name        = "allow-announce"
  description = "Allow calling the announce lambda"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : ["lambda:InvokeFunction"],
        "Effect" : "Allow",
        "Resource" : [aws_lambda_function.announce.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "allow_release_announce" {
  role       = aws_iam_role.release-lambda.name
  policy_arn = aws_iam_policy.allow_announce.arn
}
