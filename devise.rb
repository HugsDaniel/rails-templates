run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY

    # Ruby < 3.0 included rexml by default, but now
    # it's a separate gem that is required for running tests
    gem "rexml"

    # Brakeman analyzes our code for security vulnerabilities
    gem "brakeman"
    # bundler-audit checks our dependencies for vulnerabilities
    gem "bundler-audit"

    # lograge changes Rails' logging to a more
    # traditional one-line-per-event format
    gem "lograge"

    # Authentication
    gem "devise"

    # Better forms
    gem "simple_form", github: "heartcombo/simple_form"

  RUBY
end

inject_into_file "Gemfile", after: 'gem "debug", platforms: %i[ mri windows ]' do
  <<~RUBY

    gem "dotenv-rails"
    gem "standard"
  RUBY
end

inject_into_file "Gemfile", after: 'gem "web-console"' do
  <<~RUBY

    gem "pry-byebug"
    gem "bullet"
  RUBY
end

gsub_file("Gemfile", '# gem "rack-mini-profiler"', 'gem "rack-mini-profiler"')

# Flashes
########################################
file "app/views/shared/_flashes.html.erb", <<~HTML
  <% if notice %>
    <div class="alert alert-info" role="alert">
      <%= notice %>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning" role="alert">
      <%= alert %>
    </div>
  <% end %>
HTML

inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# README
########################################
markdown_file_content = <<~MARKDOWN
  ## Setup

  1. Pull down the app from version control
  2. Make sure you have Postgres running
  3. `bin/setup`

  ## Running The App

  1. `bin/run`

  ## Tests and CI

  1. `bin/ci` contains all the tests and checks for the app
  2. `tmp/test.log` will use the production logging format *not* the development one.

  ## Production

  * All runtime configuration should be supplied in the UNIX environment
  * Rails logging uses lograge. `bin/setup help` can tell you how to see this locally
MARKDOWN
file "README.md", markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

# Lograge setup
file "config/initializers/lograge.rb", <<~RUBY
  Rails.application.configure do
    if !Rails.env.development? || ENV["LOGRAGE_IN_DEVELOPMENT"] == "true"
      config.lograge.enabled = true
    else
      config.lograge.enabled = false
    end
  end
RUBY

# Setup file
########################################
run "rm bin/setup"
file "bin/setup", '#!/usr/bin/env ruby

def setup
  log "Installing gems"
  # Only do bundle install if the much-faster
  # bundle check indicates we need to
  system! "bundle check || bundle install"

  log "Dropping & recreating the development database"
  # Note that the very first time this runs, db:reset
  # will fail, but this failure is fixed by
  # doing a db:migrate
  system! "bin/rails db:reset || bin/rails db:migrate"

  log "Seeding the development database"
  system! "bin/rails db:seed"

  log "Dropping & recreating the test database"
  # Setting the RAILS_ENV explicitly to be sure
  # we actually reset the test database
  system!({ "RAILS_ENV" => "test" }, "bin/rails db:reset")

  log "All set up."
  log ""
  log "To see commonly-needed commands, run:"
  log ""
  log "    bin/setup help"
  log ""
end

def help
  log "Useful commands:"
  log ""
  log " bin/run"
  log "    # run app locally"
  log ""
  log " LOGRAGE_IN_DEVELOPMENT=true bin/run"
  log "    # run app locally using"
  log "    # production-like logging"
  log ""
  log " bin/ci"
  log "    # runs all tests and checks as CI would"
  log ""
  log " bin/rails test"
  log "    # run non-system tests"
  log ""
  log " bin/rails test:system"
  log "    # run system tests"
  log ""
  log " bin/setup help"
  log "    # show this help"
  log ""
end

def log(message)
  puts "[ bin/setup ] #{message}"
end

def system!(*args)
  log "Executing #{args}"
  if system(*args)
    log "#{args} succeeded"
  else
    log "#{args} failed"
    abort
  end
end

if ARGV[0] == "help"
  help
else
  setup
end
'
run "chmod +x bin/setup"

# CI file
########################################
file "bin/ci", <<~BASH
  #!/usr/bin/env bash
  set -e

  echo "[ bin/ci ] Running unit tests"
  bin/rails test

  echo "[ bin/ci ] Running system tests"
  bin/rails test:system

  echo "[ bin/ci ] Analyzing ruby code for quality."
  bundle exec standardrb --fix

  echo "[ bin/ci ] Analyzing code for security vulnerabilities."
  echo "[ bin/ci ] Output will be in tmp/brakeman.html, which"
  echo "[ bin/ci ] can be opened in your browser."
  bundle exec brakeman -q -o tmp/brakeman.html


  echo "[ bin/ci ] Analyzing Ruby gems for"
  echo "[ bin/ci ] security vulnerabilities"
  bundle exec bundle audit check --update

  echo "[ bin/ci ] Done"
BASH
run "chmod +x bin/ci"

# Runner file
########################################
file "bin/run", <<~BASH
  #!/usr/bin/env bash
  set -e

  bin/rails server
BASH
run "chmod +x bin/run"

# After bundle
########################################
after_bundle do
  # Run setup
  ########################################
  run "bin/setup"

  # Generators: simple form + pages controller
  ########################################
  generate("simple_form:install")
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")
  # Devise install + user
  ########################################
  generate("devise:install")
  generate("devise", "User")

  # Application controller
  ########################################
  run "rm app/controllers/application_controller.rb"
  file "app/controllers/application_controller.rb", <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command "db:migrate"
  generate("devise:views")
  gsub_file(
    "app/views/devise/registrations/new.html.erb",
    "<%= simple_form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>",
    "<%= simple_form_for(resource, as: resource_name, url: registration_path(resource_name), data: { turbo: :false }) do |f| %>"
  )
  gsub_file(
    "app/views/devise/sessions/new.html.erb",
    "<%= simple_form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>",
    "<%= simple_form_for(resource, as: resource_name, url: session_path(resource_name), data: { turbo: :false }) do |f| %>"
  )
  link_to = <<~HTML
    <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML
  button_to = <<~HTML
    <p><%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "btn btn-link" %></p>
  HTML
  gsub_file("app/views/devise/registrations/edit.html.erb", link_to, button_to)

  # Pages Controller
  ########################################
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Routes
  ########################################
  route 'root to: "pages#home"'

  # Gitignore
  ########################################
  append_file ".gitignore", <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  ########################################
  run "touch '.env'"

  # Run Standardrb
  ########################################
  run "bundle exec standardrb --fix"

  # Git
  ########################################
  git :init
  git add: "."
  git commit: "-m 'Initial commit with minimal template from https://github.com/hugsdaniel/rails-templates'"
  run "git branch -M main"
end
