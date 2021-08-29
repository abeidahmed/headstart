require "fileutils"
require "shellwords"

# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__.match?(%r{\Ahttps?://})
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("headstart-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/abeidahmed/headstart.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{headstart/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def rails_version
  @rails_version ||= Gem::Version.new(Rails::VERSION::STRING)
end

def rails_5?
  Gem::Requirement.new(">= 5.2.0", "< 6.0.0.beta1").satisfied_by? rails_version
end

def rails_6?
  Gem::Requirement.new(">= 6.0.0.alpha", "< 7").satisfied_by? rails_version
end

def rails_7?
  Gem::Requirement.new(">= 7.0.0.alpha", "< 8").satisfied_by? rails_version
end

def master?
  ARGV.include? "--master"
end

def add_gems
  if rails_7? || master?
    gem "devise", github: "ghiculescu/devise", branch: "patch-2"
  else
    gem "devise", "~> 4.8", ">= 4.8.0"
  end
  gem "devise_masquerade", "~> 1.3"
  gem "hotwire-rails"
  gem "name_of_person", "~> 1.1"
  gem "omniauth-facebook", "~> 8.0"
  gem "omniauth-github", "~> 2.0"
  gem "omniauth-twitter", "~> 1.4"
  gem "pundit", "~> 2.1"
  gem "sidekiq", "~> 6.2"
  gem "responders", github: "heartcombo/responders"

  gem_group :development do
    gem "standard"
  end

  if rails_5?
    gsub_file "Gemfile", /gem 'sqlite3'/, "gem 'sqlite3', '~> 1.3.0'"
    gem "webpacker", "~> 5.3"
  end
end

def set_application_name
  # Add Application Name to Config
  if rails_5?
    environment "config.application_name = Rails.application.class.parent_name"
  else
    environment "config.application_name = Rails.application.class.module_parent_name"
  end

  # Announce the user where they can change the application name in the future.
  puts "You can change application name inside: ./config/application.rb"
end

def add_users
  route "root to: 'home#index'"
  generate "devise:install"
  generate "devise:views"

  # Configure Devise to handle TURBO_STREAM requests like HTML requests
  inject_into_file "config/initializers/devise.rb", "  config.navigational_formats = ['/', :html, :turbo_stream]", after: "Devise.setup do |config|\n"

  inject_into_file "config/initializers/devise.rb", after: "# frozen_string_literal: true\n" do
    <<~RUBY
      class TurboFailureApp < Devise::FailureApp
        def respond
          if request_format == :turbo_stream
            redirect
          else
            super
          end
        end
        def skip_format?
          %w[html turbo_stream */*].include? request_format.to_s
        end
      end
    RUBY
  end

  inject_into_file "config/initializers/devise.rb", after: "# ==> Warden configuration\n" do
    <<-RUBY
  config.warden do |manager|
    manager.failure_app = TurboFailureApp
  end
    RUBY
  end

  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: "development"
  generate :devise, "User", "first_name", "last_name", "admin:boolean"

  # Set admin default to false
  in_root do
    migration = Dir.glob("db/migrate/*").max_by { |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end

  if Gem::Requirement.new("> 5.2").satisfied_by? rails_version
    gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"
  end

  # Add Devise masqueradable to users
  inject_into_file("app/models/user.rb", "omniauthable, :masqueradable, :", after: "devise :")
end

def add_authorization
  generate "pundit:install"
end

def add_webpack
  # Rails 6+ comes with webpacker by default, so we can skip this step
  return if rails_6?

  # Our application layout already includes the javascript_pack_tag,
  # so we don't need to inject it
  rails_command "webpacker:install"
end

def add_hotwire
  rails_command "hotwire:install"
end

def copy_templates
  copy_file "Procfile"
  copy_file "Procfile.dev"
  copy_file ".foreman"

  directory "app", force: true
  directory "config", force: true
end

def add_sidekiq
  environment "config.active_job.queue_adapter = :sidekiq"

  insert_into_file "config/routes.rb", "require 'sidekiq/web'\n\n", before: "Rails.application.routes.draw do"

  content = <<~RUBY
    authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => "/sidekiq"
    end
  RUBY

  insert_into_file "config/routes.rb", "#{content}\n", after: "Rails.application.routes.draw do\n"
end

def add_multiple_authentication
  insert_into_file "config/routes.rb", ', controllers: { omniauth_callbacks: "users/omniauth_callbacks" }', after: "  devise_for :users"

  generate "model Service user:references provider uid access_token access_token_secret refresh_token expires_at:datetime auth:text"

  content = <<~RUBY
    env_creds = Rails.application.credentials[Rails.env.to_sym] || {}
      %i[facebook twitter github].each do |provider|
        if options = env_creds[provider]
          config.omniauth provider, options[:app_id], options[:app_secret], options.fetch(:options, {})
        end
      end
  RUBY

  insert_into_file "config/initializers/devise.rb", "  #{content}\n\n", before: "  # ==> Warden configuration"
end

def stop_spring
  run "spring stop"
end

def add_javascript
  # Use specific version due to this issue https://github.com/webpack/webpack-cli/issues/2272
  run "yarn add webpack-dev-server@3.11.2 -D"

  content = <<~JS
    const webpack = require('webpack')
    environment.plugins.append(
      'Provide',
      new webpack.ProvidePlugin({
        ApplicationController: ['application_controller', 'default'],
      })
    )
  JS

  insert_into_file "config/webpack/environment.js", "#{content}\n", before: "module.exports = environment"
end

# Main setup
add_template_repository_to_source_path
add_gems

after_bundle do
  set_application_name
  stop_spring
  add_users
  add_authorization
  add_webpack
  add_multiple_authentication
  add_sidekiq
  add_hotwire
  add_javascript

  copy_templates

  rails_command "active_storage:install"

  unless ENV["SKIP_GIT"]
    git :init
    git add: "."
    # git commit will fail if user.email is not configured
    begin
      git commit: %( -m 'Initial commit' )
    rescue => e
      puts e.message
    end
  end

  say
  say "Headstart app successfully created!", :blue
  say
  say "To get started with your new app:", :green
  say "  cd #{original_app_name}"
  say
  say "  Update config/database.yml with your database credentials"
  say
  say "  rails db:create db:migrate"
  say "  gem install foreman"
  say "  run foreman start to start the server"
end
