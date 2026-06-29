require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bravo
  class Application < Rails::Application
    # Initialize configuration defaults for the Rails version in use.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # New domain models use UUID primary keys (see PLAN §1).
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    # Active Record encryption keys. Set here (not in an initializer) because the
    # active_record.encryption railtie applies these before config/initializers
    # run. In production these come from the secrets manager / ENV; the dev
    # defaults below are NON-SECRET placeholders and must be overridden.
    config.active_record.encryption.primary_key =
      ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", "dev_only_primary_key_replace_in_production_0001")
    config.active_record.encryption.deterministic_key =
      ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", "dev_only_deterministic_key_replace_in_prod_0002")
    config.active_record.encryption.key_derivation_salt =
      ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", "dev_only_key_derivation_salt_replace_in_prod_0003")

    # HMAC key for the document_number blind index (document_fingerprint).
    config.x.blind_index_key =
      ENV.fetch("BLIND_INDEX_KEY", "dev_only_blind_index_key_replace_in_production_0004")

    # Country strategies are sealed under app/countries/<code>/ and addressed as
    # Countries::<CODE>::<Strategy>. By default Rails would treat app/countries as
    # an autoload root (stripping the namespace), so we instead map the directory
    # to the Countries namespace and teach Zeitwerk the country-code acronyms.
    initializer "bravo.countries_namespace", before: :set_autoload_paths do |app|
      countries_dir = app.root.join("app/countries").to_s
      app.config.eager_load_paths.delete(countries_dir)
      app.config.autoload_paths.delete(countries_dir)

      Object.const_set(:Countries, Module.new) unless Object.const_defined?(:Countries)

      main = Rails.autoloaders.main
      main.inflector.inflect("mx" => "MX", "es" => "ES")
      main.push_dir(countries_dir, namespace: Countries)
    end
  end
end
