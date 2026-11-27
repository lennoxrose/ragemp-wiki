Rails.application.config.after_initialize do
  # Only the web server runs the scheduler, never rake tasks, the console or tests.
  next unless defined?(Rails::Server) && ENV["WIKI_SCHEDULER"] != "0"

  Thread.new do
    loop do
      sleep 30
      begin
        Rails.application.executor.wrap { SyncScheduler.tick }
      rescue StandardError => e
        Rails.logger.error("sync scheduler: #{e.class}: #{e.message}")
      end
    end
  end
end
