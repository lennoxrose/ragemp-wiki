# The single row that holds the sync schedule and the options passed to wikisync.
class SyncSetting < ApplicationRecord
  FREQUENCIES = {
    "hourly" => "Every hour", "six_hours" => "Every 6 hours", "daily" => "Daily", "weekly" => "Weekly", "cron" => "Custom cron"
  }.freeze
  HINTS = { "hourly" => "incremental", "six_hours" => "incremental", "daily" => "incremental", "weekly" => "full resync", "cron" => "" }.freeze
  MODES = %w[vault compile].freeze

  validates :frequency, inclusion: { in: FREQUENCIES.keys }
  validates :mode, inclusion: { in: MODES }
  validates :run_at, format: { with: /\A([01]\d|2[0-3]):[0-5]\d\z/, message: "must look like 03:00" }
  validates :batch, numericality: { only_integer: true, in: 1..500 }
  validates :namespace, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :time_zone_exists
  validate :cron_is_valid

  def self.instance = first || create!

  def zone = ActiveSupport::TimeZone[time_zone] || Time.zone

  # Next run after +from+ in the configured time zone.
  def compute_next(from = Time.current)
    now = from.in_time_zone(zone)
    hh, mm = run_at.split(":").map(&:to_i)
    case frequency
    when "hourly" then (now + 1.hour).beginning_of_hour
    when "six_hours"
      slot = now.beginning_of_day + ((now.hour / 6) + 1) * 6.hours
      slot
    when "daily"
      t = now.change(hour: hh, min: mm, sec: 0)
      t <= now ? t + 1.day : t
    when "weekly"
      t = now.beginning_of_week(:sunday).change(hour: hh, min: mm, sec: 0)
      t <= now ? t + 1.week : t
    when "cron" then CronExpression.new(cron).next_after(now)
    end
  end

  def upcoming(count = 3)
    t = Time.current
    Array.new(count) { t = compute_next(t) }.compact
  end

  def schedule!
    update!(next_run_at: enabled ? compute_next : nil)
  end

  private

  def time_zone_exists
    errors.add(:time_zone, "is not a known time zone") unless ActiveSupport::TimeZone[time_zone]
  end

  def cron_is_valid
    return unless frequency == "cron"
    errors.add(:cron, "is not a valid 5 field cron expression") unless CronExpression.valid?(cron)
  end
end
