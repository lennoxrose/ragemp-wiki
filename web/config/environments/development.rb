Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  # Rails' debug pages list every route, which would reveal the admin panel to anyone who triggers an error.
  # Turn them on only on your own machine: RAILS_DEBUG_PAGES=1 bin/rails server
  config.consider_all_requests_local = ENV["RAILS_DEBUG_PAGES"] == "1"
  config.active_record.migration_error = :page_load
end
