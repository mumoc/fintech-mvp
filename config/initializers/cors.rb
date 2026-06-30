# Allow the frontend SPA to call the API cross-origin. Origins are configurable
# (comma-separated) via FRONTEND_ORIGINS; defaults to the Vite dev server.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("FRONTEND_ORIGINS", "http://localhost:5173").split(","))

    resource "/api/*",
             headers: :any,
             methods: %i[get post patch put delete options head],
             expose: %w[Authorization]
  end
end
