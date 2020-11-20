variable bucket_name {
  description = "Name of the S3 bucket"
  type        = string
}

variable aliases {
  description = "CNAMEs to associate with the distribution"
}

variable acm_certificate_arn {
  description = "ARN of ACM certificate associated with the given aliases"
}

