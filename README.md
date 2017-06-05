# Mullog [![CircleCI](https://circleci.com/gh/zachlatta/mullog.svg?style=svg)](https://circleci.com/gh/zachlatta/mullog)

Mullog is a personal wiki powered by [Gollum](https://github.com/gollum/gollum).

Mullog takes the default Gollum server and...

- Throws it behind Puma
- Hooks it up with a git repo of your choosing (including pushing & pulling changes from given repo)
- Puts it all behind HTTP authentication

If you're looking for a personal deployment of Gollum to manage your life, Mullog is probably what you're looking for.

## Setup

Set the following environment variables:

- `GIT_URL` - HTTP(S) URL to your chosen git repo (must be HTTP(S), SSH and others are untested and may not work)
- `GIT_USERNAME` - username to authenticate to `GIT_URL` with
- `GIT_PASSWORD` - password to authenticate to `GIT_URL` with (I recommend using a [personal access token](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/))
- `GIT_AUTHOR_NAME` - name to add to git commits (ex. "Zach Latta")
- `GIT_AUTHOR_EMAIL` - email to add to git commits (ex. "zach@zachlatta.com")
- `HTTP_USERNAME` - username to allow HTTP login with
- `HTTP_PASSWORD` - password to allow HTTP login with
- `RACK_ENV` - can either be "production" or "development", your call

And then deploy it the same way you deploy any other Rack app!

## What the heck is a Mullog?

```ruby
"gollum".reverse
```

## License

Mullog is made available under the MIT license. See [`LICENSE`](LICENSE) for full details.
