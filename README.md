# Rails Templates

Quickly generate a rails app with the default configuration
using [Rails Templates](http://guides.rubyonrails.org/rails_application_templates.html).

⚠️ The following templates have been made for Rails 7.

## Minimal

Get a minimal rails with code quality, vulnerability checks and basic configuration for setup and local dev.

```bash
rails new \
  -d postgresql \
  -m https://raw.githubusercontent.com/HugsDaniel/rails-templates/main/minimal.rb \
  CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```

## Devise

Same as minimal **plus** a Devise install with a generated `User` model.

```bash
rails new \
  -d postgresql \
  -m https://raw.githubusercontent.com/HugsDaniel/rails-templates/main/devise.rb \
  CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```
