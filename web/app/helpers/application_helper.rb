module ApplicationHelper
  CATEGORY_COLORS = {
    "Clientside API" => "#9B8CFF", "Serverside API" => "#5ED6B3", "Serverside Events" => "#FF8A3D", "Client-side Event" => "#FF7AA2",
    "Tutorials" => "#E8E36A", "Assets" => "#5AA9FF", "Uncategorized" => "#B3AEA2", "Client-side Function" => "#9B8CFF"
  }.freeze
  PALETTE = %w[#5ED6B3 #FF8A3D #9B8CFF #FF7AA2 #5AA9FF #E8E36A #FF6B6B #B3AEA2].freeze

  def category_color(name)
    CATEGORY_COLORS[name.to_s] || PALETTE[Zlib.crc32(name.to_s) % PALETTE.size]
  end

  def avatar_tag(user, size: 40)
    style = "width:#{size}px;height:#{size}px;font-size:#{(size * 0.4).round}px"
    if user.nil?
      tag.span("?", class: "avatar", style: style, title: "Deleted user")
    elsif user.avatar.attached?
      image_tag(url_for(user.avatar), class: "avatar", style: style, alt: "")
    else
      tag.span(user.initial, class: "avatar", style: style)
    end
  end

  def role_chip(user)
    tag.span(user.role_label, class: ["chip", ("chip-accent" if user.admin?)])
  end

  def chip(text, accent: false, css: nil)
    tag.span(text, class: ["chip", ("chip-accent" if accent), css])
  end

  def time_ago(time)
    return "never" unless time
    distance_of_time_in_words_to_now(time).then { |d| time > Time.current ? "in #{d}" : "#{d} ago" }
  end

  def short_date(time) = time ? time.in_time_zone.strftime("%b %-d, %Y") : "—"

  def delimited(number) = number_with_delimiter(number.to_i, delimiter: ",")

  def external_link_to(text, url, **opts)
    link_to(url, target: "_blank", rel: "noopener noreferrer", **opts) { safe_join([text, " ", icon("arrow-up-right", size: 12, css: "ext")]) }
  end

  def page_title(text = nil) = [text, "RAGE Multiplayer Wiki"].compact.join(" · ")

  # Tabs row under the header. left/right are arrays of [label, path, active?].
  def tab_link(label, path, active)
    link_to(label, path, class: ["tab", ("is-active" if active)], "aria-current": (active ? "page" : nil))
  end

  def nav_active?(*prefixes) = prefixes.any? { |p| request.path == p || request.path.start_with?("#{p}/") }
end
