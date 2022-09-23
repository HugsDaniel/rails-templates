# Rails Templates

Quickly generate a rails app with the default configuration
using [Rails Templates](http://guides.rubyonrails.org/rails_application_templates.html).

⚠️ The following templates have been made for Rails 7.

## Minimal

Get a minimal rails app ready to be deployed on Heroku with code quality analysis gems and basic configuration.

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
  -m https://raw.githubusercontent.com/lewagon/rails-templates/master/devise.rb \
  CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```
