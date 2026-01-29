# Rails Templates

Quickly generate a rails app with pre-configured templates using [Rails Templates](http://guides.rubyonrails.org/rails_application_templates.html).

⚠️ The following templates have been made for Rails 8.

## Minimal

Get a minimal rails app ready to be deployed on Heroku with Bootstrap, Simple form and debugging gems.

```bash
rails new \
  -d postgresql \
  -m https://raw.githubusercontent.com/HugsDaniel/rails-templates/master/minimal.rb \
  CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```

## Devise

Full-featured Rails app with Devise authentication, Tailwind CSS, Pundit authorization, Sidekiq background jobs, ActiveAdmin, analytics (Ahoy), FriendlyId slugs, and development tools (Letter Opener, Bullet).

```bash
rails new \
  -d postgresql \
  -m https://raw.githubusercontent.com/HugsDaniel/rails-templates/master/devise.rb \
  CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```
