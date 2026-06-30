source "https://rubygems.org"

ruby "3.3.6"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.3", ">= 7.2.3.1"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# JSON Web Tokens for stateless API authentication.
gem "jwt", "~> 2.8"

# Role-based authorization policies.
gem "pundit", "~> 2.3"

# State machine for credit-application status (wired per country via the registry).
gem "aasm", "~> 5.5"

# Background jobs + recurring schedule for the outbox dispatcher.
gem "sidekiq", "~> 7.2"
gem "sidekiq-cron", "~> 2.4"

# Redis-backed Rails.cache (single-application reads + country config).
gem "redis", "~> 5.0"
# Rails' RedisCacheStore uses the connection_pool 2.x constructor API; 3.0
# changed it (ArgumentError on boot). Pin to 2.x (also satisfies Sidekiq).
gem "connection_pool", "~> 2.4"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ]

  # Testing framework (TDD is mandatory in this project).
  gem "rspec-rails", "~> 6.1"

  # Static analysis: Rails' curated RuboCop ruleset.
  gem "rubocop", require: false
  gem "rubocop-rails-omakase", require: false

  # Dependency vulnerability scanning.
  gem "bundler-audit", require: false

  # N+1 / unused-eager-load detection (raises in test, logs in development).
  gem "bullet"

  # Test data factories and expressive model matchers.
  gem "factory_bot_rails"
  gem "shoulda-matchers", "~> 6.0"
end
