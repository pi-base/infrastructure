import * as aws from 'aws-sdk'
import type { Context, S3Event } from 'aws-lambda'

aws.config.region = 'us-east-2'

const lambda = new aws.Lambda()
const cloudfront = new aws.CloudFront()

type Environment = {
  name: string
  bucket: string
  distributionId: string
}

type Bucket = { name: string, arn: string }
type TraceEvent = { test?: boolean, bucket?: Bucket }
type Event = S3Event & TraceEvent

const environments: Environment[] = JSON.parse(process.env.DISTRIBUTIONS || '[]')

exports.handler = async (event: Event, context: Context) => {
  try {
    return await handle(event, context)
  } catch (error) {
    await info("Error handling event\n```" + JSON.stringify({ error, event }, null, 2) + "```")
    throw error
  }
}

async function handle(event: Event, context: Context) {
  const bucket = findBucket(event)
  const env = bucket && findEnv(bucket)

  if (!env) {
    await debug("Could not find bucket corresponding to event\n```" + JSON.stringify(event, null, 2) + "```")
    return
  }

  await debug(`Invalidating existing \`distributionId=${env.distributionId}\``)

  if (!event.test) {
    await invalidate(env, context)
  }

  let message = `Deployed \`env=${env.name}\``
  if (bucket) {
    message += ` via push to \`bucket=${bucket.name}\``
  }
  return info(message)
}

function findBucket(event: Event): Bucket | undefined {
  if (event.Records && event.Records[0] && event.Records[0].s3.bucket) {
    return event.Records[0].s3.bucket
  } else if (event.bucket) {
    return event.bucket
  }
}

function findEnv(bucket: { arn: string }) {
  return environments.find(env => env.bucket === bucket?.arn)
}

function invalidate(env: Environment, ctx: Context) {
  return promisify(cloudfront, 'createInvalidation')({
    DistributionId: env.distributionId,
    InvalidationBatch: {
      CallerReference: ctx.awsRequestId,
      Paths: {
        Quantity: 1,
        Items: ['/*']
      }
    }
  })
}

function info(message: string) {
  return report('info', message)
}

function debug(message: string) {
  return report('debug', message)
}

function report(level: string, message: unknown) {
  return promisify(lambda, 'invoke')({
    FunctionName: 'announce',
    InvocationType: 'RequestResponse',
    LogType: 'None',
    Payload: JSON.stringify({ level, message })
  })
}

function promisify(obj: any, method: string) {
  const f = obj[method]
  return (...args: any[]) => new Promise((resolve, reject) => {
    const cb = (error: any, data: any) => error ? reject(error) : resolve(data)

    f.apply(obj, [...args, cb])
  })
}
