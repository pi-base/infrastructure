Receives S3 Bucket update events. If the event matches a configured distribution, invalidates the distribution and posts an announcement.

## Environment variables

* `DISTRIBUTIONS` - required, a JSON-encoded value of type `{ name: string, bucket: string, distribution: string }[]`. `bucket` here should refer to a bucket ARN.
