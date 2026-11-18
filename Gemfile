source "https://rubygems.org"

# Application Rails et base de données
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "sqlite3", ">= 2.10.2"
gem "puma", "~> 8.0", ">= 8.0.3"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Interface et authentification
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "devise", ">= 4.9.3"
gem "inline_svg"
gem "jbuilder"
gem "image_processing", "~> 1.2"
gem "json", "< 4.0"

# Cache, tâches et déploiement
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", "~> 8.1.0"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
