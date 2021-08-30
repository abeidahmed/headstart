# Headstart Rails Template

Sane defaults for your next project.

## Getting started

- Ruby 2.5 or higher
- bundler `gem install bundler`
- rails `gem install rails`
- Database - we recommend PostgreSQL
- Redis - for ActionCable support
- Yarn
- Foreman (optional) - `gem install foreman`

### Creating a new app

```bash
rails new myapp -d postgresql -m https://raw.githubusercontent.com/abeidahmed/headstart/main/template.rb
```

Or if you have downloaded this repo, you can reference template.rb locally:

```bash
rails new myapp -d postgresql -m template.rb
```

### Running your app

To run your app, use `foreman start`. Foreman will run `Procfile.dev` via `foreman start -f Procfile.dev` as
configured by the `.foreman` file and will launch the development
processes `rails server`, `sidekiq`, and `webpack-dev-server` processes.

You can also run them in separate terminals manually if you prefer.

### Authentication with social networks

We use the encrypted Rails Credentials for app_id and app_secrets when it comes to
omniauth authentication. Edit them as so:

```bash
EDITOR=vim rails credentials:edit
```

```yaml
secret_key_base: [your-key]
development:
  github:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
production:
  github:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
```

With the environment, the service and the app_id/app_secret. If this is done correctly,
you should see login links for the services you have added to the encrypted credentials
using `EDITOR=vim rails credentials:edit`
