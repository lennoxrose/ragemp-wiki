# Numbers for the admin Analytics page, computed from the panel's own tables (views, searches, accounts, discussions, logins).
class Analytics
  RANGES = { "24h" => 24.hours, "7d" => 7.days, "30d" => 30.days, "90d" => 90.days, "1y" => 365.days }.freeze
  ROW_LIMIT = 300_000

  attr_reader :range, :from, :to

  def initialize(range = "30d")
    @range = RANGES.key?(range) ? range : "30d"
    @span = RANGES[@range]
    @to = Time.current
    @from = @to - @span
    @prev_from = @from - @span
  end

  def hourly? = @range == "24h"
  def weekly? = @range == "1y"
  def step = hourly? ? 1.hour : (weekly? ? 1.week : 1.day)
  def buckets = hourly? ? 24 : (weekly? ? 52 : (@span / 1.day).to_i)
  def labels = Array.new(buckets) { |i| t = (@from + i * step).in_time_zone; hourly? ? t.strftime("%H:%M") : t.strftime("%b %-d") }

  def bucket(time) = ((time - @from) / step).floor.clamp(0, buckets - 1)
  def counts(times) = times.each_with_object(Array.new(buckets, 0)) { |t, a| a[bucket(t)] += 1 }

  # ---- raw rows ------------------------------------------------------------------------------------------------
  def views = @views ||= PageView.where(created_at: @from..@to).limit(ROW_LIMIT).pluck(:page_slug, :user_id, :created_at)
  def searches = @searches ||= SearchLog.where(created_at: @from..@to).limit(ROW_LIMIT).pluck(:query, :created_at)
  def new_users = @new_users ||= User.where(created_at: @from..@to).pluck(:created_at)
  def new_posts = @new_posts ||= Post.where(created_at: @from..@to).pluck(:created_at)
  def attempts = @attempts ||= LoginAttempt.where(created_at: @from..@to).pluck(:outcome, :created_at)

  # ---- KPI strip -----------------------------------------------------------------------------------------------
  def kpis
    prev_views = PageView.where(created_at: @prev_from...@from).count
    prev_searches = SearchLog.where(created_at: @prev_from...@from).count
    prev_users = User.where(created_at: @prev_from...@from).count
    prev_posts = Post.where(created_at: @prev_from...@from).count
    active_now = views.filter_map { |_, u, _| u }.uniq.size
    active_prev = PageView.where(created_at: @prev_from...@from).distinct.count(:user_id)
    fail_now = attempts.count { |o, _| o != "success" }
    fail_rate = attempts.empty? ? 0.0 : (fail_now * 100.0 / attempts.size)
    prev_attempts = LoginAttempt.where(created_at: @prev_from...@from)
    prev_rate = prev_attempts.count.zero? ? 0.0 : (prev_attempts.where.not(outcome: "success").count * 100.0 / prev_attempts.count)
    [
      kpi("Page views", views.size, percent_change(views.size, prev_views), spark(counts(views.map(&:last))), "#FFCF31"),
      kpi("Active members", active_now, signed(active_now - active_prev), spark(unique_users_by_bucket), "#FF8A3D"),
      kpi("Searches", searches.size, percent_change(searches.size, prev_searches), spark(counts(searches.map(&:last))), "#5ED6B3"),
      kpi("New accounts", new_users.size, percent_change(new_users.size, prev_users), spark(counts(new_users)), "#FFCF31"),
      kpi("Discussion posts", new_posts.size, percent_change(new_posts.size, prev_posts), spark(counts(new_posts)), "#FF8A3D"),
      kpi("Failed logins", "#{fail_rate.round(1)}%", "#{(fail_rate - prev_rate) >= 0 ? "+" : ""}#{(fail_rate - prev_rate).round(1)}%", spark(counts(attempts.reject { |o, _| o == "success" }.map(&:last))), "#FF6B6B", lower_is_better: true)
    ]
  end

  # ---- charts --------------------------------------------------------------------------------------------------
  # Page views per bucket, stacked by the three busiest categories plus everything else.
  def views_by_category
    by_cat = views.group_by { |slug, _, _| Wiki.library.category_of(slug) || "Other" }
    top = by_cat.sort_by { |_, v| -v.size }.first(3).map(&:first)
    names = top + ["Other"]
    series = names.map do |name|
      rows = name == "Other" ? by_cat.reject { |k, _| top.include?(k) }.values.flatten(1) : by_cat[name].to_a
      { name: name, values: counts(rows.map(&:last)) }
    end
    series.reject! { |s| s[:name] == "Other" && s[:values].sum.zero? }
    series
  end

  def role_counts
    [["Members", User.active.where(role: "member").count], ["Editors", User.active.where(role: "editor").count],
     ["Admins", User.active.where(role: "admin").count], ["Disabled", User.disabled.count]]
  end

  # Searches per hour of the day: the average day and the busiest single day.
  def search_by_hour
    per_day_hour = Hash.new(0)
    searches.each { |_, t| lt = t.in_time_zone; per_day_hour[[lt.to_date, lt.hour]] += 1 }
    days = [per_day_hour.keys.map(&:first).uniq.size, 1].max
    (0..23).map do |h|
      counts = per_day_hour.select { |(_, hh), _| hh == h }.values
      { hour: h, avg: counts.sum.to_f / days, peak: counts.max.to_i }
    end
  end

  # 7 x 24 grid of page views, Monday first.
  def heatmap
    grid = Array.new(7) { Array.new(24, 0) }
    views.each { |_, _, t| lt = t.in_time_zone; grid[(lt.wday - 1) % 7][lt.hour] += 1 }
    grid
  end

  def top_pages(limit = 6) = views.group_by(&:first).map { |slug, v| [slug, v.size] }.sort_by { |_, n| -n }.first(limit)
  def top_searches(limit = 6) = searches.group_by { |q, _| q.downcase }.map { |q, v| [q, v.size] }.sort_by { |_, n| -n }.first(limit)

  def top_members(limit = 5)
    counts = Post.where(created_at: @from..@to).where.not(user_id: nil).group(:user_id).order(Arel.sql("COUNT(*) DESC")).limit(limit).count
    users = User.where(id: counts.keys).index_by(&:id)
    counts.filter_map { |id, n| users[id] && [users[id], n] }
  end

  def signups_by_month(months = 12)
    start = Time.current.beginning_of_month - (months - 1).months
    counts = Hash.new(0)
    User.where("created_at >= ?", start).pluck(:created_at).each { |t| counts[t.in_time_zone.strftime("%Y-%m")] += 1 }
    Array.new(months) { |i| m = start + i.months; [m.strftime("%b")[0], counts[m.strftime("%Y-%m")], m.strftime("%b %Y")] }
  end

  def invite_breakdown = [["Used", InviteCode.where.not(used_by_id: nil).count], ["Unused", InviteCode.available.count], ["Revoked", InviteCode.where.not(revoked_at: nil).where(used_by_id: nil).count]]
  def login_breakdown
    t = attempts.map(&:first).tally
    [["Successful", t["success"].to_i], ["Failed", t["wrong_password"].to_i], ["Disabled", t["disabled"].to_i]]
  end

  # CSV of the time series for the Export button.
  def to_csv
    require "csv"
    view_counts = counts(views.map(&:last))
    search_counts = counts(searches.map(&:last))
    CSV.generate do |csv|
      csv << %w[period page_views searches new_accounts discussion_posts]
      user_counts = counts(new_users)
      post_counts = counts(new_posts)
      labels.each_with_index { |l, i| csv << [l, view_counts[i], search_counts[i], user_counts[i], post_counts[i]] }
    end
  end

  private

  def kpi(label, value, delta, spark, color, lower_is_better: false)
    positive = delta.to_s.start_with?("+") || delta.to_s == "0"
    good = lower_is_better ? !delta.to_s.start_with?("+") || delta.to_s.match?(/\A\+0(\.0)?%?\z/) : positive
    { label: label, value: value.is_a?(Integer) ? ActiveSupport::NumberHelper.number_to_delimited(value) : value, delta: delta, good: good, spark: spark, color: color }
  end

  def percent_change(now, before)
    return now.positive? ? "+100%" : "0%" if before.zero?
    pct = ((now - before) * 100.0 / before)
    shown = pct.abs >= 1000 ? ActiveSupport::NumberHelper.number_to_delimited(pct.round) : pct.round(1)
    "#{pct >= 0 ? "+" : "-"}#{pct >= 0 ? shown : shown.to_s.delete_prefix("-")}%"
  end

  def signed(n) = n >= 0 ? "+#{n}" : n.to_s

  def unique_users_by_bucket
    views.group_by { |_, _, t| bucket(t) }.each_with_object(Array.new(buckets, 0)) { |(b, rows), a| a[b] = rows.filter_map { |_, u, _| u }.uniq.size }
  end

  # a short series for the sparkline: at most 14 points
  def spark(values)
    return values if values.size <= 14
    values.each_slice((values.size / 14.0).ceil).map(&:sum)
  end
end
