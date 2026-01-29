run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "sprockets-rails"
    gem "devise"
    gem "pundit"
    gem "sidekiq"
    gem "sidekiq-scheduler"
    gem "tailwindcss-rails"
    gem "simple_form", github: "heartcombo/simple_form"
    gem "ahoy_matey"
    gem "friendly_id"

  RUBY
end

inject_into_file "Gemfile", after: "group :development, :test do" do
  <<~RUBY

    gem "dotenv-rails"
    gem "letter_opener"
    gem "bullet"
  RUBY
end

# Replace Propshaft with Sprockets
########################################
gsub_file("Gemfile", /^gem "propshaft".*\n/, "")

# Assets
########################################
run "rm -rf app/assets/stylesheets"
run "mkdir -p app/assets/stylesheets"

# Sprockets manifest (required for Rails 8)
########################################
run "mkdir -p app/assets/config"
file "app/assets/config/manifest.js", <<~JS
  //= link_tree ../images
  //= link_directory ../stylesheets .css
JS

# Layout
########################################

gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

gsub_file(
  "app/views/layouts/application.html.erb",
  'stylesheet_link_tag :app',
  'stylesheet_link_tag "application"'
)

# Flashes
########################################
file "app/views/shared/_flashes.html.erb", <<~HTML
  <% if notice %>
    <div class="bg-blue-100 border border-blue-400 text-blue-700 px-4 py-3 rounded relative mb-4" role="alert">
      <span class="block sm:inline"><%= notice %></span>
      <button type="button" class="absolute top-0 bottom-0 right-0 px-4 py-3" data-action="click->flashes#close">
        <span class="text-2xl">&times;</span>
      </button>
    </div>
  <% end %>
  <% if alert %>
    <div class="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded relative mb-4" role="alert">
      <span class="block sm:inline"><%= alert %></span>
      <button type="button" class="absolute top-0 bottom-0 right-0 px-4 py-3" data-action="click->flashes#close">
        <span class="text-2xl">&times;</span>
      </button>
    </div>
  <% end %>
HTML

file "app/views/shared/_navbar.html.erb", <<~HTML
  <nav class="bg-white shadow-lg">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16">
        <div class="flex">
          <div class="flex-shrink-0 flex items-center">
            <%= link_to "Home", root_path, class: "text-xl font-bold text-gray-800" %>
          </div>
        </div>
        <div class="flex items-center">
          <% if user_signed_in? %>
            <%= link_to "Sign Out", destroy_user_session_path, data: { turbo_method: :delete }, class: "text-gray-700 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium" %>
          <% else %>
            <%= link_to "Sign In", new_user_session_path, class: "text-gray-700 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium" %>
            <%= link_to "Sign Up", new_user_registration_path, class: "ml-4 px-4 py-2 rounded-md text-sm font-medium text-white bg-blue-600 hover:bg-blue-700" %>
          <% end %>
        </div>
      </div>
    </div>
  </nav>
HTML

inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do
  <<~HTML
    <%= render "shared/navbar" %>
    <%= render "shared/flashes" %>
  HTML
end

