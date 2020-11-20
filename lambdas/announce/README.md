Receives events of type

```
{
  level?: 'error' | 'info' | 'debug' = 'debug'
  message: string
}
```

and posts the message to the corresponding channel.

## Environment variables

* `SLACK_TOKEN` - required, token used to post to Slack
* `ERROR_CHANNEL` - optional, channel to post `error` messages to
* `INFO_CHANNEL` - optional, channel to post `info` messages to
* `DEBUG_CHANNEL` - optional, channel to post `debug` messages to