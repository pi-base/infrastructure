import * as https from 'https'

const token = process.env.SLACK_TOKEN

const errorChannel = process.env.INFO_CHANNEL || 'errors'
const infoChannel = process.env.INFO_CHANNEL || 'activity'
const debugChannel = process.env.DEBUG_CHANNEL || 'bots'

type Event = {
  level?: 'error' | 'info' | 'debug'
  message?: string
}

exports.handler = async (event: Event) => {
  return request('POST', 'chat.postMessage', {
    icon_emoji: ':female-scientist:',
    channel: findChannel(event.level),
    text: event.message,
  })
}

function findChannel(level: string | undefined) {
  switch (level) {
    case 'error':
      return errorChannel
    case 'info':
      return infoChannel
    default:
      return debugChannel
  }
}

function request(verb: string, action: string, body: Record<string, unknown>) {
  let data = ''

  return new Promise((resolve, reject) => {
    const options = {
      method: verb,
      headers: {
        'Content-type': 'application/json',
        'Authorization': `Bearer ${token}`
      }
    }

    const req = https.request(`https://slack.com/api/${action}`, options, (res) => {
      res.on('data', chunk => data += chunk)

      res.on('error', reject)

      res.on('end', () => {
        try {
          resolve(JSON.parse(data))
        } catch (e) {
          reject(e)
        }
      })
    })

    req.write(JSON.stringify(body))
    req.end()
  })
}
