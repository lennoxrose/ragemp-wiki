require_relative "boot"
require "rails"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"
Bundler.require(*Rails.groups)

module Web
  class Application < Rails::Application
    config.load_defaults 8.0
    config.time_zone = "Berlin"
    # Avatars and banners are stored and served as uploaded; no image processing gems are installed.
    config.active_storage.analyzers = []
    config.active_storage.previewers = []
    config.active_storage.service = :local
    config.active_job.queue_adapter = :async
    # Folder written by the wikisync tool (Markdown files plus .manifest.json).
    config.x.wiki_root = Pathname.new(ENV.fetch("WIKI_ROOT", File.expand_path("../../dist", __dir__)))
    config.x.wikisync_bin = ENV.fetch("WIKISYNC_BIN", File.expand_path("../../bin/wikisync.exe", __dir__))
  end
end
