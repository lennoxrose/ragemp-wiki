# Minimal 5 field cron: minute hour day-of-month month day-of-week, with *, lists, ranges and steps.
class CronExpression
  RANGES = [0..59, 0..23, 1..31, 1..12, 0..6].freeze

  def self.valid?(text)
    new(text)
    true
  rescue ArgumentError
    false
  end

  def initialize(text)
    fields = text.to_s.split
    raise ArgumentError, "cron needs 5 fields" unless fields.size == 5
    @sets = fields.each_with_index.map { |f, i| expand(f, RANGES[i]) }
  end

  def match?(t)
    minute, hour, dom, month, dow = @sets
    minute.include?(t.min) && hour.include?(t.hour) && dom.include?(t.day) && month.include?(t.month) && dow.include?(t.wday)
  end

  def next_after(time, horizon_days: 62)
    t = time.change(sec: 0) + 1.minute
    limit = time + horizon_days.days
    while t < limit
      return t if match?(t)
      t += 1.minute
    end
    nil
  end

  private

  def expand(field, range)
    field.split(",").flat_map do |part|
      base, step = part.split("/")
      step = step ? Integer(step) : 1
      raise ArgumentError, "bad step" unless step.positive?
      lo, hi = if base == "*" then [range.first, range.last]
               elsif base.include?("-") then base.split("-").map { |n| Integer(n) }
               else v = Integer(base); [v, step == 1 ? v : range.last]
               end
      raise ArgumentError, "out of range" unless range.cover?(lo) && range.cover?(hi) && lo <= hi
      (lo..hi).step(step).to_a
    end.to_set
  rescue ArgumentError, TypeError
    raise ArgumentError, "invalid cron field #{field.inspect}"
  end
end
