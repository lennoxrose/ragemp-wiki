# One run of the wikisync tool. Events use the NDJSON shape the tool prints with `-json`.
class SyncRun < ApplicationRecord
  STATUSES = %w[queued running success warnings failed cancelled].freeze
  LOG_LIMIT = 300_000

  belongs_to :triggered_by, class_name: "User", optional: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(started_at: :desc) }
  scope :active, -> { where(status: %w[queued running]) }

  def self.queue!(trigger:, user: nil, full: false, settings: SyncSetting.instance)
    create!(trigger: trigger, triggered_by: user, mode: settings.mode, full: full, status: "queued", started_at: Time.current)
  end

  def active? = status.in?(%w[queued running])
  def finished? = !active?
  def duration = (finished_at || Time.current) - started_at

  def percent
    return 0 if changed_count.zero?
    [(done * 100.0 / changed_count).round, 100].min
  end

  def log_lines
    log.to_s.lines.map(&:chomp).map { |l| t, level, msg = l.split("\t", 3); { time: t, level: level, message: msg.to_s } }
  end

  # Applies a list of event hashes in one write. Unknown events are ignored.
  def apply_events(events)
    return if events.blank?
    attrs = {}
    lines = []
    events.each do |ev|
      ev = ev.to_h.stringify_keys
      stamp = (ev["ts"] ? Time.zone.at(ev["ts"].to_i > 10**11 ? ev["ts"].to_i / 1000 : ev["ts"].to_i) : Time.current).strftime("%H:%M:%S")
      case ev["t"]
      when "phase"
        attrs[:phase] = ev["name"]; attrs[:status] = "running"
        lines << [stamp, "PHASE", ev["name"]]
      when "listing"
        attrs[:listed] = ev["count"].to_i; lines << [stamp, "INFO", "listed #{ev["count"]} pages"]
      when "plan"
        attrs.merge!(total: ev["total"].to_i, changed_count: ev["changed"].to_i, removed: ev["removed"].to_i)
        lines << [stamp, "PLAN", "#{ev["total"]} total · #{ev["changed"]} changed · #{ev["removed"]} removed"]
      when "batch"
        attrs[:batches] = (attrs[:batches] || batches) + 1
        lines << [stamp, "BATCH", "batch #{ev["index"].to_i + 1} · #{ev["size"]} pages"]
      when "page"
        attrs[:written] = (attrs[:written] || written) + 1
        lines << [stamp, "PAGE", "#{ev["title"]} → #{ev["path"]}"]
      when "progress"
        attrs[:done] = ev["done"].to_i; lines << [stamp, "PROG", "#{ev["done"]} / #{ev["total"]} pages"]
      when "warn"
        lines << [stamp, "WARN", ev["msg"].to_s]
      when "done"
        failed_batches = ev["failed"].to_i
        attrs.merge!(failed: failed_batches, status: failed_batches.positive? ? "warnings" : "success", finished_at: Time.current)
        lines << [stamp, "INFO", failed_batches.positive? ? "finished with #{failed_batches} failed batches" : "finished"]
      when "error"
        attrs.merge!(status: "failed", error: ev["msg"].to_s, finished_at: Time.current)
        lines << [stamp, "ERROR", ev["msg"].to_s]
      end
    end
    attrs[:log] = (log.to_s + lines.map { |l| l.join("\t") }.join("\n") + "\n").last(LOG_LIMIT) if lines.any?
    update!(attrs) if attrs.any?
  end

  def add_log(level, message)
    apply_note(level, message)
  end

  def fail!(message)
    update!(status: "failed", error: message, finished_at: Time.current, log: (log.to_s + [Time.current.strftime("%H:%M:%S"), "ERROR", message].join("\t") + "\n").last(LOG_LIMIT))
  end

  private

  def apply_note(level, message)
    update!(log: (log.to_s + [Time.current.strftime("%H:%M:%S"), level, message].join("\t") + "\n").last(LOG_LIMIT))
  end
end