# README
########################################
markdown_file_content = <<~MARKDOWN
  Rails app generated with [lewagon/rails-templates](https://github.com/lewagon/rails-templates), created by the [Le Wagon coding bootcamp](https://www.lewagon.com) team.
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

########################################
# After bundle
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command "db:drop db:create db:migrate"
  generate("simple_form:install")
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

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
      include Pundit::Authorization

      # Pundit: allow-list approach
      after_action :verify_authorized, except: :index, unless: :skip_pundit?
      after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

      # Uncomment when you have a real policy implemented
      # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

      private

      def skip_pundit?
        devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
      end

      # def user_not_authorized
      #   flash[:alert] = "You are not authorized to perform this action."
      #   redirect_to(request.referer || root_path)
      # end
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command "db:migrate"
  generate("devise:views")

  link_to = <<~HTML
    <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML
  button_to = <<~HTML
    <div class="flex items-center space-x-2">
      <div>Unhappy?</div>
      <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "text-blue-600 hover:text-blue-800 underline" %>
    </div>
  HTML
  gsub_file("app/views/devise/registrations/edit.html.erb", link_to, button_to)

  # Pundit install
  ########################################
  generate "pundit:install"

  # Ahoy install
  ########################################
  generate "ahoy:install"
  rails_command "db:migrate"

  # Track Ahoy visits and events
  inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base\n" do
    "  # Uncomment to track visits with Ahoy\n  # before_action :track_ahoy_visit\n\n"
  end

  # FriendlyId install
  ########################################
  generate "friendly_id"
  rails_command "db:migrate"

  # Create example FriendlyId concern
  file "app/models/concerns/sluggable.rb", <<~RUBY
    module Sluggable
      extend ActiveSupport::Concern

      included do
        extend FriendlyId
        friendly_id :name, use: :slugged
      end

      def should_generate_new_friendly_id?
        name_changed? || slug.blank?
      end
    end
  RUBY

  # Letter Opener configuration
  ########################################
  environment "config.action_mailer.delivery_method = :letter_opener", env: "development"
  environment "config.action_mailer.perform_deliveries = true", env: "development"

  # Bullet configuration
  ########################################
  insert_into_file "config/environments/development.rb", after: "Rails.application.configure do\n" do
    <<~RUBY
      # Bullet configuration
      config.after_initialize do
        Bullet.enable = true
        Bullet.alert = false
        Bullet.bullet_logger = true
        Bullet.console = true
        Bullet.rails_logger = true
        Bullet.add_footer = true
      end

    RUBY
  end

  # Sidekiq configuration
  ########################################
  environment "config.active_job.queue_adapter = :sidekiq"

  file "config/sidekiq.yml", <<~YAML
    :concurrency: 3
    :queues:
      - default
      - mailers
      - active_storage_analysis
      - active_storage_purge
  YAML

  file "config/initializers/sidekiq.yml", <<~YAML
    # Example scheduled jobs configuration
    # Uncomment and modify as needed
    #
    # :schedule:
    #   example_job:
    #     cron: '0 0 * * *'  # Runs daily at midnight
    #     class: ExampleJob
    #     queue: default
  YAML

  inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
    <<~RUBY
      require 'sidekiq/web'
      require 'sidekiq-scheduler/web'

      # Sidekiq Web UI (mount behind authentication in production)
      if Rails.env.development?
        mount Sidekiq::Web => '/sidekiq'
      else
        # In production, protect with authentication
        # authenticate :user, ->(user) { user.admin? } do
        #   mount Sidekiq::Web => '/sidekiq'
        # end
      end

    RUBY
  end

  # Example job
  file "app/jobs/example_job.rb", <<~RUBY
    class ExampleJob < ApplicationJob
      queue_as :default

      def perform(*args)
        # Do something later
      end
    end
  RUBY

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

  # Tailwind CSS
  ########################################
  rails_command "tailwindcss:install"

  # Stylesheet Architecture
  ########################################
  file "app/assets/stylesheets/application.tailwind.css", <<~CSS
    @import "tailwindcss/base";
    @import "tailwindcss/components";
    @import "tailwindcss/utilities";

    @import "base/reset";
    @import "base/typography";

    @import "components/buttons";
    @import "components/forms";
    @import "components/navbar";
    @import "components/alerts";

    @import "pages/home";
  CSS

  run "mkdir -p app/assets/stylesheets/base"
  run "mkdir -p app/assets/stylesheets/components"
  run "mkdir -p app/assets/stylesheets/pages"

  file "app/assets/stylesheets/base/_reset.css", <<~CSS
    /* Custom resets and base styles */
    * {
      margin: 0;
      padding: 0;
    }
  CSS

  file "app/assets/stylesheets/base/_typography.css", <<~CSS
    /* Typography styles */
    body {
      @apply text-gray-900;
    }

    h1, h2, h3, h4, h5, h6 {
      @apply font-semibold;
    }
  CSS

  file "app/assets/stylesheets/components/_buttons.css", <<~CSS
    /* Button component styles */
    .btn {
      @apply px-4 py-2 rounded font-medium transition-colors;
    }

    .btn-primary {
      @apply bg-blue-600 text-white hover:bg-blue-700;
    }

    .btn-secondary {
      @apply bg-gray-600 text-white hover:bg-gray-700;
    }
  CSS

  file "app/assets/stylesheets/components/_forms.css", <<~CSS
    /* Form component styles */
    .form-input {
      @apply w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500;
    }

    .form-label {
      @apply block text-sm font-medium text-gray-700 mb-1;
    }
  CSS

  file "app/assets/stylesheets/components/_navbar.css", <<~CSS
    /* Navbar component styles */
  CSS

  file "app/assets/stylesheets/components/_alerts.css", <<~CSS
    /* Alert component styles */
  CSS

  file "app/assets/stylesheets/pages/_home.css", <<~CSS
    /* Home page specific styles */
  CSS

  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  ########################################
  run "touch '.env'"

  # Rubocop
  ########################################
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml"

  # Git
  ########################################
  git :init
  git add: "."
  git commit: "-m 'Initial commit with devise template from https://github.com/lewagon/rails-templates'"
end
