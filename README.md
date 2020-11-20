π-base infrastructure as code.

# Terraform

Sets up

* S3 buckets to hold prod and dev releases
* Cloudfront distributions for each, with appropriate CNAMEs
* An `announce` lambda for broadcasting messages to Slack
* A `release` lambda which subscribes for updates to the two S3 buckets,
  invalidates the corresponding Cloudfront distribution, and announces a release

To run, first supply the required secrets

```bash
$ cp secret.tfvars.example secret.tfvars
```

The existing `Terraformers` group should grant (only) the required permissions to run terraform. Set your `AWS_PROFILE`
to a user with appropriate permissions and apply:

```bash
$ export AWS_PROFILE=...
$ terraform apply -var-file=secret.tfvars
```

You may still need to manually

* repoint `topology-dev.` and `topology.` CNAMEs

# Lambdas

## Update

In the subdirectory for the lambda

```bash
$ npm run build
```

and then `terraform apply -var-file=secret.tfvars` to upload the new implementation.

## Invoke Directly

```bash
$ aws lambda invoke --function $NAME --cli-binary-format raw-in-base64-out --payload '{...}' /dev/stdout
```
