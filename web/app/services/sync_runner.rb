require "json"

# Runs the wikisync tool on this machine for a queued SyncRun, feeding its `-json` events into the run
# and importing the result. When the tool is not installed here, runs stay queued for an external
# wikisync agent to claim through /api/v2.
class SyncRunner
  FLUSH_EVERY = 25

  def self.bin = Pathname.new(Rails.configuration.x.wikisync_bin.to_s)
  def self.available? = ENV["SYNC_RUNNER"] != "agent" && bin.file?

  # Starts a queued run in the background when a local runner is available.
  def self.dispatch(run)
    return false unless available?
    Thread.new do
      Rails.application.executor.wrap { new(run.reload).call }
    rescue StandardError => e
      Rails.logger.error("sync run #{run.id} crashed: #{e.class}: #{e.message}")
    end
    true
  end

  def initialize(run)
    @run = run
    @settings = SyncSetting.instance
  end

  def call
    @run.update!(status: "running")
    buffer = []
    reported_end = false
    IO.popen(command, chdir: self.class.bin.dirname.to_s, err: %i[child out]) do |io|
      @run.update_column(:pid, io.pid)
      io.each_line do |line|
        ev = parse(line)
        if ev.nil?
          @run.add_log("INFO", line.strip) if line.strip.present?
          next
        end
        reported_end = true if %w[done error].include?(ev["t"])
        buffer << ev
        flush(buffer) if buffer.size >= FLUSH_EVERY || reported_end
      end
    end
    flush(buffer)
    code = $?.exitstatus
    @run.reload
    return if @run.status == "cancelled"
    @run.fail!("wikisync exited with code #{code}") if @run.active? || (code.to_i != 0 && @run.status == "success")
    import_pages if @run.status.in?(%w[success warnings])
  end

  private

  def command
    s = @settings
    args = [self.class.bin.to_s, "-json", "-out", Rails.configuration.x.wiki_root.to_s, "-mode", @run.mode, "-batch", s.batch.to_s, "-ns", s.namespace.to_s]
    args << "-full" if @run.full
    args
  end

  def parse(line)
    ev = JSON.parse(line)
    ev.is_a?(Hash) && ev["t"] ? ev : nil
  rescue JSON::ParserError
    nil
  end

  def flush(buffer)
    return if buffer.empty?
    @run.apply_events(buffer.shift(buffer.size))
  end

  # The panel reads the Markdown files directly, so a finished run only needs the index refreshed.
  def import_pages
    Wiki.reload!
    @run.add_log("INFO", "wiki index refreshed: #{Wiki.library.count} pages")
  rescue StandardError => e
    @run.add_log("ERROR", "could not refresh the wiki index: #{e.message}")
  end
end
